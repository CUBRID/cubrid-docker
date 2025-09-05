#!/bin/bash

if [ -z "$CUBRID" ]; then
    CONF_DIR="/home/cubrid/CUBRID/conf"
else
    CONF_DIR="${CUBRID}/conf"
fi

CUBRID_CONF="${CONF_DIR}/cubrid.conf"
CUBRID_HA_CONF="${CONF_DIR}/cubrid_ha.conf"

# Function to add HA mode
add_ha_mode() {
    local VALUE=$1
    if grep -q '^[#[:space:]]*ha_mode[[:space:]]*=' "$CUBRID_CONF"; then
        sed -i "s/^[#[:space:]]*ha_mode[[:space:]]*=.*/ha_mode=$VALUE/" "$CUBRID_CONF"
    elif grep -q '^ha_mode[[:space:]]*=' "$CUBRID_CONF"; then
        sed -i "s/^ha_mode[[:space:]]*=.*/ha_mode=$VALUE/" "$CUBRID_CONF"
    else
        echo -e "ha_mode=$VALUE" >> "$CUBRID_CONF"
    fi
}

# Function to set the maximum number of log archives
set_log_max_archives() {
    local VALUE=$1
    if grep -q '^[^#]*log_max_archives' "$CUBRID_CONF"; then
        sed -i "s/^[^#]*log_max_archives=[^#]*/log_max_archives=$VALUE/" "$CUBRID_CONF"
    else
        echo "log_max_archives=$VALUE" >> "$CUBRID_CONF"
    fi
}

set_force_remove_log_archives() {
    local VALUE=$1
    if grep -q '^[#[:space:]]*force_remove_log_archives[[:space:]]*=' "$CUBRID_CONF"; then
        sed -i "s/^[#[:space:]]*force_remove_log_archives[[:space:]]*=.*/force_remove_log_archives=$VALUE/" "$CUBRID_CONF"
    elif grep -q '^force_remove_log_archives[[:space:]]*=' "$CUBRID_CONF"; then
        sed -i "s/^force_remove_log_archives[[:space:]]*=.*/force_remove_log_archives=$VALUE/" "$CUBRID_CONF"
    else
        echo -e "force_remove_log_archives=$VALUE" >> "$CUBRID_CONF"
    fi
}

# Function to add common configuration to cubrid_ha.conf
add_common_config() {
    local DEFAULT_PORT="59901"
    local DEFAULT_DB="demodb"
    local DEFAULT_MEM_SIZE="300"
    local DEFAULT_LOG_ARCHIVES="1"

    # edit [common]
    if grep -q '^[#[:space:]]*\[\s*common\s*\]' "$CUBRID_HA_CONF"; then
        sed -i 's/^[#[:space:]]*\[\s*common\s*\]/[common]/' "$CUBRID_HA_CONF"
    elif ! grep -q '^\[common\]' "$CUBRID_HA_CONF"; then
        echo -e "[common]" >> "$CUBRID_HA_CONF"
    else
        echo "none"
    fi

    # eidt ha_port_id
    if grep -q '^[#[:space:]]*ha_port_id[[:space:]]*=[[:space:]]*[0-9]\+' "$CUBRID_HA_CONF"; then
        sed -i 's/^[#[:space:]]*\(ha_port_id[[:space:]]*=[[:space:]]*[0-9]\+\)/\1/' "$CUBRID_HA_CONF"
    elif ! grep -q '^ha_port_id[[:space:]]*=[[:space:]]*[0-9]\+' "$CUBRID_HA_CONF"; then
        echo -e "ha_port_id=$DEFAULT_PORT" >> "$CUBRID_HA_CONF"
    else
        echo "none"
    fi

    # edit ha_db_list
    if grep -q '^[#[:space:]]*ha_db_list[[:space:]]*=[[:space:]]*[a-zA-Z_]\+' "$CUBRID_HA_CONF"; then
        sed -i 's/^[#[:space:]]*\(ha_db_list[[:space:]]*=[[:space:]]*[a-zA-Z_]\+\)/\1/' "$CUBRID_HA_CONF"
    elif ! grep -q '^ha_db_list[[:space:]]*=[[:space:]]*[a-zA-Z_]\+' "$CUBRID_HA_CONF"; then
        echo -e "ha_db_list=$DEFAULT_DB" >> "$CUBRID_HA_CONF"
    else
        echo "none"
    fi

    # edit ha_apply_max_size
    if grep -q '^[#[:space:]]*ha_apply_max_mem_size[[:space:]]*=[[:space:]]*[0-9]\+' "$CUBRID_HA_CONF"; then
        sed -i 's/^[#[:space:]]*\(ha_apply_max_mem_size[[:space:]]*=[[:space:]]*[0-9]\+\)/\1/' "$CUBRID_HA_CONF"
    elif ! grep -q '^ha_apply_max_mem_size[[:space:]]*=[[:space:]]*[0-9]\+' "$CUBRID_HA_CONF"; then
        echo -e "ha_apply_max_mem_size=$DEFAULT_MEM_SIZE" >> "$CUBRID_HA_CONF"
    else
        echo "none"
    fi

    # edit ha_copy_log_max_archives
    if grep -q '^[#[:space:]]*ha_copy_log_max_archives[[:space:]]*=[[:space:]]*[0-9]\+' "$CUBRID_HA_CONF"; then
        sed -i 's/^[#[:space:]]*\(ha_copy_log_max_archives[[:space:]]*=[[:space:]]*[0-9]\+\)/\1/' "$CUBRID_HA_CONF"
    elif ! grep -q '^ha_copy_log_max_archives[[:space:]]*=[[:space:]]*[0-9]\+' "$CUBRID_HA_CONF"; then
        echo -e "ha_copy_log_max_archives=$DEFAULT_LOG_ARCHIVES" >> "$CUBRID_HA_CONF"
    else
        echo "none"
    fi
}

# Function to set the HA node list
set_ha_node_list() {
    local NODE_LIST="$1"

    if grep -q '^[#[:space:]]*ha_node_list[[:space:]]*=' "$CUBRID_HA_CONF"; then
        sed -i "s/^[#[:space:]]*ha_node_list[[:space:]]*=.*/ha_node_list=$NODE_LIST/" "$CUBRID_HA_CONF"
    elif grep -q '^ha_node_list[[:space:]]*=' "$CUBRID_HA_CONF"; then
        sed -i "s/^[[:space:]]*ha_node_list[[:space:]]*=.*/ha_node_list=$NODE_LIST/" "$CUBRID_HA_CONF"
    else
        echo -e "ha_node_list=$NODE_LIST" >> "$CUBRID_HA_CONF"
    fi
}

# Function to set ha_copy_sync_mode in cubrid_ha.conf
set_ha_copy_sync_mode() {
    local MODE=$1

    if grep -q '^[#[:space:]]*ha_copy_sync_mode[[:space:]]*=' "$CUBRID_HA_CONF"; then
        sed -i "s/^[#[:space:]]*ha_copy_sync_mode[[:space:]]*=.*/ha_copy_sync_mode=$MODE/" "$CUBRID_HA_CONF"
    elif grep -q '^ha_copy_sync_mode[[:space:]]*=' "$CUBRID_HA_CONF"; then
        sed -i "s/^[[:space:]]*ha_copy_sync_mode[[:space:]]*=.*/ha_copy_sync_mode=$MODE/" "$CUBRID_HA_CONF"
    else
        echo -e "ha_copy_sync_mode=$MODE" >> "$CUBRID_HA_CONF"
    fi
}

# Function to set the HA replica list
set_ha_replica_list() {
    local REPLICA_LIST="$1"
    if grep -q '^[#[:space:]]*ha_replica_list[[:space:]]*=' "$CUBRID_HA_CONF"; then
        sed -i "s/^[#[:space:]]*ha_replica_list[[:space:]]*=.*/ha_replica_list=${REPLICA_LIST}/" "$CUBRID_HA_CONF"
    else
        echo "ha_replica_list=${REPLICA_LIST}" >> "$CUBRID_HA_CONF"
    fi
}


# Function to delete a replica from the HA replica list
del_ha_replica_list() {
    sed -i '/^[#[:space:]]*ha_replica_list[[:space:]]*=.*/d' "$CUBRID_HA_CONF"
}

# Function Execution Mapping
case "$1" in
    ha_mode)
        add_ha_mode "on"
        ;;
    ha_replica_mode)
        add_ha_mode "replica"
        ;;
    ha_log_max_archives)
        set_log_max_archives "5"
        ;;
    ha_force_remove_log_archives)
        set_force_remove_log_archives "no"
        ;;
    ha_common_config)
        add_common_config
        ;;
    ha_node_list)
        set_ha_node_list "$2"
        ;;
    ha_copy_sync_mode)
        set_ha_copy_sync_mode "$2"
        ;;
    ha_replica_list)
        set_ha_replica_list "$2"
        ;;
    ha_del_replica_list)
        del_ha_replica_list
        ;;
    test)
        update_cubrid_conf $2 $3
        ;;
    *)
        echo "Usage: $0 {ha_mode|ha_replica_mode|ha_log_max_archives|ha_force_remove_log_archives|ha_common_config|ha_node_list <value>|ha_copy_sync_mode <value>|ha_replica_list <value>|ha_del_replica_list}"
        exit 1
        ;;
esac

