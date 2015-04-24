#!/usr/bin/env bash

# ``upgrade-keystone``

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

# Source params
source $GRENADE_DIR/grenaderc

# Import common functions
source $GRENADE_DIR/functions

# This script exits on an error so that errors don't compound and you see
# only the first error that occurred.
set -o errexit

source $TARGET_DEVSTACK_DIR/stackrc
source $TARGET_DEVSTACK_DIR/lib/apache
source $TARGET_DEVSTACK_DIR/lib/tls
source $TARGET_DEVSTACK_DIR/lib/keystone

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace

# Temporary setting until venv change is in DevStack
if [[ -z $KEYSTONE_BIN_DIR ]]; then
    KEYSTONE_BIN_DIR=$(dirname $(which keystone-manage))
fi

# Save current config files for posterity
[[ -d $SAVE_DIR/etc.keystone ]] || cp -pr $KEYSTONE_CONF_DIR $SAVE_DIR/etc.keystone

# install_keystone()
stack_install_service keystone

# calls upgrade-keystone for specific release
upgrade_project keystone $RUN_DIR $BASE_DEVSTACK_BRANCH

# Simulate init_keystone()
# Migrate the database
$KEYSTONE_BIN_DIR/keystone-manage db_sync || die $LINENO "DB sync error"

# Start Keystone
start_keystone

# ensure the service has started
ensure_services_started keystone

# TODO(sdague): we should probably check that apache looks like it's
# logging, but this will let us pass for now.
if [[ "$KEYSTONE_USE_MOD_WSGI" != "True" ]]; then
    ensure_logs_exist key
fi

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End $0"
echo "*********************************************************************"
