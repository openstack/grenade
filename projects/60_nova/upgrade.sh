#!/usr/bin/env bash

# ``upgrade-nova``

echo "*********************************************************************"
echo "Begin $0"
echo "*********************************************************************"

# Clean up any resources that may be in use
cleanup() {
    set +o errexit

    echo "*********************************************************************"
    echo "ERROR: Abort $0"
    echo "*********************************************************************"

    # Kill ourselves to signal any calling process
    trap 2; kill -2 $$
}

trap cleanup SIGHUP SIGINT SIGTERM

# Keep track of the grenade directory
RUN_DIR=$(cd $(dirname "$0") && pwd)

# Import common functions
source $GRENADE_DIR/functions

# Determine what system we are running on.  This provides ``os_VENDOR``,
# ``os_RELEASE``, ``os_UPDATE``, ``os_PACKAGE``, ``os_CODENAME``
# and ``DISTRO``
GetDistro

# Source params
source $GRENADE_DIR/grenaderc

# This script exits on an error so that errors don't compound and you see
# only the first error that occurred.
set -o errexit

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace

# Set for DevStack compatibility
TOP_DIR=$TARGET_DEVSTACK_DIR


# Upgrade Nova
# ============

MYSQL_HOST=${MYSQL_HOST:-localhost}
MYSQL_USER=${MYSQL_USER:-root}
BASE_SQL_CONN=$(source $BASE_DEVSTACK_DIR/stackrc; echo ${BASE_SQL_CONN:-mysql://$MYSQL_USER:$MYSQL_PASSWORD@$MYSQL_HOST})

# Duplicate some setup bits from target DevStack
cd $TARGET_DEVSTACK_DIR
source $TARGET_DEVSTACK_DIR/functions
source $TARGET_DEVSTACK_DIR/stackrc
source $TARGET_DEVSTACK_DIR/lib/stack

# From stack.sh
FLOATING_RANGE=${FLOATING_RANGE:-172.24.4.224/28}
FIXED_RANGE=${FIXED_RANGE:-10.0.0.0/24}
HOST_IP=$(get_default_host_ip $FIXED_RANGE $FLOATING_RANGE "$HOST_IP_IFACE" "$HOST_IP")
if [ "$HOST_IP" == "" ]; then
    die $LINENO "Could not determine host ip address. Either localrc specified dhcp on ${HOST_IP_IFACE} or defaulted"
fi
SERVICE_HOST=${SERVICE_HOST:-$HOST_IP}

SERVICE_TENANT_NAME=${SERVICE_TENANT_NAME:-service}
S3_SERVICE_PORT=${S3_SERVICE_PORT:-8080}

# Just do this rather than bring in all of glance
GLANCE_HOSTPORT=$SERVICE_HOST:9292

SYSLOG=`trueorfalse False $SYSLOG`

# Get functions from current DevStack
source $TARGET_DEVSTACK_DIR/lib/database
source $TARGET_DEVSTACK_DIR/lib/rpc_backend
source $TARGET_DEVSTACK_DIR/lib/apache
source $TARGET_DEVSTACK_DIR/lib/tls
source $TARGET_DEVSTACK_DIR/lib/oslo
source $TARGET_DEVSTACK_DIR/lib/keystone
source $TARGET_DEVSTACK_DIR/lib/nova
source $TARGET_DEVSTACK_DIR/lib/neutron-legacy

NOVNC_DIR=$DEST/noVNC

# Save current config files for posterity
[[ -d $SAVE_DIR/etc.nova ]] || cp -pr $NOVA_CONF_DIR $SAVE_DIR/etc.nova

# install_nova()
stack_install_service nova

# calls upgrade-nova for specific release
upgrade_project nova $RUN_DIR $BASE_DEVSTACK_BRANCH $TARGET_DEVSTACK_BRANCH

# Simulate init_nova()
create_nova_cache_dir
create_nova_keys_dir

# Migrate the database
$NOVA_BIN_DIR/nova-manage --config-file $NOVA_CONF db sync || die $LINENO "DB sync error"

# rolling nova-compute support
if ! should_upgrade "n-cpu"; then
    iniset $NOVA_CONF upgrade_levels compute $(basename $BASE_DEVSTACK_BRANCH)
fi

# Start Nova
start_nova_api
if should_upgrade "n-cpu"; then
    start_nova_compute
fi
start_nova_rest

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End $0"
echo "*********************************************************************"
