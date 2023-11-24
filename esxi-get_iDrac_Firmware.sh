#!/bin/bash
LIST_IDRAC="$PWD/list"
INFO_PATH="$PWD/info"
DIR_DATA="$PWD/data"
CARD_INFO_PATH="$PWD/card_info"
[[ -d "${INFO_PATH}" ]] || mkdir ${INFO_PATH}
[[ -d "${DIR_DATA}" ]] || mkdir ${DIR_DATA}
[[ -d "${CARD_INFO_PATH}" ]] || mkdir ${CARD_INFO_PATH}

cat "$LIST_IDRAC" | xargs -n 1 -P 15 -I {} bash -c '
    idracip="{}"
    racadm -r $idracip -u root -p $PASS --nocertwarn getsysinfo > "$PWD/info/${idracip}_info"
    racadm -r $idracip -u root -p $PASS --nocertwarn  raid get controllers -o |grep "FirmwareVersion"|awk "NR==1"|awk "{print $3}" > "$PWD/card_info/${idracip}_card"
'
rm -rf $DIR_DATA/*
for info_list in $PWD/info/*_info;do
    IP=$(echo "$info_list" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    BIOS=$(grep "System BIOS Version" $info_list |awk '{print $5}')
    IDRAC=$(grep "Firmware Version" $info_list |awk '{print $4}')
    RIDRAC=$(grep "Last Firmware Update" $info_list |awk '{print $5}')
    RAIDCARD=""
    if [ -f "$PWD/card_info/${IP}_card" ]; then
        RAIDCARD=$(grep "FirmwareVersion" "$PWD/card_info/${IP}_card" | awk 'NR==1'|awk '{print $3}')
    fi
    echo "$IP|$BIOS|$IDRAC|$RIDRAC|$RAIDCARD" >> $DIR_DATA/ver.csv
done
sort -t . -n -k 1,1 -k 2,2 -k 3,3 -k 4,4 $DIR_DATA/ver.csv > $DIR_DATA/sorted_ver.csv
