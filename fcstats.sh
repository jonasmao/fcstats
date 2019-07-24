#!/bin/bash

cc_test='\n
#include <stdio.h>\n
#include <stdlib.h>\n
#include <string.h>\n
#include <errno.h>\n
#include <sys/types.h>\n
#include <sys/stat.h>\n
#include <unistd.h>\n
#include <sys/mman.h>\n
#include <fcntl.h>\n
int main(int argc, char *argv[])\n
{\n
	char *file_tmp = argv[1]; \n

	int fd = open(file_tmp,O_RDONLY,0);\n
	struct stat buf;\n
	if (stat(file_tmp, &buf) < 0) {\n
		printf("stat %s fail: %s",file_tmp, strerror(errno));\n
		close(fd);\n
		return 0;\n
	}\n
	long len = buf.st_size;\n
	char *start = mmap(NULL, len,PROT_NONE, MAP_SHARED, fd,0);\n
	if (start == MAP_FAILED){\n
		close(fd);\n
		printf("mamp %s fail: %s", file_tmp, strerror(errno));\n
		return 0;\n
	}\n
	int size = (len + sysconf(_SC_PAGESIZE) - 1) /sysconf(_SC_PAGESIZE);\n
	unsigned char *vec = malloc(size+1);\n
	memset(vec, 0, size+1);\n
	int ret = mincore(start, len, vec);\n
	if (ret != 0) {\n
		close(fd);\n
		printf("mincore failed : %s", strerror(errno));\n
		munmap(start, len);\n
		return 0;\n
	}\n	
	int index, page_cache=0;\n
	for (index=0; index<size; index++) {\n
		if (vec[index] & 0x1) page_cache++;\n
	}\n
	free(vec);\n
	munmap(start, len);\n
	close(fd);\n
	printf("%d",page_cache);\n
	return 0;\n
}\n
'

cc_tests_file="cc_test_tmp.c"
main_test_file="main_test_mincore"

if [ -f $cc_tests_file ]
then
	echo "the same file exists."
	exit 0
else
	echo -e $cc_test > $cc_tests_file
fi

gcc -o $main_test_file $cc_tests_file

fcstat=""
top=10


if [ $1 == "pid" ]
then
	fcstat="process"
	if [ $# == 2 ]
	then
		top=$2
	fi	
elif [ $1 == "file" ]
then
	fcstat="file"
	if [ $# == 2 ]
	then
		top=$2
	fi
else
	echo "fcstat [pid|file] [1-10]|[filename]"
	echo "--pid: find the process who use cache memory in [1-10] situsation"
	echo "--file: find out how many cache memory the file or dir being using."
	tmp_cc_file="cc_test_tmp.*"
	rm -rf $tmp_cc_file $main_test_file
	exit 0
fi

pagesz=`getconf PAGESIZE`

files=()
if [ $fcstat == "process" ]
then	
	pids=(`ps -aux | sort -k4,4nr | head -n $top|awk '{printf "%s ", $2}'`)
	names=(`ps -aux|sort -k4,4nr |head -n $top|awk '{printf "%s ", $11}'`)

	len=${#pids[@]}
	sizes=()

	for pid in ${pids[@]}
	do
		size_pid=0
	
		fl=(`lsof -p $pid|awk '/\//'|awk '{ printf "%s ", $9}'`)
		for i in ${fl[@]}
		do
			if [ $i != "/dev/null" ] && [ "$i" != "/" ] && [ "$i" != "NAME" ] && [ -f $i ]
			then
				sizet=`./$main_test_file $i`
				if [ $sizet -gt 0 ] 2>/dev/null
				then
					let sizeti=($sizet*$pagesz)
					let size_pid=($size_pid+$sizeti)
				fi
			fi			
		done
		sizes+=($size_pid)
	done
	
	printf "%-10s\t%-50s\t%-15s\n" "PID" "NAME" "CACHE_SIZE(Bytes)"
	for ((index=0; index<$len; index++)) 
	do
		printf "%-10s\t%-50s\t%-15s\n" ${pids[$index]} ${names[$index]} ${sizes[$index]}
	done	
fi


if [ $fcstat == "file" ]
then
	if [ -f $top ]
	then
		sizet=`./$main_test_file $top`
		if [ $sizet -gt 0 ] 2>/dev/null
		then
			let sizet=($sizet*$pagesz)	
		fi	
		printf "%-50s\t%-15s\n" "NAME" "CACHE_SIZE(Bytes)"
		printf "%-50s\t%-15s\n" $top $sizet

	elif [ -d $top ]
	then
		sizes=()
		fs_dict=()
		for i in `ls ${top}`
		do	
			size_pid=0
			if [ $i != "/dev/null" ] && [ "$i" != "/" ] && [ "$i" != "NAME" ] && [ -f $i ]
			then
				sizet=`./$main_test_file $i`		
				if [ $sizet -gt 0 ] 2>/dev/null
				then
					let sizeti=($sizet*$pagesz)
					let size_pid=($size_pid+$sizeti)
					sizes+=($size_pid)
					fs_dict+=($i)
				fi
			fi
		done	

		printf "%-50s\t%-15s\n" "NAME" "CACHE_SIZE(Bytes)"
		for ((index=0; index<${#fs_dict[@]}; index++)) 
		do
			printf "%-50s\t%-15s\n" ${fs_dict[$index]} ${sizes[$index]}
		done		


	else
		echo "the $top is not a file or dir"
	fi
fi

tmp_cc_file="cc_test_tmp.*"

rm -rf $tmp_cc_file $main_test_file
