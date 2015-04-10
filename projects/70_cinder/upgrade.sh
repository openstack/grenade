#!/usr/bin/env bash

# ``upgrade-cinder``

# ``upgrade-nova`` must be complete for this to work!!!

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


# Upgrade Cinder
# ==============

MYSQL_HOST=${MYSQL_HOST:-localhost}
MYSQL_USER=${MYSQL_USER:-root}
BASE_SQL_CONN=$(source $BASE_DEVSTACK_DIR/stackrc; echo ${BASE_SQL_CONN:-mysql://$MYSQL_USER:$MYSQL_PASSWORD@$MYSQL_HOST})

# Duplicate some setup bits from target DevStack
cd $TARGET_DEVSTACK_DIR
source $TARGET_DEVSTACK_DIR/functions
source $TARGET_DEVSTACK_DIR/stackrc
source $TARGET_DEVSTACK_DIR/lib/stack

SERVICE_HOST=${SERVICE_HOST:-localhost}
SERVICE_PROTOCOL=${SERVICE_PROTOCOL:-http}
SERVICE_TENANT_NAME=${SERVICE_TENANT_NAME:-service}
source $TARGET_DEVSTACK_DIR/lib/database
source $TARGET_DEVSTACK_DIR/lib/rpc_backend
source $TARGET_DEVSTACK_DIR/lib/apache
source $TARGET_DEVSTACK_DIR/lib/tls
source $TARGET_DEVSTACK_DIR/lib/oslo
source $TARGET_DEVSTACK_DIR/lib/keystone

# Get functions from current DevStack
source $TARGET_DEVSTACK_DIR/lib/cinder

# Save current config files for posterity
[[ -d $SAVE_DIR/etc.cinder ]] || cp -pr $CINDER_CONF_DIR $SAVE_DIR/etc.cinder

# install_cinder()
stack_install_service cinder

# calls upgrade-cinder for specific release
upgrade_project cinder $RUN_DIR $BASE_DEVSTACK_BRANCH $TARGET_DEVSTACK_BRANCH

# Simulate init_cinder()
create_cinder_volume_group
create_cinder_cache_dir

# Migrate the database
$CINDER_BIN_DIR/cinder-manage db sync || die $LINENO "DB migration error"

start_cinder

# Don't succeed unless the services come up
ensure_services_started cinder-api
ensure_logs_exist c-api c-vol

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End $0"
echo "*********************************************************************"
