
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
FILES="/mnt/*"
LAST_BACKUP=$BACKUP_FOLDER/BACKUP_LAST
#Get date for naming backup folder
DATA=`date "+%y-%m-%d--%H:%M"`
DATE_SEC=`date "+%s"`
NEW_BACKUP=$BACKUP_FOLDER/"BACKUP-$DATA"

echo $NEW_BACKUP
#Mount the files in unix system
# mount -t cifs -o username=xxxxx,password=xxxxx,ro //xxxxxxx/d$ /mnt
#Copy all files from $FILES to $NEW_BACKUP. Do a Hard link with files in lik-dest
#Create as symbolic link of the newest backup as last-backup
rsync -azvh --progress --exclude='System Volume Information' --link-dest=$LAST_BACKUP $FILES $NEW_BACKUP && rm -rf $LAST_BACKUP && ln -s $NEW_BACKUP $LAST_BACKUP && echo "Backup Done"
NUMBER_OF_BACKUPS=`find $BACKUP_FOLDER -maxdepth 1  |grep -P "BACKUP-[A-Z,a-z,0-9,:,-]*[0-9]$" | wc -l`

if ((NUMBER_OF_BACKUPS > MAX_DAILY_BACKUPS)); then
	#Order all backups
	find $BACKUP_FOLDER -maxdepth 1  |grep -P "BACKUP-[A-Z,a-z,0-9,:,-]*[0-9]$" | sort -d| head -1 | xargs rm -rf
fi


#Weekly Backups
CONDITION=`date "+%u"`==WEEKLY_BABCKUP_DAY
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
