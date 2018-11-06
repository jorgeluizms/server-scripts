
backup_function() {
	if ((NUMBER_OF_BACKUPS==0)); then
		((TIME_EDIT=DATE_SEC-$4-1)) #To guarantee that a backup will be created
	else
		TIME_EDIT=`find $BACKUP_FOLDER -maxdepth 1  |grep -P "BACKUP-[A-Z,a-z,0-9,:,-]*[0-9]"$1"$" | sort -d --reverse| head -1 | xargs stat -c %Y`
	fi


	if ((($3)||(DATE_SEC-TIME_EDIT>=$4))); then
		cp -lr $LAST_BACKUP $NEW_BACKUP$1
		#logging
		if [ $? -eq 0 ]; then
			echo "$(date +%H:%M) Success: Backup $1 created." >>backup_log
		else
			echo "$(date +%H:%M) Fail: Backup $1 could not be created." >>backup_log
		fi
		NUMBER_OF_BACKUPS=`find $BACKUP_FOLDER -maxdepth 1  |grep -P "BACKUP-[A-Z,a-z,0-9,:,-]*[0-9]"$1"$" | wc -l`
		#Delete if Number of number of $1 backups is greater than $2
		if ((NUMBER_OF_BACKUPS >= $2)); then
			FILE=$(find $BACKUP_FOLDER -maxdepth 1  |grep -P "BACKUP-[A-Z,a-z,0-9,:,-]*[0-9]"$1"$" | sort -d| head -1) #Find oldest backup
                        rm -rf $FILE
			#logging
			if [ $? -eq 0 ]; then
				echo "$(date +%H:%M) Success: Number of $1 backups exceeded. $FILE deleted." >>backup_log
			else
				echo "$(date +%H:%M) FAIL: Number of $1 backups exceeded. $FILE could not be deleted." >>backup_log
			fi

		fi

	fi
}

START_SEC=`date "+%s"`
echo "Inicio: `date`"
#Configuration
MAX_DAILY_BACKUPS=7
MAX_WEEKLY_BACKUPS=5
MAX_MONTHLY_BACKUPS=4
MAX_YEARLY_BACKUPS=2
echo "\n\n~~~~~$(date)~~~~~\n">>backup_log

WEEKLY_BACKUP_DAY=6 #1 is Monday. Therefore six is Saturday.
MONTHLY_BACKUP_DAY=20 #
YEARLY_BACKUP_DAY=5 #Month is January and the day is defined here

#Declare all required variables
BACKUP_FOLDER=/mnt/NAS/Backup-Jorge

LAST_BACKUP=$(find $BACKUP_FOLDER -maxdepth 1  |grep -P "BACKUP-[A-Z,a-z,0-9,:,-]*[0-9]$" | sort -dr | head -1)
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
cat /home/more_jo/backup_input   | sed '/^#/ d'| sed '/^$/d' | while IFS=';' read -r NAME FOLDER_SOURCE FOLDER_DEST_OLD FOLDER_DEST_NEW OPTIONS CMD REMAINDER
do
#Create backup Dir
mkdir -p "$NEW_BACKUP$FOLDER_DEST_NEW"

####rsync case####
echo $OPTIONS
if [[ "$CMD" == "rsync" ]]; then
	eval "OPTIONS=($OPTIONS)"
	#Concateanate Command, options and, then, execute it.
	#cmd=(rsync -azvh --progress "${OPTIONS[@]}" --link-dest="$LAST_BACKUP$FOLDER_DEST_OLD" "$FOLDER_SOURCE" "$NEW_BACKUP$FOLDER_DEST_NEW")
	cmd=(rsync -azvh --iconv=ISO-8859-1,utf-8 --chmod=755 --progress "${OPTIONS[@]}" --link-dest="$LAST_BACKUP$FOLDER_DEST_OLD" "$FOLDER_SOURCE" "$NEW_BACKUP$FOLDER_DEST_NEW")
	"${cmd[@]}"

	#logging
	if [ $? -eq 0 ]; then
		echo "$(date +%H:%M) Success: rsync of ${NAME} was successfully finished." >>backup_log
	else
		echo "$(date +%H:%M) Fail: rsync of ${NAME} has failed." >>backup_log
	fi

####compact and cp case####
elif [[ "$CMD" == "cp" ]]; then
        FILE_DOES_NOT_EXIST=1
        if [ -f "$LAST_BACKUP$FOLDER_DEST_NEW/$NAME.lz" ]; then #file exists
        BACKUP_DATE=$(($(stat "$LAST_BACKUP$FOLDER_DEST_NEW/$NAME.lz" -c %Y)/60)) #in minutes
        FILE_DATE=$(($(stat $(find "$FOLDER_SOURCE" -type f -name "$NAME.*" | sort -k1.1n  |head -1) -c %Y)/60))
        FILE_DOES_NOT_EXIST=0
	else
	FILE_DATE=0
	BACKUP_DATE=0
	fi
        if ((("$FILE_DOES_NOT_EXIST" == 1)||("$FILE_DATE" > "$BACKUP_DATE"))); then
		echo $FOLDER_SOURCE
		echo $NAME
		FILE=$(find "$FOLDER_SOURCE" -type f -name "$NAME.*" | sort -k1.1n |head -1)
		echo "File to be copied: $FILE".
		time lzip -kv "$FILE"

		#logging
		if [ $? -eq 0 ]; then
			echo "$(date +%H:%M) Success: compress of ${NAME} was successfully finished." >>backup_log
		else
			echo "$(date +%H:%M) Fail: compress of ${NAME} has failed." >>backup_log
		fi
		mv "$FILE.lz" "$NEW_BACKUP$FOLDER_DEST_NEW/$NAME.lz"
		#logging
		if [ $? -eq 0 ]; then
			echo "$(date +%H:%M) Success: ${NAME}.lz was successfully copied to backup." >>backup_log
		else
			echo "$(date +%H:%M) Fail: ${NAME}.lz was not copied to backup." >>backup_log
		fi
        else
		echo "$(date +%H:%M) Warning: A more recent version of ${NAME}.lz not found." >>backup_log
		cp -l "$LAST_BACKUP$FOLDER_DEST_NEW/$NAME.lz" "$NEW_BACKUP$FOLDER_DEST_NEW/$NAME.lz"
		#logging
		if [ $? -eq 0 ]; then
			echo "$(date +%H:%M) Success: A hard link of previous ${NAME}.lz was made." >>backup_log
		else
			echo "$(date +%H:%M) Fail: ${NAME}.lz was not copied to backup." >>backup_log
		fi
        fi
        NUMBER_FILES=$(find "$FOLDER_SOURCE" -mtime -1 -type f | wc -l) #Check for daily files
	if (( "$NUMBER_FILES" == 0 )); then #if there are recent files to be copied.
            echo "$(date +%H:%M) Warning: Daily version of ${NAME}.lz not found." >>backup_log
	fi

fi
done
NUMBER_OF_BACKUPS=`find $BACKUP_FOLDER -maxdepth 1  |grep -P "BACKUP-[A-Z,a-z,0-9,:,-]*[0-9]$" | wc -l`

if ((NUMBER_OF_BACKUPS > MAX_DAILY_BACKUPS)); then
	#Order all backups
	FILE=$(find $BACKUP_FOLDER -maxdepth 1  |grep -P "BACKUP-[A-Z,a-z,0-9,:,-]*[0-9]$" | sort -d| head -1)
	rm -rf $FILE #Remove daily bakcup
	#logging
	if [ $? -eq 0 ]; then
		echo "$(date +%H:%M) Success: Number of daily backups exceeded. $FILE deleted." >>backup_log
	else
		echo "$(date +%H:%M) FAIL: Number of daily backups exceeded, but $FILE could not be deleted." >>backup_log
	fi

fi

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
CONDITION=`date "+%m"`==01" && "`date "+%d"`==$YEARLY_BACKUP_DAY
backup_function Y "$MAX_YEARLY_BACKUPS" "$CONDITION" "$DELTA_SEC"

END_SEC=`date "+%s"`
echo "Fim: `date`"
echo "Tempo Total (segundos): "`expr $END_SEC - $START_SEC`
