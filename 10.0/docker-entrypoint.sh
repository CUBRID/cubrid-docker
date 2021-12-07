#!/bin/bash
set -e

init_db () {
	if [ -f "$CUBRID_DATABASES/databases.txt" ]; then
		if grep -qwe "^$CUBRID_DB" "$CUBRID_DATABASES/databases.txt"; then
			echo "Database '$CUBRID_DB' is initialized already"
			return
		fi
	else
		touch "$CUBRID_DATABASES/databases.txt"
	fi
	chown -R cubrid:cubrid "$CUBRID_DATABASES"

	echo "Initializing database '$CUBRID_DB'"

	if [ ! -d "$CUBRID_DATABASES/$CUBRID_DB" ]; then
		gosu cubrid mkdir -p "$CUBRID_DATABASES/$CUBRID_DB"
	fi

	
	if [ "$CUBRID_DB_HOST" ]; then
		CUBRID_SERVER_NAME=$CUBRID_DB_HOST
	else
		CUBRID_SERVER_NAME=$HOSTNAME
	fi

	cd "$CUBRID_DATABASES/$CUBRID_DB" \
		&& gosu cubrid cubrid createdb --db-volume-size=$CUBRID_VOLUME_SIZE --server-name=$CUBRID_SERVER_NAME $CUBRID_DB $CUBRID_LOCALE

	if [ "$CUBRID_USER" -a "$CUBRID_USER" != "dba" -a "$CUBRID_USER" != "public" ]; then
		csql -u dba -S $CUBRID_DB -c "CREATE USER $CUBRID_USER PASSWORD '$CUBRID_PASSWORD';"
	fi
}

init_ha () {
	# turn on HA mode
	if grep -we 'ha_mode[ ]*=[ ]*on' ; then
		echo "HA mode is on already"
	else
		echo "ha_mode=on" >> $CUBRID/conf/cubrid.conf
	fi
	# config for HA
	echo "[common]" >> $CUBRID/conf/cubrid_ha.conf
	echo "ha_port_id=59901" >> $CUBRID/conf/cubrid_ha.conf
	echo "ha_node_list=cubrid@$CUBRID_DB_HOST" >> $CUBRID/conf/cubrid_ha.conf
	echo "ha_db_list=$CUBRID_DB" >> $CUBRID/conf/cubrid_ha.conf
	echo "ha_copy_sync_mode=sync:sync" >> $CUBRID/conf/cubrid_ha.conf
	echo "ha_apply_max_mem_size=300" >> $CUBRID/conf/cubrid_ha.conf
	echo "ha_copy_log_max_archives=1" >> $CUBRID/conf/cubrid_ha.conf
}

echo "export CUBRID=/home/cubrid/CUBRID" >> /home/cubrid/.bash_profile
echo "export CUBRID_DATABASES=/var/lib/cubrid" >> /home/cubrid/.bash_profile
echo "export PATH=$CUBRID/bin:$PATH" >> /home/cubrid/.bash_profile
echo "export LD_LIBRARY_PATH=$CUBRID/lib" >> /home/cubrid/.bash_profile
echo "export SHLIB_PATH=$LD_LIBRARY_PATH" >> /home/cubrid/.bash_profile
echo "export LIBPATH=$LD_LIBRARY_PATH" >> /home/cubrid/.bash_profile

if [ $# -eq 0 ]; then
	case "$CUBRID_COMPONENTS" in
		BROKER)
			gosu cubrid cubrid broker start
			if [ "$CUBRID_DB_HOST" ]; then
				if [ -f "$CUBRID_DATABASES/databases.txt" ]; then
					if grep -qwe "^$CUBRID_DB" "$CUBRID_DATABASES/databases.txt"; then
						echo "Database '$CUBRID_DB' exists already"
					fi
				else
					echo "$CUBRID_DB / $CUBRID_DB_HOST / file:/" > $CUBRID_DATABASES/databases.txt
				fi
			fi
			;;
		SERVER)
			init_db && gosu cubrid cubrid server start $CUBRID_DB
			;;
		MASTER|SLAVE)
			init_db && init_ha && gosu cubrid cubrid heartbeat start
			;;
		HA)
			init_db && init_ha && gosu cubrid cubrid broker start && gosu cubrid cubrid heartbeat start
			;;
		ALL)
			init_db && gosu cubrid cubrid broker start && gosu cubrid cubrid server start $CUBRID_DB
			;;
		*)
			echo "Unknown CUBRID_COMPONENTS '$CUBRID_COMPONENTS'" && false
			;;
	esac

	gosu cubrid cubrid_rel

	gosu cubrid /usr/bin/tail -F /dev/null
else
	echo "$@"
fi

chown -R cubrid:cubrid $CUBRID $CUBRID_DATABASES
