#!/bin/bash

GUEST_QCOW2=$1
TDVF=$2

DISTRO=redhat #redhat/ubuntu
CURR_DIR="$(pwd)"
tdx_host_user='root'
tdx_host_ip=$(hostname -I)
tdx_host_path='/home/tdx'
guest_user='root'
password='osve123'
port=10022
tdx_guest_ip='127.0.0.1'
path='/root'
local_testcase_image="$CURR_DIR/build/2024WW03.tar.gz"
echo "$local_testcase_image"
export tdx_host_user
export tdx_host_ip
export tdx_host_path
export guest_user
export password
export port
export tdx_guest_ip
export tdx_host
export host
export path
export local_testcase_image
export local_path
export GUEST_QCOW2
export DISTRO
export CURR_DIR
export TDVF

if [ $# -eq 0 ]; then
    	echo "没有提供任何输入参数...."
	echo "正确输入格式如下："
	echo "一般测试, 一个输出参数:"
	echo "./run.sh rhel-guest-image-9.4-20240226.21.x86_64.wxl.qcow2"
	echo " "
	echo "Seucre boot测试, 二个输出参数:"
	echo "./run.sh rhel-guest-image-9.4-20240226.21.x86_64.wxl.qcow2 OVMF.inteltdx.secboot.fd"
	echo  ""
	exit
elif [ $# -eq 1 ]; then
	if [[ ! $(file -b $GUEST_QCOW2) =~ "QCOW" ]]; then echo "$GUEST_QCOW2 不是qcow2文件 不可以启动"
	exit
	else
	file $GUEST_QCOW2| grep -i "qcow2" > /dev/null && echo "该文件是qcow2文件 可以启动... ... "
	sleep 3
	fi

elif [ $# -eq 2 ]; then 
	if [[ ! $(file -b $TDVF) =~ "data" ]]; then  echo "不是fd格式文件 不能启动"
	exit
	else
	echo " fd ok"
	sleep 5
	fi

else
	echo "输入参数多了"
	echo "正确格式："
	echo "./run.sh rhel-guest-image-9.4-20240226.21.x86_64.wxl.qcow2"
  exit
fi



tmux_init()
{
    tmux new-session  -s "TDX"  -d -n "[Left: boot  qeme]                                                                 1:[Right: run tdx_test ]"    # 开启一个会话
    tmux split-window -h                 # 开启一个竖屏
	tmux selectp -t 0
	tmux send-keys  "$CURR_DIR/build/boot_qemu.sh" C-m

	tmux selectp -t 1
	tmux send-keys "$CURR_DIR/build/osve_test.sh" C-m
    tmux -2 attach-session -d           # tmux -2强制启用256color，连接已开启的tmux
}

# 判断是否已有开启的tmux会话，没有则开启
if which tmux 2>&1 >/dev/null; then
    test -z "$TMUX" && (tmux attach || tmux_init)
fi
