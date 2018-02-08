
backup_function() {
NUMBER_OF_BACKUPS=`find $BACKUP_FOLDER -maxdepth 1  |grep -P "BACKUP-[A-Z,a-z,0-9,:,-]*[0-9]"$1"$" | wc -l`
if ((NUMBER_OF_BACKUPS==0)); then
((TIME_EDIT=DATE_SEC-$4-1)) #To guarantee that a backup will be created
else
TIME_EDIT=`find $BACKUP_FOLDER -maxdepth 1  |grep -P "BACKUP-[A-Z,a-z,0-9,:,-]*[0-9]"$1"$" | sort -d --reverse| head -1 | xargs stat -c %Y`
fi


if ((($3)||(DATE_SEC-TIME_EDIT>=$4))); then
cp -lr $LAST_BACKUP $NEW_BACKUP$1
#Delete if Number of number of weekly backups is greater than MAX_WEEKLY_BACKUPS
if ((NUMBER_OF_BACKUPS >= $2)); then
	#Order all backups
	find $BACKUP_FOLDER -maxdepth 1  |grep -P "BACKUP-[A-Z,a-z,0-9,:,-]*[0-9]"$1"$" | sort -d| head -1 | xargs rm -rf
fi

fi
}
START_SEC=`date "+%s"`
echo "Inicio: `date`"
#Configuration
MAX_DAILY_BACKUPS=5
MAX_WEEKLY_BACKUPS=3
MAX_MONTHLY_BACKUPS=3
MAX_YEARLY_BACKUPS=1

WEEKLY_BACKUP_DAY=6 #1 is Monday. Therefore six is Saturday.
MONTHLY_BACKUP_DAY=20 #
YEARLY_BACKUP_DAY=5 #Month is January and the day is defined here

#Declare all required variables
BACKUP_FOLDER=/Backup

#FILES="/mnt/MOTO /mnt/XML /mnt/ALMOXARIFADO /mnt/QUALIDADE /mnt/CONTABILIDADE"
LAST_BACKUP=$BACKUP_FOLDER/BACKUP_LAST
#Get date for naming backup folder
DATA=`date "+%y-%m-%d--%H:%M"`
DATE_SEC=`date "+%s"`
NEW_BACKUP=$BACKUP_FOLDER/"BACKUP-$DATA"
mkdir $NEW_BACKUP
echo $NEW_BACKUP
#Mount the files in unix system
#sudo mount -t cifs -o username=xxxxxx,password=xxxxxx,ro,vers=2.0 '//xxxxxxxx' /mnt
#Copy all files from $FILES to $NEW_BACKUP. Do a Hard link with files in lik-dest
#Create as symbolic link of the newest backup as last-backup

#Read all backups to be made
cat backup_input   | sed '/^#/ d'| sed '/^$/d' | while IFS=';' read -r NAME FOLDER_SOURCE FOLDER_DEST_OLD FOLDER_DEST_NEW OPTIONS CMD REMAINDER
do
#Create Dir
mkdir -p "$NEW_BACKUP$FOLDER_DEST_NEW"

if [[ "$CMD" == "rsync" ]]; then #Execute rsync
	eval OPTIONS=($OPTIONS)
#Concateanate Command and Options
cmd=(rsync -azvh --progress "${OPTIONS[@]}" --link-dest="$LAST_BACKUP$FOLDER_DEST_OLD" "$FOLDER_SOURCE" "$NEW_BACKUP$FOLDER_DEST_NEW")

if [ $? -eq 0 ]; then
echo "SUCCESS: "$(date)" ${NAME}" >>backup_log
fi
#Execute Command
"${cmd[@]}"
elif [[ "$CMD" == "cp" ]]; then #Execute Compact
echo "SUCCESS: cp"
NUMBER_FILES=$(find "$FOLDER_SOURCE" -mtime -1 -type f | wc -l)
if[[ $NUMBER_FILES == 1 ]]; then
FILE=$(find "$FOLDER_SOURCE" -mtime -1 -type f | sort -k1.1n  --reverse |head -1)
echo "$FILE"
time lzip -kv "$FILE"
mv "$FILE.lz" "$NEW_BACKUP$FOLDER_DEST_NEW/$NAME.lz"
#else
#echo "FILE NOT FOUND - ERROR"
$fi

fi
done
NUMBER_OF_BACKUPS=`find $BACKUP_FOLDER -maxdepth 1  |grep -P "BACKUP-[A-Z,a-z,0-9,:,-]*[0-9]$" | wc -l`

if ((NUMBER_OF_BACKUPS > MAX_DAILY_BACKUPS)); then
	#Order all backups
	find $BACKUP_FOLDER -maxdepth 1  |grep -P "BACKUP-[A-Z,a-z,0-9,:,-]*[0-9]$" | sort -d| head -1 | xargs rm -rf
fi

rm -rf $LAST_BACKUP
ln -s $NEW_BACKUP $LAST_BACKUP #It is done even when there are errors

#Weekly Backups
CONDITION=`date "+%u"`==WEEKLY_BACKUP_DAY
((DELTA_SEC=3600*24*8))
backup_function W $MAX_WEEKLY_BACKUPS $CONDITION $DELTA_SEC

#Monthly Backups
((DELTA_SEC=3600*24*32))
CONDITION=`date "+%m"`==MONTHLY_BACKUP_DAY
backup_function M $MAX_MONTHLY_BACKUPS $CONDITION $DELTA_SEC

((DELTA_SEC=3600*24*367))
#Yearly Backups
CONDITION=`date "+%m"`==01"&&"`date "+%d"`==YEARLY_BACKUP_DAY
backup_function Y $MAX_YEARLY_BACKUPS $CONDITION $DELTA_SEC

END_SEC=`date "+%s"`
echo "Fim: `date`"
echo "Tempo Total (segundos): "`expr $END_SEC - $START_SEC`
