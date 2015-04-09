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
source $BASE_DEVSTACK_DIR/lib/nova

set -o xtrace

stop_nova_rest

# TODO(sdague): list all the services
SERVICES_DOWN="nova-api nova-conductor nova-scheduler"

if should_upgrade "n-cpu"; then
    # IF n-cpu is on do not upgrade list, then do no stop it
    stop_nova_compute
    SERVICES_DOWN+=" nova-compute"
fi

# sanity check that services are actually down
ensure_services_stopped $SERVICES_DOWN
