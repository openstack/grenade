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

# Source params
source $GRENADE_DIR/grenaderc
source $GRENADE_DIR/functions

# This script exits on an error so that errors don't compound and you see
# only the first error that occurred.
set -o errexit

# Upgrade Cinder
# ==============

source $TARGET_DEVSTACK_DIR/stackrc
source $TARGET_DEVSTACK_DIR/lib/tls
source $TARGET_DEVSTACK_DIR/lib/cinder

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace

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
ensure_logs_exist c-api
if is_service_enabled c-vol; then
    ensure_services_started cinder-volume
    ensure_logs_exist c-vol
fi

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End $0"
echo "*********************************************************************"
