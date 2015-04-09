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
source $BASE_DEVSTACK_DIR/lib/cinder

set -o xtrace

# BUG: do we really need this?
SCSI_PERSIST_DIR=$CINDER_STATE_PATH/volumes/*

stop_cinder

# sanity check that services are actually down
ensure_services_stopped cinder-api
