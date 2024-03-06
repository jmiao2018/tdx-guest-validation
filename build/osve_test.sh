#!/bin/bash

RED="echo -en \\E[4;31m"
RESET="echo -en \\E[0;39m"


echo " "
echo " "
echo " "

# clear test result log
rm -rf $CURR_DIR/log

# -------------------------------------------------- 
# boot a qemu:
#---------------------------------------------------

#sleep 60s
flag="true"
while $flag; do

  if [[ $(nmap -p $port $tdx_guest_ip) =~ "closed" ]]; then echo "waiting qemu boot..."

   		sleep 2
  else
		echo " "
		echo "run the testcase"
		sleep 5
		echo "ok ...."
		sleep 5
	  	flag=false
  fi

done

#----------------------------------------------------
# 1 scp qcow2 file to a host. and boot a TDX guest
#----------------------------------------------------
cd $CURR_DIR/build
tar -cvf 2024WW03.tar.gz 2024WW03

/usr/bin/expect <<EOD
spawn scp -P $port -o StrictHostKeyChecking=no -r $local_testcase_image $guest_user@$tdx_guest_ip:$path
expect {
  "*assword:" { send "$password\r";}
}
expect eof
EOD

#-------------------------------------------------------
# 2 Logn in the TDX guest and scp the ltp-ddt testcases:
#-------------------------------------------------------
#w
sshpass -p $password ssh -p $port $guest_user@$tdx_guest_ip "pwd;cd /root/; tar -xvf 2024WW03.tar.gz;cd 2024WW03;./runtests.sh -p gnr -f tdx_guest_bat_tests;./runtests.sh -p gnr -f tdx_guest_func_tests"
sshpass -p $password ssh -p $port $guest_user@$tdx_guest_ip "pwd;cd /root/; dmesg |grep -i secure > LTP_tdx_guest_secure_boot_test.log"

#-------------------------------------------------------
# 3 scp the test result log to local
#-------------------------------------------------------

mkdir -p $CURR_DIR/log

/usr/bin/expect <<EOD

spawn scp -P $port -o StrictHostKeyChecking=no -r $guest_user@$tdx_guest_ip:/root/2024WW03/results/LTP_tdx_guest_bat_tests.log  $CURR_DIR/log
expect {
  "*assword:" { send "$password\r";}
}
expect eof
EOD

/usr/bin/expect <<EOD
spawn scp -P $port -o StrictHostKeyChecking=no -r $guest_user@$tdx_guest_ip:/root/2024WW03/results/LTP_tdx_guest_func_tests.log  $CURR_DIR/log
expect {
  "*assword:" { send "$password\r";}
}
expect eof
EOD

if [ -z $TDVF ]; then
echo "Not secure boot test"
else
echo "This is a Secure boot: fd: $TDVF"
/usr/bin/expect <<EOD
spawn scp -P $port -o StrictHostKeyChecking=no -r $guest_user@$tdx_guest_ip:/root/LTP_tdx_guest_secure_boot_test.log  $CURR_DIR/log
expect {
  "*assword:" { send "$password\r";}
}
expect eof
EOD

echo " "
fi


rm -rf $CURR_DIR/rootfs
rm -rf $CURR_DIR/build/2024WW03.tar.gz
echo " "
echo " "
echo " "
echo "Result log are $CURR_DIR:"
ls $CURR_DIR/log/*.log
echo " "

