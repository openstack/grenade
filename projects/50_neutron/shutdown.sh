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
source $BASE_DEVSTACK_DIR/lib/neutron-legacy

set -o xtrace

# BUG: neutron stop scripts don't exit cleanly, this needs to be fixed
stop_neutron || /bin/true
stop_neutron_third_party || /bin/true
