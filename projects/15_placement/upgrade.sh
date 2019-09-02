#!/usr/bin/env bash

# ``upgrade-placement``

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
source $TARGET_DEVSTACK_DIR/lib/placement

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following along as the install occurs.
set -o xtrace

# Temporary setting until venv change is in DevStack
if [[ -z $PLACEMENT_BIN_DIR ]]; then
    PLACEMENT_BIN_DIR=$(dirname $(which placement-manage))
fi

# Save current config files for posterity
[[ -d $SAVE_DIR/etc.placement ]] || cp -pr $PLACEMENT_CONF_DIR $SAVE_DIR/etc.placement

# install_placement()
stack_install_service placement

# calls upgrade-placement for specific release
upgrade_project placement $RUN_DIR $BASE_DEVSTACK_BRANCH

# Simulate init_placement()
# Migrate the database
$PLACEMENT_BIN_DIR/placement-manage db sync || die $LINENO "DB sync error"

# Start Placement:
start_placement

# ensure the service has started
ensure_services_started placement

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End $0"
echo "*********************************************************************"
