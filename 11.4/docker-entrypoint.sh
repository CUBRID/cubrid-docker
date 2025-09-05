#!/bin/bash
set -e

# =============================================================================
# Environment Detection Functions
# =============================================================================

# Function to check if running in Kubernetes environment
is_kubernetes_environment() {
    if [ -n "$KUBERNETES_SERVICE_HOST" ] || \
       [ -n "$POD_NAME" ] || \
       [ -d "/var/run/secrets/kubernetes.io" ] || \
       ( [ -f "/proc/1/cgroup" ] && grep -q "kubepods" /proc/1/cgroup ); then
        return 0  # true - Kubernetes environment
    else
        return 1  # false - Non-Kubernetes environment
    fi
}

# =============================================================================
# Common Utility Functions
# =============================================================================

# Function to set ulimit with error handling
set_ulimit() {
    local limit_type=$1
    local value=$2
    
    if ulimit -$limit_type $value 2>/dev/null; then
        echo "Successfully set ulimit -$limit_type to $value"
    else
        echo "Warning: Failed to set ulimit -$limit_type to $value (may require --ulimit option)"
    fi
}

# =============================================================================
# Kubernetes Environment Functions 
# =============================================================================

# Setup Kubernetes environment
setup_kubernetes_environment() {
    echo "=========================================="
    echo "Setting up Kubernetes Environment"
    echo "=========================================="
    
    # Set ulimit for CUBRID user
    echo "Setting ulimit values..."
    set_ulimit "c" "unlimited"  # core dump size
    set_ulimit "n" "65536"      # open files
    set_ulimit "u" "65536"      # max user processes
    set_ulimit "s" "32768"      # stack size

    # Display current ulimit values
    echo "Current ulimit values:"
    ulimit -a

    # CMS Account for Operator 
    echo "Creating CMS account for operator..."
    cm_admin adduser cm_info cm_inf0pw

    cubrid_rel
    /usr/bin/tail -F /dev/null

    echo "Kubernetes environment setup completed"
    echo "=========================================="
}

# =============================================================================
# Standard Docker Environment Functions
# =============================================================================

# Initialize database
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

# Initialize HA configuration
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

# Setup standard Docker environment
setup_standard_environment() {
    echo "=========================================="
    echo "Setting up Standard Docker Environment"
    echo "=========================================="
    
    # Set ulimit for CUBRID user
    echo "Setting ulimit values..."
    set_ulimit "c" "unlimited"  # core dump size
    set_ulimit "n" "65536"      # open files
    set_ulimit "u" "65536"      # max user processes
    set_ulimit "s" "32768"      # stack size

    # Display current ulimit values
    echo "Current ulimit values:"
    ulimit -a

    if [ $# -eq 0 ]; then
        case "$CUBRID_COMPONENTS" in
            BROKER)
                echo "Starting CUBRID Broker..."
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
                echo "Starting CUBRID Server..."
                init_db && gosu cubrid cubrid server start $CUBRID_DB
                ;;
            MASTER|SLAVE)
                echo "Starting CUBRID HA (Master/Slave)..."
                init_db && init_ha && gosu cubrid cubrid heartbeat start
                ;;
            HA)
                echo "Starting CUBRID HA..."
                init_db && init_ha && gosu cubrid cubrid broker start && gosu cubrid cubrid heartbeat start
                ;;
            ALL)
                echo "Starting CUBRID All Services..."
                init_db && gosu cubrid cubrid broker start && gosu cubrid cubrid server start $CUBRID_DB
                ;;
            *)
                echo "Unknown CUBRID_COMPONENTS '$CUBRID_COMPONENTS'" && false
                ;;
        esac

        gosu cubrid cubrid_rel
        gosu cubrid /usr/bin/tail -F /dev/null
    else
        exec "$@"
    fi
    
    echo "Standard Docker environment setup completed"
    echo "=========================================="
}

# =============================================================================
# Main Entry Point
# =============================================================================

echo "=========================================="
echo "CUBRID Docker Entrypoint Starting..."
echo "=========================================="

# Detect environment and execute appropriate setup
if is_kubernetes_environment; then
    echo "Kubernetes environment detected!"
    setup_kubernetes_environment
else
    echo "Standard Docker environment detected!"
    setup_standard_environment "$@"
fi