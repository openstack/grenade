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

KEYSTONE_TEST_USER=keystone_check
KEYSTONE_TEST_GROUP=keystone_check
KEYSTONE_TEST_PASS=pass

function create {
    # creates the project, and sets $id locally
    eval $(openstack project create -f shell -c id $KEYSTONE_TEST_GROUP)
    resource_save keystone project_id $id

    # creates the user, and sets $id locally
    eval $(openstack user create $KEYSTONE_TEST_USER \
        --project $id \
        --password $KEYSTONE_TEST_PASS \
        -f shell -c id)
    resource_save keystone user_id $id
}

function verify {
    local user_id=$(resource_get keystone user_id)
    openstack user show $user_id
}

function verify_noapi {
    # currently no good way
    :
}

function destroy {
    local user_id=$(resource_get keystone user_id)
    local project_id=$(resource_get keystone project_id)
    openstack user delete $user_id
    openstack project delete $project_id
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
