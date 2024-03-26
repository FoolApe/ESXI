#!/bin/bash
log_path="$PWD/iLo_${BMC}"
[[ -d "$log_path" ]] || mkdir $log_path
### Need to install ilorest tool first!!!
ilorest serverlogs --selectlog=AHS --directorypath=$log_path --customiseAHS="from=${start_date}&&to=${end_date}"   --url ${BMC} -u admin -p PASSWORD
