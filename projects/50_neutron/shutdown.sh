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
# TODO(sdague): remove this conditional once we've branched
# grenade. Right now we need to support stable/mitaka, stable/newton,
# and master devstack
if [[ -e $BASE_DEVSTACK_DIR/lib/neutron ]]; then
    source $BASE_DEVSTACK_DIR/lib/neutron
fi
source $BASE_DEVSTACK_DIR/lib/neutron-legacy

set -o xtrace

stop_neutron
