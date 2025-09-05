#!/bin/bash
#
# CUBRID Backup Script v1.4
# Copyright (c) 2020 CUBRID Corporation
#
# Version 1.0 : 2020.12.18 Created.
# Version 1.1 : 2021.03.29 ft_create_dummy_tbl(), ft_set_environment_variable() function Bug Fix.
# Version 1.2 : 2021.06.03 ft_copy_lob_dir() function Bug Fix.
# Version 1.3 : 2021.11.15 ft_copy_archive_dir() created (*WARNING* Check database.txt file "log-path")
#                          * You can copy archive logs only if the log-path of the database.txt file is [DBNAME]/log. 
# Version 1.4 : 2023.01.17 ft_init_info_variable(), ft_delete_old_backup() change $BACKUP_DIR path (*WARNING* Disk Full)
#                          * AS-IS : $BACKUP_DIR/[DATE]/[DBNAME]
#                          * TO-BE : $BACKUP_DIR/[DATE]/[DBNAME]/$BACKUP_LEVEL_DIR
#
 
# -------------------------------
# Common Variable
# -------------------------------
VERSION="v1.4 (64bit release build for linux_gnu) (Jan 17 2023)"
VERSION_SHORT="${VERSION%% (*}"
 
        # If Major Number is 0, only Release Number is displayed.
        if [ 0 -eq ${VERSION_SHORT:3:1} ];then
                VERSION_SHORT="${VERSION%%.*}"
        fi
 
# -------------------------------
# User Setting
# -------------------------------
DEFAULT_HOSTNAME=localhost
 
DEFAULT_ENV=$HOME/.cubrid.sh
 
DEFAULT_CUBRID=/home/cubrid/CUBRID
DEFAULT_TMPDIR=$CUBRID/tmp
DEFAULT_CUBRID_TMP=$CUBRID/var/CUBRID_SOCK
 
BACKUP_DIR=/home/cubrid/CUBRID/backupdb
 
BACKUP_OPTION="--no-check -z"

CREATE_DUMMY_TBL_USER_PW=""
 
# -------------------------------
# Sub Function
# -------------------------------
 
# Show help.
function ft_show_help() {
        echo ""
        echo "CUBRID Backup script $VERSION"
        echo ""
        echo "Usage: $0 <OPTIONS> | <COMMAND> "
        echo ""
        echo "Backup directory: $BACKUP_DIR"
        echo "If you want to change the backup directory, open the script file"
        echo "and change $BACKUP_DIR in User Settings."
        echo ""
        echo "Valid Options:"
        echo "  -v, --version     Shows the version"
        echo "  -h, --help        Show this help"
        echo ""
        echo "Available Command:"
        echo "  start             Start backup and manage old backup files."
        echo ""
        echo "Examples:"
        echo "  cubrid_backup_${VERSION_SHORT}.sh -v"
        echo "                    Shows the version"
        echo ""
}
 
# Show help.
function ft_show_start_help() {
        echo ""
        echo "CUBRID Backup script $VERSION"
        echo ""
        echo "Backup directory: $BACKUP_DIR"
        echo "If you want to change the backup directory, open the script file"
        echo "and change $BACKUP_DIR in User Settings."
        echo ""
        echo "Usage: $0 <start> DBNAME [LEVEL] [PERIOD]"
        echo ""
        echo "  DBNAME  Backup target database name"
        echo "  LEVEL   Backup level"
        echo "            LEVEL is allowed:"
        echo "              0 - full (default)"
        echo "              1 - incremental 1"
        echo "              2 - incremental 2"
        echo "  PERIOD  How long to delete old backup files."
        echo "            PERIOD is allowed:"
        echo "              0 - Do not delete all old backup file (default)"
        echo "              # - Positive integer"
        echo "            Delete backup files stored beyond PERIOD."
        echo "            However, it does not delete the backup files required"
        echo "            for incremental backup recovery."
        echo ""
        echo "The database name must be a database created in databases.txt."
        echo ""
        echo "Examples:"
        echo "  cubrid_backup_${VERSION_SHORT}.sh start demodb 0 7"
        echo "          Perform a full backup of the demodb database, and delete"
        echo "            the backup files stored for more than 7 days"
        echo "  cubrid_backup_${VERSION_SHORT}.sh start demodb 0 1"
        echo "          Perform a full backup of the demodb database, and delete"
        echo "            all old backup files except for the new one."
        echo ""
}
 
# Get version.
function ft_show_version() {
        echo ""
        echo "CUBRID Backup Script $VERSION"
        echo ""
}
 
# Set environment variable.
function ft_set_environment_variable() {
        . $DEFAULT_ENV
 
        if [ -z $CUBRID ]; then
                CUBRID=$DEFAULT_CUBRID
                CUBRID_DATABASES=$CUBRID/databases
 
                if [ ! -z $LD_LIBRARY_PATH ]; then
                        LD_LIBRARY_PATH=$CUBRID/lib:$LD_LIBRARY_PATH
                else
                        LD_LIBRARY_PATH=$CUBRID/lib
                fi
 
                PATH=$CUBRID/bin:$PATH
 
                TMPDIR=$DEFAULT_TMPDIR
                CUBRID_TMP=$DEFAULT_CUBRID_TMP
        fi
}
 
# Initialize info variable.
function ft_init_info_variable() {
        local DATABASE_INFO=`cat $CUBRID_DATABASES/databases.txt | grep ^$DATABASE_NAME[[:space:]]`
        DATABASE_LOG_DIR=`echo $DATABASE_INFO | awk '{print $4}'`
        DATABASE_LOB_DIR=`echo $DATABASE_INFO | awk '{print $5}' | sed s/file://g`
        DATABASE_JAVA_DIR=`echo $DATABASE_INFO | awk '{print $2}'`/java
        DATABASE_ARCHIVE_DIR=`echo $DATABASE_INFO | awk '{print $2}'`/log
 
        # Creating a backup-level directory name
        BACKUP_LEVEL_DIR="Full_backup"
 
        if [ $BACKUP_LEVEL -eq 1 ]; then
                BACKUP_LEVEL_DIR="First_incremental_backup"
        fi
 
        if [ $BACKUP_LEVEL -eq 2 ]; then
                BACKUP_LEVEL_DIR="Second_incremental_backup"
        fi
 
        BACKUP_DATE=`date +%Y%m%d`
        BACKUP_DATE_DATABASE_DIR="$BACKUP_DIR"/"$BACKUP_DATE"/"$DATABASE_NAME"/"$BACKUP_LEVEL_DIR"
        BACKUP_LOG_FILE=$BACKUP_DATE_DATABASE_DIR/backup_"$DATABASE_NAME"_"$BACKUP_DATE".log
        BACKUP_ERROR_FILE=$BACKUP_DATE_DATABASE_DIR/backup_"$DATABASE_NAME"_"$BACKUP_DATE".err
        BACKUP_OUT_FILE=$BACKUP_DATE_DATABASE_DIR/backup_"$DATABASE_NAME"_"$BACKUP_DATE".out
        BACKUP_SPACEDB_FILE=$BACKUP_DATE_DATABASE_DIR/backup_"$DATABASE_NAME"_"$BACKUP_DATE".spacedb
 
        if [ -d $BACKUP_DATE_DATABASE_DIR ]; then
                rm -rf $BACKUP_DATE_DATABASE_DIR > /dev/null
        fi
 
        mkdir -p $BACKUP_DATE_DATABASE_DIR > /dev/null
 
        echo "" >> $BACKUP_LOG_FILE
 
        echo "[LOG] CUBRID                   : $CUBRID" >> $BACKUP_LOG_FILE
        echo "[LOG] CUBRID_DATABASES         : $CUBRID_DATABASES" >> $BACKUP_LOG_FILE
        echo "[LOG] LD_LIBRARY_PATH          : $LD_LIBRARY_PATH" >> $BACKUP_LOG_FILE
        echo "[LOG] TMPDIR                   : $TMPDIR" >> $BACKUP_LOG_FILE
        echo "[LOG] CUBRID_TMP               : $CUBRID_TMP" >> $BACKUP_LOG_FILE
 
        echo "" >> $BACKUP_LOG_FILE
 
        echo "[LOG] DATABASE_NAME            : $DATABASE_NAME" >> $BACKUP_LOG_FILE
        echo "[LOG] DATABASE_LOG_DIR         : $DATABASE_LOG_DIR" >> $BACKUP_LOG_FILE
        echo "[LOG] DATABASE_LOB_DIR         : $DATABASE_LOB_DIR" >> $BACKUP_LOG_FILE
        echo "[LOG] DATABASE_JAVA_DIR        : $DATABASE_JAVA_DIR" >> $BACKUP_LOG_FILE
		echo "[LOG] DATABASE_ARCHIVE_DIR     : $DATABASE_ARCHIVE_DIR" >> $BACKUP_LOG_FILE
 
        echo "" >> $BACKUP_LOG_FILE
 
        echo "[LOG] BACKUP_LEVEL             : $BACKUP_LEVEL" >> $BACKUP_LOG_FILE
        echo "[LOG] BACKUP_PERIOD            : $BACKUP_PERIOD" >> $BACKUP_LOG_FILE
 
        echo "" >> $BACKUP_LOG_FILE
 
        echo "[LOG] BACKUP_DATE              : $BACKUP_DATE" >> $BACKUP_LOG_FILE
        echo "[LOG] BACKUP_DATE_DATABASE_DIR : $BACKUP_DATE_DATABASE_DIR" >> $BACKUP_LOG_FILE
        echo "[LOG] BACKUP_LOG_FILE          : $BACKUP_LOG_FILE" >> $BACKUP_LOG_FILE
        echo "[LOG] BACKUP_ERROR_FILE        : $BACKUP_ERROR_FILE" >> $BACKUP_LOG_FILE
        echo "[LOG] BACKUP_OUT_FILE          : $BACKUP_OUT_FILE" >> $BACKUP_LOG_FILE
        echo "[LOG] BACKUP_SPACEDB_FILE      : $BACKUP_SPACEDB_FILE" >> $BACKUP_LOG_FILE
 
        echo "" >> $BACKUP_LOG_FILE
}
 
# Show spacedb
function ft_show_spacedb() {
        df -h >> $BACKUP_SPACEDB_FILE 2>> $BACKUP_ERROR_FILE
 
        echo "" >> $BACKUP_SPACEDB_FILE
        echo "----------------------------------------" >> $BACKUP_SPACEDB_FILE
        echo "" >> $BACKUP_SPACEDB_FILE
 
        cubrid spacedb -p "$DATABASE_NAME"@"$DEFAULT_HOSTNAME" >> $BACKUP_SPACEDB_FILE 2>> $BACKUP_ERROR_FILE
 
        if [ $? -eq 0 ]; then
                echo "[LOG] Show spacedb : Ok" >> $BACKUP_LOG_FILE
        else
                echo "[LOG] Show spacedb : Fail " >> $BACKUP_LOG_FILE
        fi
 
        echo "" >> $BACKUP_SPACEDB_FILE
        echo "----------------------------------------" >> $BACKUP_SPACEDB_FILE
        echo "" >> $BACKUP_SPACEDB_FILE
 
        cubrid spacedb -p --size-unit=page "$DATABASE_NAME"@"$DEFAULT_HOSTNAME" >> $BACKUP_SPACEDB_FILE 2>> $BACKUP_ERROR_FILE
 
        if [ $? -eq 0 ]; then
                echo "[LOG] Show spacedb by purpose : Ok" >> $BACKUP_LOG_FILE
        else
                echo "[LOG] Show spacedb by purpose by page : Fail " >> $BACKUP_LOG_FILE
        fi
}
 
# Create and drop dummy table.
# - Prevents problems caused by Mvcc_op_log_lsa being smaller than Checkpoint.
# - csql> show log header;
function ft_create_dummy_tbl() {
        local DUMMY_TABLE_NAME="cubrid_backup_$(date +%Y%m%d%H%M)"
 
        # Connect to csql with a public account.
        csql -p "$CREATE_DUMMY_TBL_USER_PW" "$DATABASE_NAME"@"$DEFAULT_HOSTNAME" -c "CREATE TABLE $DUMMY_TABLE_NAME; DROP TABLE $DUMMY_TABLE_NAME;" > /dev/null 2>> $BACKUP_ERROR_FILE
 
        if [ $? -eq 0 ]; then
                echo "[LOG] Create and drop dummy table : Ok" >> $BACKUP_LOG_FILE
        else
                echo "[LOG] Create and drop dummy table : Fail " >> $BACKUP_LOG_FILE
        fi
}
 
# Backup database.
function ft_backup_database() {
        echo "" >> $BACKUP_LOG_FILE
 
        cubrid backupdb -D $BACKUP_DATE_DATABASE_DIR -l $BACKUP_LEVEL -o $BACKUP_OUT_FILE -C $BACKUP_OPTION "$DATABASE_NAME"@"$DEFAULT_HOSTNAME" >> $BACKUP_LOG_FILE 2>> $BACKUP_ERROR_FILE
 
        if [ $? -eq 0 ]; then
                echo "" >> $BACKUP_LOG_FILE
                echo "[LOG] Database : Ok" >> $BACKUP_LOG_FILE
        else
                echo "[LOG] Database : Fail" >> $BACKUP_LOG_FILE
                exit 1
        fi
 
        # In the case of incremental backup files, a backup information file is required to find the backup files required for recovery.
        cp "$DATABASE_LOG_DIR"/"$DATABASE_NAME"_bkvinf $BACKUP_DATE_DATABASE_DIR/ > /dev/null 2>> $BACKUP_ERROR_FILE
 
        if [ $? -eq 0 ]; then
                echo "[LOG] Copy backup information file : Ok" >> $BACKUP_LOG_FILE
        else
                echo "[LOG] Copy backup information file : Fail" >> $BACKUP_LOG_FILE
        fi
}
 
# Copy configuration directory.
function ft_copy_conf_dir() {
        cp -r $CUBRID/conf "$BACKUP_DATE_DATABASE_DIR"/ > /dev/null 2>> $BACKUP_ERROR_FILE
 
        if [ $? -eq 0 ]; then
                echo "[LOG] Copy configuration directory : Ok" >> $BACKUP_LOG_FILE
        else
                echo "[LOG] Copy configuration directory : Fail" >> $BACKUP_LOG_FILE
        fi
}
 
# Copy lob directory.
function ft_copy_lob_dir() {
    if [ ! -d $DATABASE_LOB_DIR ]; then
        mkdir -p $DATABASE_LOB_DIR > /dev/null 2>> $BACKUP_ERROR_FILE
 
        if [ $? -eq 0 ]; then
            echo "[LOG] Create lob directory : Ok" >> $BACKUP_LOG_FILE
        else
            echo "[LOG] Create lob directory : Fail" >> $BACKUP_LOG_FILE
        fi
 
        return 0
    fi
 
    if [ `ls -Al $DATABASE_LOB_DIR | wc -l` -eq 1 ]; then
        return 0
    fi
 
    if [ ! -d "$BACKUP_DATE_DATABASE_DIR"/lob ]; then
        mkdir -p "$BACKUP_DATE_DATABASE_DIR"/lob > /dev/null 2>> $BACKUP_ERROR_FILE
 
        if [ $? -eq 0 ]; then
            echo "[LOG] Create backup lob directory : Ok" >> $BACKUP_LOG_FILE
        else
            echo "[LOG] Create backup lob directory : Fail" >> $BACKUP_LOG_FILE
        fi
    fi
 
    local CP_PIDS=""
    local ALL_SUCCESS_YN="Y"
    local MAX_SIZE="0"
    local MAX_PID=""
    local CURRENT_SIZE=""
 
    # Find the PID with the largest size of Lob folder
    # Execute the copy command in 10 multi-processes.
    for i in {0..9}; do
        CURRENT_SIZE=`du -cs $DATABASE_LOB_DIR/ces_*"$i" | grep total | sed 's/[^0-9]//g'`
         
        if [  $MAX_SIZE -le $CURRENT_SIZE ] ; then
            MAX_SIZE="$CURRENT_SIZE"
            MAX_PID="$i"
        fi
 
        cp -rf $DATABASE_LOB_DIR/ces_*"$i" "$BACKUP_DATE_DATABASE_DIR"/lob/ > /dev/null 2>> $BACKUP_ERROR_FILE &
 
        CP_PIDS+=($!)
    done
 
    # Wait until time of the MAX_PID is finished and check it's copied accurately.
    if wait ${CP_PIDS[$MAX_PID]}; then
        for i in {0..9}; do
             
            local ORIGIN_LOB_COUNT=`ls -al $DATABASE_LOB_DIR/ces_*$i | wc -l`
            local BACKUP_LOB_COUNT=`ls -al "$BACKUP_DATE_DATABASE_DIR"/lob/ces_*$i | wc -l`
 
            if [ $ORIGIN_LOB_COUNT -eq $BACKUP_LOB_COUNT ]; then
                echo "[LOG] Copy ces_##$i lob directory : Ok" >> $BACKUP_LOG_FILE
            else
                ALL_SUCCESS_YN="N"
                echo "[LOG] Copy ces_##$i lob directory : Fail" >> $BACKUP_LOG_FILE
            fi
        done
    fi
 
    if [ $ALL_SUCCESS_YN == "Y" ]; then
        echo "[LOG] Copy all lob directory : Ok" >> $BACKUP_LOG_FILE
    else
        echo "[LOG] Copy all lob directory : Fail" >> $BACKUP_LOG_FILE
    fi
}
 
# Copy java directory.
function ft_copy_java_dir() {
        if [ ! -d $DATABASE_JAVA_DIR ]; then
                return 0
        fi
 
        if [ `ls -Al $DATABASE_JAVA_DIR | wc -l` -eq 1 ]; then
                return 0
        fi
 
        cp -r $DATABASE_JAVA_DIR "$BACKUP_DATE_DATABASE_DIR"/ > /dev/null 2>> $BACKUP_ERROR_FILE
 
        if [ $? -eq 0 ]; then
                echo "[LOG] Copy java directory : Ok" >> $BACKUP_LOG_FILE
        else
                echo "[LOG] Copy java directory : Fail" >> $BACKUP_LOG_FILE
        fi
}

# Copy archive directory.
function ft_copy_archive_dir() {
        if [ ! -d $DATABASE_ARCHIVE_DIR ]; then
                return 0
        fi
 
        if [ `ls -Al $DATABASE_ARCHIVE_DIR | wc -l` -eq 1 ]; then
                return 0
        fi
 
        cp -r $DATABASE_ARCHIVE_DIR "$BACKUP_DATE_DATABASE_DIR"/ > /dev/null 2>> $BACKUP_ERROR_FILE
 
        if [ $? -eq 0 ]; then
                echo "[LOG] Copy archive directory : Ok" >> $BACKUP_LOG_FILE
        else
                echo "[LOG] Copy archive directory : Fail" >> $BACKUP_LOG_FILE
        fi
}
 
# Delete old backup files out of storage period.
function ft_delete_old_backup() {
        local ALL_DELETE_YN="N"
 
        local DELETE_DATE=`date +%Y%m%d -d "$BACKUP_PERIOD day ago"`
 
        echo "" >> $BACKUP_LOG_FILE
        echo "[LOG] DELETE_DATE              : $DELETE_DATE" >> $BACKUP_LOG_FILE
        echo "" >> $BACKUP_LOG_FILE
 
        # The backup date of the backup file needed to restore the backup file being searched.
        # - Initialise to current date.
        local NEED_PREV_BACKUP_DATE=$BACKUP_DATE
 
        local YYYYMMDD="[1-9][0-9]{3,}[0-1][0-9][0-3][0-9]"
 
        # Array that stores all backup date directories in reverse order.
        # * When using the -d option in the ls command, it must end with '/'.
        local ALL_BACKUP_DATE=`ls -dlr "$BACKUP_DIR"/*/ | awk -F '/' '{print $(NF-1)}' | grep -E "^$YYYYMMDD$"`
 
        # Search all backup date directories in reverse order.
        # * BACKUP_DATE_ALL_LEVEL = Stores the backup levels in reverse order within all backup date directories.
        # * BACKUP_DATE_LAST_LEVEL = Finds the value of the last row of the backup level stored in reverse order.
        for TEMP_BACKUP_DATE in ${ALL_BACKUP_DATE[@]}; do
                local TEMP_BACKUP_DATE_DIR="$BACKUP_DIR"/"$TEMP_BACKUP_DATE"
                local BACKUP_DATE_ALL_LEVEL=`ls -dlr "$BACKUP_DIR"/"$TEMP_BACKUP_DATE"/"$DATABASE_NAME"/*_backup/ | awk '{print $9}'`
                local BACKUP_DATE_LAST_LEVEL=`ls -dlr "$BACKUP_DIR"/"$TEMP_BACKUP_DATE"/"$DATABASE_NAME"/*_backup/ | awk -F '/' '{print $(NF-1)}' | tail -n 1`
                local TEMP_BACKUP_DATE_DATABASE_DIR="$TEMP_BACKUP_DATE_DIR"/"$DATABASE_NAME"/"$BACKUP_DATE_LAST_LEVEL"
 
 
                # Delete the backup file being searched.
                if [ $ALL_DELETE_YN == "Y" ]; then
                        rm -rf $BACKUP_DATE_ALL_LEVEL > /dev/null 2>> $BACKUP_ERROR_FILE

                        if [ $? -eq 0 ]; then
                                echo "[LOG] Delete old backup directory - $BACKUP_DATE_ALL_LEVEL : Ok" >> $BACKUP_LOG_FILE
                        else
                                echo "[LOG] Delete old backup directory - $BACKUP_DATE_ALL_LEVEL : Fail" >> $BACKUP_LOG_FILE
                        fi

                        # Delete empty backup database_name directory.
                        if [ `ls -Al $TEMP_BACKUP_DATE_DIR | wc -l` -eq 2 ]; then
                                rmdir $TEMP_BACKUP_DATE_DIR/"$DATABASE_NAME" > /dev/null 2>> $BACKUP_ERROR_FILE
                        fi

                        # Delete empty backup date directory.
                        if [ `ls -Al $TEMP_BACKUP_DATE_DIR | wc -l` -eq 1 ]; then
                                rmdir $TEMP_BACKUP_DATE_DIR > /dev/null 2>> $BACKUP_ERROR_FILE
                        fi

                        if [ $? -eq 0 ]; then
                                echo "[LOG] Delete old backup date directory - $TEMP_BACKUP_DATE_DIR : Ok" >> $BACKUP_LOG_FILE
                        else
                                echo "[LOG] Delete old backup date directory - $TEMP_BACKUP_DATE_DIR : Fail" >> $BACKUP_LOG_FILE
                        fi
 
                        continue
                fi
 
                # Backup files within the storage period will be skipped.
                # - $TEMP_BACKUP_DATE > $DELETE_DATE
                if [ $TEMP_BACKUP_DATE -gt $DELETE_DATE ]; then
                        NEED_PREV_BACKUP_DATE=`cat "$TEMP_BACKUP_DATE_DATABASE_DIR"/"$DATABASE_NAME"_bkvinf 2>> $BACKUP_ERROR_FILE | grep v000 | sort -r | head -2 | tail -1 | awk -F '/' '{print $(NF-3)}'`
 
                        if [ -z $NEED_PREV_BACKUP_DATE ]; then
                                NEED_PREV_BACKUP_DATE=$TEMP_BACKUP_DATE
                        fi
 
                        continue
                fi
 
                # The following is executed for the backup file out of the storage period.
                # - $TEMP_BACKUP_DATE <= $DELETE_DATE
 
                # The backup file being searched is deleted because it is not necessary to restore the previously searched backup file.
                # - $TEMP_BACKUP_DATE != $NEED_PREV_BACKUP_DATE
                #
                # The previously searched backup file may or may not be within the storage period.
                # For example, a 0-level backup file is required to restore a 1-level incremental backup file, but the 1-level incremental backup file is out of the storage period.
                # - 2-level incremental backup file : Within the storage period. A 1-level incremental backup file is required for recovery.
                # - 1-level incremental backup file : Out of storage period. A 0-level full backup file is required for recovery.
                # - 0-level backup file : Out of storage period.
                if [ $TEMP_BACKUP_DATE -ne $NEED_PREV_BACKUP_DATE ]; then
                        rm -rf $BACKUP_DATE_ALL_LEVEL > /dev/null 2>> $BACKUP_ERROR_FILE

                        if [ $? -eq 0 ]; then
                                echo "[LOG] Delete old backup directory - $BACKUP_DATE_ALL_LEVEL : Ok" >> $BACKUP_LOG_FILE
                        else
                                echo "[LOG] Delete old backup directory - $BACKUP_DATE_ALL_LEVEL : Fail" >> $BACKUP_LOG_FILE
                        fi

                        # Delete empty backup database_name directory.
                        if [ `ls -Al $TEMP_BACKUP_DATE_DIR | wc -l` -eq 2 ]; then
                                rmdir $TEMP_BACKUP_DATE_DIR/"$DATABASE_NAME" > /dev/null 2>> $BACKUP_ERROR_FILE
                        fi

                        # Delete empty backup date directory.
                        if [ `ls -Al $TEMP_BACKUP_DATE_DIR | wc -l` -eq 1 ]; then
                                rmdir $TEMP_BACKUP_DATE_DIR > /dev/null 2>> $BACKUP_ERROR_FILE
                        fi

                        if [ $? -eq 0 ]; then
                                echo "[LOG] Delete old backup date directory - $TEMP_BACKUP_DATE_DIR : Ok" >> $BACKUP_LOG_FILE
                        else
                                echo "[LOG] Delete old backup date directory - $TEMP_BACKUP_DATE_DIR : Fail" >> $BACKUP_LOG_FILE
                        fi
 
                        continue
                fi
 
                # The backup file being searched is necessary to restore the previously searched backup file.
                # - $TEMP_BACKUP_DATE == $NEED_PREV_BACKUP_DATE
                if [ $TEMP_BACKUP_DATE -eq $NEED_PREV_BACKUP_DATE ]; then
                        echo "[LOG] $TEMP_BACKUP_DATE : Didn't delete. Needed for the next incremental backup recovery." >> $BACKUP_LOG_FILE
 
                        NEED_PREV_BACKUP_DATE=`cat "$TEMP_BACKUP_DATE_DATABASE_DIR"/"$DATABASE_NAME"_bkvinf | grep v000 | sort -r | head -2 | tail -1 | awk -F '/' '{print $(NF-3)}'`
                fi
 
                # After updating the backup date of the backup file needed to restore the backup file being searched.
 
                # The backup file being searched and the backup file required for recovery are the same.
                # This means that the backup file being searched is a 0-level full backup file.
                # The backup files older than the 0-level full backup file out of the storage period will be deleted in the next search.
                if [ $TEMP_BACKUP_DATE -eq $NEED_PREV_BACKUP_DATE ]; then
                        ALL_DELETE_YN="Y"
                fi
        done
}
 
# -------------------------------
#  MAIN function
# -------------------------------
if [ $# -lt 1 ]; then
        ft_show_help
        exit 0
fi
 
OPTIONS=`getopt -o vh --long version,help -n $0 -- "$@"`
eval set -- $OPTIONS
 
while true; do
        case $1 in
                -v|--version)
                        ft_show_version
                        exit 0
                        ;;
                -h|--help)
                        ft_show_help
                        exit 0
                        ;;
                -*)
                        shift
                        ;;
                --)
                        shift
                        break
                        ;;
                *)
                        break
                        ;;
        esac
done
 
case $1 in
        start)
                shift
 
                case $# in
                        1)
                                DATABASE_NAME=$1
                                BACKUP_LEVEL=0
                                BACKUP_PERIOD=0
                                ;;
                        2)
                                DATABASE_NAME=$1
                                BACKUP_LEVEL=$2
                                BACKUP_PERIOD=0
                                ;;
                        3)
                                DATABASE_NAME=$1
                                BACKUP_LEVEL=$2
                                BACKUP_PERIOD=$3
                                ;;
                        *)
                                ft_show_start_help
                                exit 0
                                ;;
                esac
 
                ft_set_environment_variable
 
                IS_EXIST=`cat $CUBRID_DATABASES/databases.txt | grep ^$DATABASE_NAME[[:space:]] | wc -l`
 
                # The database does not exist
                if [ ! $IS_EXIST -gt 0 ]; then
                        echo ""
                        echo "[ERROR] The database does not exist."
                        ft_show_start_help
                        exit 1
                fi
 
                # The backup level is not 0, 1, or 2.
                if ! { [ $BACKUP_LEVEL == 0 ] || [ $BACKUP_LEVEL == 1 ] || [ $BACKUP_LEVEL == 2 ]; }; then
                        echo ""
                        echo "[ERROR] The backup level is not 0, 1, or 2."
                        ft_show_start_help
                        exit 1
                fi
 
                # The storage period is not a number greater than or equal to zero.
                if ! [[ $BACKUP_PERIOD =~ ^[0-9]+$ ]] ; then
                        echo ""
                        echo "[ERROR] The storage period is not a number greater than or equal to zero."
                        ft_show_start_help
                        exit 1
                fi
 
                ft_init_info_variable
                ft_show_spacedb
                ft_create_dummy_tbl
                ft_backup_database
                ft_copy_conf_dir
                ft_copy_lob_dir
                ft_copy_java_dir
                ft_copy_archive_dir
 
                if [ $BACKUP_PERIOD -gt 0 ]; then
                        ft_delete_old_backup
                fi
 
                ;;
        *)
                ft_show_help
                exit 0
                ;;
esac
 
exit 0
# -------------------------------
# EOF
# -------------------------------

