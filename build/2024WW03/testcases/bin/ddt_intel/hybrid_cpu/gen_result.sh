#!/bin/sh

s_file=$1

result_log="$s_file".csv
t_file=temp.log


get_data() {
  key=$1
  echo "$1" > $t_file
  echo "key=$key"
  datas=$(cat $s_file | grep $key | awk '{print $3}')
  for data in $datas; do
    echo "$data" >> $t_file
  done
}

generate_results() {
  cp $result_log 1.log
  paste -d"," 1.log $t_file > $result_log
  rm 1.log
}

init_log() {
  echo "instance" > $result_log
  datas=$(cat $s_file | grep "instance" | awk '{print $3}')
  for data in $datas; do
    echo "$data" >> $result_log
  done  
}

init_log
path="./"
if [[ $# -gt 1 ]]; then
  path=$2
  echo "path =$path"
fi
key_file=$path/key.data
keys=$(cat $key_file)
for key in $keys; do
  get_data $key
  generate_results 
done
rm $t_file

