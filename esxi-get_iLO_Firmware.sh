#!/bin/bash
LIST="$PWD/list"
INFO_PATH="$PWD/info"
DIR_DATA="$PWD/data"
[[ -d "${INFO_PATH}" ]] || mkdir ${INFO_PATH}
[[ -d "${DIR_DATA}" ]] || mkdir ${DIR_DATA}

cat "$LIST" | xargs -n 1 -P 2 -I {} bash -c '
    iloip="{}"
    ilorest get info Name Version --select SoftwareInventory --url "${iloip}" -u admin -p $PASS > "$PWD/info/${iloip}_info"
'

rm -rf $DIR_DATA/*
for list in $INFO_PATH/*; do
	IP=$(echo "$list" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    	SYSROM=$(grep -A1 "Name=System ROM" $list | awk -F= '/Version/ {print $2}')
    	RSYSROM=$(grep -A1 "Redundant System ROM" $list | awk -F= '/Version/ {print $2}')
    	ILO=$(grep -A1 "iLO 5" $list | awk -F= '/Version/ {print $2}')
    	IE=$(grep -A1 "Innovation" $list | awk -F= '/Version/ {print $2}')
    	P816ia=$(grep -A1 "P816i-a SR Gen10" $list | awk -F= '/Version/ {print $2}')
    
	echo "$IP|$SYSROM|$RSYSROM|$ILO|$IE|$P816ia" >> $DIR_DATA/ver.csv
done
sort -t . -n -k 1,1 -k 2,2 -k 3,3 -k 4,4 $DIR_DATA/ver.csv > $DIR_DATA/sorted_ver.csv
