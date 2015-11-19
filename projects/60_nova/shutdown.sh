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
source $BASE_DEVSTACK_DIR/lib/apache
source $BASE_DEVSTACK_DIR/lib/nova

set -o xtrace

stop_nova

# TODO(sdague): list all the services
SERVICES_DOWN="nova-api nova-conductor nova-scheduler nova-compute"

# sanity check that services are actually down
ensure_services_stopped $SERVICES_DOWN
