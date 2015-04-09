#!/bin/bash
#
#

set -o errexit

source $GRENADE_DIR/grenaderc
source $GRENADE_DIR/functions

# We need base DevStack functions for this
source $BASE_DEVSTACK_DIR/functions
source $BASE_DEVSTACK_DIR/stackrc # needed for status directory
source $BASE_DEVSTACK_DIR/lib/tls
source $BASE_DEVSTACK_DIR/lib/swift

set -o xtrace

# BUG: we shouldn't have to mask out the exit here
stop_swift || /bin/true

# Unplumb the Swift data
sudo umount ${DATA_DIR}/swift/drives/images/swift.img || /bin/true

# sanity check that services are actually down
ensure_services_stopped swift-object-server swift-proxy-server
