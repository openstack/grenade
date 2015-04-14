#!/bin/bash
#
# Copyright 2015 Hewlett-Packard Development Company, L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

set -o errexit

source $GRENADE_DIR/grenaderc
source $GRENADE_DIR/functions

source $TOP_DIR/openrc admin admin

set -o xtrace

CONTAINER=cont_grenade

function create {
    # TODO: this should really create a limited user for these
    # actions, but all the example scripts assume admin, so we'll just
    # do that here.

    # We start by creating a test container
    openstack container create $CONTAINER

    # add some files into it.
    openstack object create $CONTAINER /etc/issue
}

function verify {
    openstack object list $CONTAINER
}

# there is nothing to verify for swift when the API is down
function verify_noapi {
    :
}

function destroy {
    openstack object delete $CONTAINER /etc/issue
    openstack container delete $CONTAINER
}

# Dispatcher
case $1 in
    "create")
        create
        ;;
    "verify_noapi")
        verify_noapi
        ;;
    "verify")
        verify
        ;;
    "destroy")
        destroy
        ;;
esac
