#!/usr/bin/env bash

# ``upgrade-swift``

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

# Upgrade Swift
# =============
source $TARGET_DEVSTACK_DIR/stackrc

FILES=$TARGET_DEVSTACK_DIR/files
source $TARGET_DEVSTACK_DIR/lib/apache
source $TARGET_DEVSTACK_DIR/lib/tls
source $TARGET_DEVSTACK_DIR/lib/keystone
source $TARGET_DEVSTACK_DIR/lib/swift

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace

# Save current config files for posterity
[[ -d $SAVE_DIR/etc.swift ]] || cp -pr $SWIFT_CONF_DIR $SAVE_DIR/etc.swift
cp -pr /etc/rsyncd.conf $SAVE_DIR

# install_swift()
stack_install_service swift

# calls upgrade-swift for specific release
upgrade_project swift $RUN_DIR $BASE_DEVSTACK_BRANCH $TARGET_DEVSTACK_BRANCH

# Simulate swift_init()

# Create cache dir
USER_GROUP=$(id -g)
sudo mkdir -p ${SWIFT_DATA_DIR}/{drives,cache,run,logs}
sudo chown -R $USER:${USER_GROUP} ${SWIFT_DATA_DIR}

# Mount backing disk
if ! egrep -q ${SWIFT_DATA_DIR}/drives/sdb1 /proc/mounts; then
    sudo mount -t xfs -o nouuid,loop,noatime,nodiratime,logbufs=8  \
        ${SWIFT_DATA_DIR}/drives/images/swift.img ${SWIFT_DATA_DIR}/drives/sdb1
fi

# Start Swift
start_swift

# Don't succeed unless the services come up
ensure_services_started s-object s-proxy

# If we're in python3 for the overall grenade, swift itself is still
# using python2 and installed the openstackclient, clobbering the
# python3 version. We need to put it back before moving on. Because
# openstackclient is explicitly listed as python3 supported, this
# does "the right thing".
# TODO(cdent): Remove this when swift is part of ENABLED_PYTHON3_PACKAGES.
pip_install python-openstackclient

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End $0"
echo "*********************************************************************"
