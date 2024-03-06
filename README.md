1.Prepare
===========
   - Get the Specialized TDX OSVE testing disk 
   - boot and the default kernel is "tdx-5.10"

   - put the xxx.qcow2 file to  /home/tdx/tdx-guest-validation/



2. How to run TDX testcase
============================

	
	./run.sh xxxx.qcow2

	Find the testcase log:
		.../tdx-guest-validation/log/LTP_tdx_guest_bat_tests.log
		.../tdx-guest-validation/log/LTP_tdx_guest_func_tests.log

3. How to run secure boot TDX testcase
=======================================

	./run.sh xxxx.qcow2 OVMF.inteltdx.secboot.fd
	
	Find the test case log:
	.../tdx-guest-validation/log/LTP_tdx_guest_secure_boot_test.log

	
	Pass:
	[    0.000000] secureboot: Secure boot enabled

	Failed:
	[    0.000000] secureboot: Secure boot disable
