#!/usr/bin/env bash

# ``upgrade-ceilometer``

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


# Upgrade Ceilometer
# ==================

# Get functions from current DevStack
source $TARGET_DEVSTACK_DIR/stackrc
source $BASE_DEVSTACK_DIR/lib/apache
source $TARGET_DEVSTACK_DIR/lib/ceilometer

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace

# install_ceilometer()
stack_install_service ceilometer

# calls upgrade-ceilometer for specific release
upgrade_project ceilometer $RUN_DIR $BASE_DEVSTACK_BRANCH $TARGET_DEVSTACK_BRANCH

# Migrate the database
$CEILOMETER_BIN_DIR/ceilometer-dbsync || die $LINENO "DB sync error"

# Start Ceilometer
start_ceilometer

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End $0"
echo "*********************************************************************"
