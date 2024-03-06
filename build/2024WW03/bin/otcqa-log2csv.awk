# Copyright (c) 2012-2018 Intel Corporation
#
# Author:
#       Dwane Pottratz <dwane.pottratz@intel.com>
#
# History:
#       Feb 27, 2013 - (Dwane Pottratz) Created
#       Nov 21, 2013 - (Dwane Pottratz) Updated for SDK 19 and gcc 4.7
#       Apr 29, 2014 - (Sharron LIU) add "testout" notes to csv file for non-pass cases
#       Apr 29, 2014 - (Sharron LIU) repace "NOT_APPLICABLE" by "BLOCKED" for testkit-lite
#       Aug 12, 2014 - (Helia Correia) Output LTP results file to a csv format that fits TRC expectation
#       Aug 29, 2014 - (Helia Correia) Change program name to otcqa-log2csv.awk
#                                      Works now with 2 mandatory parameters:
#                                      - file from where to read Feature value
#                                      - LTP raw results file to be output in csv for TRC
#                                      About Feature value:
#                                      - for LTP for LCK, it is read from ltp/atm/resources/data/parameter-files
#                                      - for LTP for Android, it is generated dynamically, default value is "Kernel"
#       Aug 26, 2015 - (Wenzhong Sun) Revert to original parameter
#                                     Assign "feature" variable on the command line
#       Apr 12, 2018 - (Yixin Zhang) Update test result logic
#                                    - Only refer to the final exit value of a test case
#                                    - 2 => block, 32 => NA/TCONF
#                                    - TCONF is ignored temporary
#       Apr 18, 2018 - (Yixin Zhang) Update CSV format (header), add new columns
#                                    Add log for PASSED test cases
#                                    Add log for binary not found case
#                                    Add \n for logs
#                                    Change the delimiter to comma to adapt Windows Excel
#
# Interpret the output
#
# exit code 2 ==> blocked
# exit code 4 ==> not_applicable (NA)
# other nonzero exit code ==> failed
# exit code 0 ==> pass
# nothing ==> UNKNOWN (which is really fail)
#
# Useful links:
#       http://www.grymoire.com/Unix/Awk.html
#

# header for csv
BEGIN {
    printf("Feature,Test_ID,Result,Bug,Comment,Start_Time,Duration,Sysinfo,Kconfig,Dmesg,Log\n");
}

/^tag=/ {
    tc_name=substr($1,5)
    stime=substr($2,7)
}
# add "testout" notes to save test log
/<<<test_output>>>/,/<<<execution_status>>>/{
    if ($0=="<<<test_output>>>" || $0=="<<<execution_status>>>") {
        next
    }
    testout=testout$0"\\n"
}
# check binary not found
/initiation_status=/ {
    init_status=substr($1, 19)
    if (init_status!="\"ok\"") {testout=testout$0"\\n"}
}
/termination_type=exited termination_id/ {
    exit_val=substr($3,16)
    duration=substr($1,10)
    if (exit_val=="0") {result="Passed"}
    else if (exit_val=="2") {result="Blocked"}
    else if (exit_val=="32") {result="N/A"}
    else {result="Failed"}
    testout=testout$0"\\n"
}
/<<<test_end>>>/ {
    # ignore "unknown" test results
    if (tc_namei!="unknown") {
        # replace " to ' in log
        testout=gensub(/"/, "'", "g", testout)
        # remove the EOL '\\n' in log
        testout=gensub(/\\n$/, "", "g", testout)

        # replace " with ' in dmesg
        dmesg=gensub(/"/, "'", "g", dmesg)
        # replace newline character with literal newline characters in dmesg
        # note: if you are confused why there are so many backslash in the
        # second argument, please check:
        # https://www.gnu.org/software/gawk/manual/html_node/Gory-Details.html
        dmesg=gensub(/\n/, "\\\\n", "g", dmesg)

        printf("%s,%s,%s,,,%s,%s,%s,%s,\"%s\",\"%s\"\n", \
            feature, tc_name, result, stime, duration, \
            sysinfo, kconfig, dmesg, testout);
    }
    result="UNKNOWN"
    tc_name="unknown"
    testout=""
    stime=""
    duration=""
    # default value is FAILED
    exit_val="1"
}
