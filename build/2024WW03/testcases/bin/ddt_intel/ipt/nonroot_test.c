/**
 *   Copyright © Intel, 2018
 *
 *   This file is part of IPT tests.
 *
 *   IPT tests is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Lesser General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   IPT tests is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU Lesser General Public License for more details.
 *
 *   You should have received a copy of the GNU Lesser General Public
 *   License along with IPT tests.  If not, see <http://www.gnu.org/licenses/>.
 *
 *
 * File:         nonroot_test.c
 *
 * Description:  non priviledge for Intel® Processor Trace driver
 *
 * Author(s):    Ammy Yi <ammy.yi@intel.com>
 *
 * Date:         08/29/2018
 */


#include "utils.h"
#include "evint.h"


/**
 * non priviledge full/snapshot trace check :
 *  will set exclude_kernel=1 and run as non priviledge to check if we can get trace
 *	PASS will return 0 and FAIL will return 1
 */
int non_pri_test(int mode) {
	unsigned FAIL=0;
	struct perf_event_attr attr={};
	struct perf_event_mmap_page * pmp;
	int fde,fdi;
	long bufSz;
	uint64_t ** bufM=NULL, head;

//	Set buffersize as 2 pagesize
	bufSz = 2 * PAGESIZE;
//initial attribute for IPT
	iniEvtAttr(&attr);

	attr.exclude_kernel=1;

	//only get trace for own pid
	fde = sys_perf_event_open(&attr, 0, -1, -1, 0);
	if (fde < 0) {
		perror("perf_event_open");
		FAIL = 1;
		goto onerror;
	}
	/* map event : full */
	if(mode == 1){
		printf("full trace\n");
		bufM =  creaMap(fde,bufSz,1,&fdi);
	}
	if(mode == 2){
		printf("snapshot trace\n");
		bufM =  creaMap(fde,bufSz,0,&fdi);
	}

	if (!bufM || (bufM)[0]==MAP_FAILED || (bufM)[1]==MAP_FAILED) {
		perror("Full Trace creaMap");

		close(fde);
		FAIL = 1;
		goto onerror;
	}

	/* enable tracing */
	if(ioctl(fde, PERF_EVENT_IOC_RESET) != 0) {
		printf("ioctl with PERF_EVENT_IOC_RESET is failed!\n");
		FAIL = 1;
	}
	if(ioctl(fde, PERF_EVENT_IOC_ENABLE) != 0) {
		printf("ioctl with PERF_EVENT_IOC_ENABLE is failed!\n");
		FAIL = 1;
	}

	/* stop tracing */
	if(ioctl(fde, PERF_EVENT_IOC_DISABLE) != 0) {
		printf("ioctl with PERF_EVENT_IOC_DISABLE is failed!\n");
		FAIL = 1;
	}

	printf("bufSz = %ld\n", bufSz);
	pmp = (struct perf_event_mmap_page * )bufM[0];
  head = (*(volatile uint64_t *)&(pmp->aux_head));
	printf("head = %ld \n", head);
	if (head == 0){
		FAIL = 1;
		printf("No trace generated!\n");
	}

	/* unmap and close */
	delMap(bufM,bufSz,1,fdi);
	close(fde);
onerror :
	printf("non priviledge trace check %s\n",FAIL ? "FAIL":"PASS");

	return FAIL;
}

/**
 * non priviledge test :
 *	Will check if non priviledge can get trace with full mode and snapshot mode
 *	PASS will return 0 and FAIL will return 1
 *	If skip case will return 2
 *  CASE ID=1 for full; CASE ID=2 for snapshot
 */
int main(int argc,char *argv[]) {
	int CASEID;
	int result = 0;
	//full trace mode = 1, snapshot mode = 2
	int mode = 0;
	if (argc==2) CASEID = atoi(argv[1]);
	printf("CASE ID = %d\n", CASEID);

	switch (CASEID) {
		case 1:
		// will check
			mode=1;
			result = non_pri_test(mode);
			break;
		case 2:
			mode=2;
			result = non_pri_test(mode);
			break;
		default:
			printf("CASE ID is invalid, please input valid ID!\n");
			result = 2;
			break;
	}
	printf("CASE result = %d \n", result);
	return result;
}
