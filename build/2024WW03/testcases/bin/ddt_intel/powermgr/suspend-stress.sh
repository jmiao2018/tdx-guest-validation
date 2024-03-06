#!/bin/bash

#typical usage: sh suspend-stress.sh -h

version=0.1

# git_address for pmgraph
git_pmgraph=https://github.com/intel/pm-graph.git

# Dataserver configuration
ssh_otcpl=sleepgraph@otcpl-perf-data.jf.intel.com
ssh_sh=power@power-sh.sh.intel.com
http_sh=http://power-sh.sh.intel.com
rr_sh=/power/suspend-stress-qa

# default parameters
d_pmgraph=$HOME/pm-graph
iteration=10
modes="mem freeze"
rtcwake=15


while getopts ":cefghnsvd:i:l:m:o:p:r:w:" opt; do
	case $opt in
	c) cleanup=true
	;;
	e) tools_in_env=true
	;;
	f) force_update=true
	;;
	g) upload_google=true; hosts="$hosts $ssh_otcpl"
	;;
	h) upload_html=true; hosts="$hosts $ssh_sh"
	;;
	n) no_html=true
	;;
	s) sshkey_only=true
	;;
	v) echo "suspend-stress.sh version $version"; exit
	;;
	d) desc="$OPTARG"
	;;
	i) iteration="$OPTARG"
	;;
	l) f_log="$OPTARG"
	;;
	m) modes="$OPTARG"
	;;
	o) output="$OPTARG"
	;;
	p) d_pmgraph="$OPTARG"
	;;
	r) rr_sh=/power/$OPTARG
	;;
	w) rtcwake="$OPTARG"
	;;
	\?) echo "Invalid option -$OPTARG" >&2
	;;
	esac
done

which turbostat > /dev/null
[ $? -ne 0 ] && { echo No turbostat tool found, quit; exit 1; }

if [ ! -z $tools_in_env ]
then
	f_sg=$(which sleepgraph.py)
	f_ds=$(which dataserver.py)
else
	f_sg=$d_pmgraph/sleepgraph.py
	f_ds=$d_pmgraph/tools/dataserver.py
fi

if [ ! -z $force_update ]
then	
	git config --global http.proxy http://child-prc.intel.com:913
	git config --global https.proxy https://child-prc.intel.com:913
	if [ ! -d $d_pmgraph ]
	then
		git clone $git_proxy $d_pmgraph
	else
		cd $d_pmgraph
		git pull
	fi
	f_sg=$d_pmgraph/sleepgraph.py
	f_ds=$d_pmgraph/tools/dataserver.py
fi

[ -f $f_sg ] || { echo No sleepgraph.py found at $f_sg, quit; exit 1; }
if [[ -z $upload_google &&  ! -f $f_ds ]]
then
	echo No dataserver.py found at $f_sg, quit
	exit 1
fi

for host in $hosts
do
	ssh -o PasswordAuthentication=no  -o BatchMode=yes $host exit &>/dev/null
	[ $? -eq 0 ] && { echo can connect to $host; continue; }

	echo Setup access to $host
	if [ "$host" = "$ssh_otcpl" ]
	then
		python3 $f_ds -sshkeysetup
		[ $? -ne 0 ] && { echo failed to set $host password-less login, quit; exit 1; }
	else
		ssh-copy-id -o "StrictHostKeyChecking no" $host
		[ $? -ne 0 ] && { echo failed to set $host password-less login, quit; exit 1; }
	fi
	echo Access to $host has been setup.
done

[ ! -z $sshkey_only ] && exit 0

options="-dev -sync -gzip -addlogs"
[ ! -z $desc ] && options="$options -desc $desc"
[ ! -z $no_html ] && options="$options -skiphtml"

for mode in $modes
do
	trr=$(hostname)-$mode-$(date +%F)
	[ ! -z $desc ] && trr=$trr-$desc

	for i in `seq 1 100`
	do
		l_output=$trr-$i
		[ ! -d $l_output ] && break
	done

	if [ -z $output ]
	then
		output=$l_output
	fi

	options="$options -o $output"
	$f_sg -m $mode -multi $iteration 3 -rtcwake $rtcwake $options

	[ ! -z $upload_google ] && python3 $f_ds -monitor $output
	if [ ! -z $upload_html ]
	then
		ssh $ssh_sh "mkdir ${rr_sh}/${l_output}"
		cd $output
		scp -r ./* $ssh_sh:$rr_sh/$l_output/
		ssh $ssh_sh "cd ${rr_sh}/${l_output}; ~/pm-graph/sleepgraph.py -genhtml -dev -summary ./"
		echo Test results are available at $http_sh/$rr_sh/$l_output/summary.html
		[ ! -z $f_log ] && echo Test results are available at $http_sh/$rr_sh/$l_output/summary.html > $f_log
	fi
done


[ -z $cleanup ] || rm -rf $output
