#!/bin/bash

CUR_DIR=$( cd $( dirname $0 ) && pwd )

sgx_numa_prealloc(){
    out=$(dmesg | grep sgx | grep section | wc -l)

    if [[ "$out" == "0" ]]; then
        echo "No EPC section is decteded! Reboot and re-run this test!"
        exit 1
    fi
    str_pass="SGX_numa_prealloc test passed"
    echo $str_pass
}

sgx_local_attestation(){
    str_fail="SGX_local_attestation test failed"
    source /opt/intel/sgxsdk/environment

    cd $(dirname $0)
    appresponder &
    appresponder_pid=$!

    sleep 1

    appinitiator &> test_appinitiator.out
    kill $appresponder_pid
    sync
    #cat test_appresponder.out

    ret1=`cat test_appinitiator.out |grep "succeed to establish secure channel"`
    ret2=`cat test_appinitiator.out |grep "Succeed to close Session"`

    if [[ "$ret1" == "" || "$ret2" == "" ]]; then
        echo "Fail to create the secure channel!"
        exit 1
    fi
    echo "SGX_local_attestation test passed"
}
sgx_seal_unseal_enclave(){
    source /opt/intel/sgxsdk/environment

    cd $(dirname $0)
    output=$(SealUnseal)
    if [[ "$?" != "0" ]]; then
        echo "Fail to seal data!"
        exit 1
    fi

    if [[ ! "$output" =~ "Sealing data succeeded" || ! "$output" =~ "Unseal succeeded" ]]; then
        echo "Fail to create the secure channel!"
        exit 1
    fi
    echo "sgx_seal_unseal_enclave PASS!"
}

sgx_enclave_multiple(){
    source /opt/intel/sgxsdk/environment

    cd $(dirname $0)
    rm -rf enclave.signed.so && ln -s enclave_small.signed.so enclave.signed.so
    output=`yes " " | SampleEnclave`

    if [[ "$?" != "0" ]]; then
        echo "Fail to create Enclave!"
        exit 1
    fi

    if [[ ! "$output" =~ "SampleEnclave successfully returned" ]]; then
        echo "Fail to create the Enclave!"
        exit 1
    fi
    echo "sgx_enclave PASS!"
}

sgx_enclave_stack40000(){
    source /opt/intel/sgxsdk/environment

    cd $(dirname $0)
    rm -rf enclave.signed.so && ln -s enclave_huge.signed.so enclave.signed.so
    output=`yes " " | SampleEnclave_huge`

    if [[ "$?" != "0" ]]; then
        echo "Fail to create Enclave!"
        exit 1
    fi

    if [[ ! "$output" =~ "SampleEnclave successfully returned" ]]; then
        echo "Fail to create the Enclave!"
        exit 1
    fi
    echo "sgx_enclave_stack40000 PASS!"
}

sgx_enable(){
    str_fail="SGX_enable test failed"
    flag=0
    output=$(lscpu | grep sgx)
    #change into array, separated by space
    output=(${output})
    #${#names[@]} represent the length of array
    for((i = 0; i < ${#output[@]}; i++)); do
       if [[ "${output[$i]}" == "sgx" ]]; then
           flag=$((flag|1))
       elif test ${output[$i]} == "sgx_lc"; then
           flag=$((flag|2))
       fi
    done
    #echo $flag
    if [[ "$flag" -ne "3" ]];then
        echo "$str_fail:lscpu | grep sgx"
        exit 1
    fi

    #----------------------------------------
    ret=$(cpuid -1 -l 0x12 -s 0x1 -r)
    ret=${ret% ebx*}
    ret=${ret#*eax=}
    ret=$((ret>>4 &1))
    if [[ "$ret" != "1" ]]
    then
        echo "$str_fail:cpuid -1 -l 0x12 -s 0x1 -r"
    fi
    #--------------------------------
    res1=$(ls /dev/sgx* | grep /dev/sgx_enclave)
    res2=$(ls /dev/sgx* | grep /dev/sgx_provision)
    res3=$(ls /dev/sgx* | grep /dev/sgx_vepc)
    if [[ "$res1" == "" || "$res2" == "" || "$res3" == "" ]]
    then
        echo "$str_fail:ls /dev/sgx*"
        exit 1
    fi

    echo "SGX_enable test passed"
}

sgx_edmm_detect() {
    local ret=0
    local cpuid_value=0
    local i=0

    cpuid | grep -i sgx || ret=1
    if [ $ret -eq 1 ]; then
        echo ""
    fi

    for((i=0;i<=1;i++)); do
        cpuid_check 12 0 0 0 a $i | grep "Return:" > /tmp/cpuid.log
        cpuid_value=`cat /tmp/cpuid.log | awk -F: '{print $2}' | awk -F. '{print $1}'`
        if [ ${cpuid_value} -neq 1 ];then
            ret=1
            echo "CPUID.(EAX=12H, ECX=0H).EAX[$i] is not 1!"
        fi
    done

    if [ $ret -eq 0 ];then
        echo "SGX EDMM is supported! Test passed."
    else
        echo "SGX EDMM is not supported! Test Failed."
        exit 1
    fi
}

sgx_no_heap_expansion () {
    source /opt/intel/sgxsdk/environment

    cd $(dirname $0)
    rm -rf enclave.signed.so && ln -s enclave_noheap_expansion.signed.so enclave.signed.so
    output=`yes " " | SampleEnclave_noheap_expansion`

    if [[ "$?" != "0" ]]; then
        echo "Fail to create Enclave!"
        exit 1
    fi

    if [[ ! "$output" =~ "SampleEnclave successfully returned" ]]; then
        echo "Fail to create the Enclave!"
        exit 1
    fi
    echo "sgx_no_heap_expansion PASS!"
}

sgx_expand_heap () {
    source /opt/intel/sgxsdk/environment

    cd $(dirname $0)
    rm -rf enclave.signed.so && ln -s enclave_expand_heap.signed.so enclave.signed.so
    output=`yes " " | SampleEnclave_expand_heap`

    if [[ "$?" != "0" ]]; then
        echo "Fail to create Enclave!"
        exit 1
    fi

    if [[ ! "$output" =~ "SampleEnclave successfully returned" ]]; then
        echo "Fail to create the Enclave!"
        exit 1
    fi
    echo "sgx_expand_heap PASS!"
}

sgx_no_stack_expansion () {
    source /opt/intel/sgxsdk/environment

    cd $(dirname $0)
    rm -rf enclave.signed.so && ln -s enclave_nostack_expansion.signed.so enclave.signed.so
    output=`yes " " | SampleEnclave_nostack_expansion`

    if [[ "$?" != "0" ]]; then
        echo "Fail to create Enclave!"
        exit 1
    fi

    if [[ ! "$output" =~ "SampleEnclave successfully returned" ]]; then
        echo "Fail to create the Enclave!"
        exit 1
    fi
    echo "sgx_no_stack_expansion PASS!"
}

sgx_expand_stack () {
    source /opt/intel/sgxsdk/environment

    cd $(dirname $0)
    rm -rf enclave.signed.so && ln -s enclave_expand_stack.signed.so enclave.signed.so
    output=`yes " " | SampleEnclave_expand_stack`

    if [[ "$?" != "0" ]]; then
        echo "Fail to create Enclave!"
        exit 1
    fi

    if [[ ! "$output" =~ "SampleEnclave successfully returned" ]]; then
        echo "Fail to create the Enclave!"
        exit 1
    fi
    echo "sgx_expand_stack PASS!"
}

if [[ ${1} == "" ]]
then
    echo "please enter one argument"
else
    case "${1}" in
        "sgx_numa_prealloc")
	sgx_numa_prealloc
	;;

        "sgx_local_attestation")
	sgx_local_attestation
	;;

        "sgx_seal_unseal_enclave")
	sgx_seal_unseal_enclave
	;;

        "sgx_enclave_multiple")
	sgx_enclave_multiple
	;;

        "sgx_enclave_stack40000")
	sgx_enclave_stack40000
	;;

        "sgx_enable")
	sgx_enable
	;;
	"sgx_edmm_detect")
            sgx_edmm_detect
            ;;
        "sgx_no_heap_expansion")
            sgx_no_heap_expansion
            ;;
        "sgx_expand_heap")
            sgx_expand_heap
            ;;
        "sgx_no_stack_expansion")
            sgx_no_stack_expansion
            ;;
        "sgx_expand_stack")
            sgx_expand_stack
            ;;

        *)
	echo "wrong argument"
        ;;
    esac
fi

