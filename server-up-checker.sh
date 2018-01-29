#!/bin/sh
FOLDER=/home/more_jo/devel/server-scripts
cd $FOLDER
#Build list of servers to be read
echo "SELECT IP, id from servers ;" | mysql -u dummy Polimet| sed -n '1!p'>servers.txt
#Automatically computes ping for each server in servers.txt
while IFS='' read -r line || [[ -n "$line" ]]; do
line_data=( $line )
ping -c 1 ${line_data[0]} &>/dev/null
if (($?==0)); then
server_status="'online'"
else
server_status="'offline'"
fi
echo ${line_data[0]}": " $server_status
mysql -u dummy -D Polimet -e "INSERT INTO uptimes VALUES (${line_data[1]},$server_status,NULL)";
done < "servers.txt"
