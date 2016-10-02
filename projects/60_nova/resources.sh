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

NOVA_USER=nova_grenade
NOVA_PROJECT=nova_grenade
NOVA_PASS=pass
NOVA_SERVER=nova_server1
DEFAULT_INSTANCE_TYPE=${DEFAULT_INSTANCE_TYPE:-m1.tiny}
DEFAULT_IMAGE_NAME=${DEFAULT_IMAGE_NAME:-cirros-0.3.2-x86_64-uec}

function _nova_set_user {
    OS_TENANT_NAME=$NOVA_PROJECT
    OS_PROJECT_NAME=$NOVA_PROJECT
    OS_USERNAME=$NOVA_USER
    OS_PASSWORD=$NOVA_PASS
}

function create {
    # creates a tenant for the server
    eval $(openstack project create -f shell -c id $NOVA_PROJECT)
    if [[ -z "$id" ]]; then
        die $LINENO "Didn't create $NOVA_PROJECT project"
    fi
    resource_save nova project_id $id

    # creates the user, and sets $id locally
    eval $(openstack user create $NOVA_USER \
        --project $id \
        --password $NOVA_PASS \
        -f shell -c id)
    if [[ -z "$id" ]]; then
        die $LINENO "Didn't create $NOVA_USER user"
    fi
    resource_save nova user_id $id

    # set ourselves to the created nova user
    _nova_set_user

    # setup a working security group
    # BUG(sdague): I have no idea how to make openstack security group work
    # openstack security group create --description "BUG" $NOVA_USER
    # openstack security group rule create --proto icmp --dst-port 0 $NOVA_USER
    # openstack security group rule create --proto tcp --dst-port 22 $NOVA_USER
    nova secgroup-create $NOVA_USER "BUG: this should not be mandatory"
    nova secgroup-add-rule $NOVA_USER icmp -1 -1 0.0.0.0/0
    nova secgroup-add-rule $NOVA_USER tcp 22 22 0.0.0.0/0

    # BUG(sdague): openstack client server create fails on volume
    # error by default.
    #
    # ERROR: openstack Invalid volume client version '2'. must be one of: 1
    export OS_VOLUME_API_VERSION=1

    # work around for neutron because there is no such thing as a default
    local net_id=$(resource_get network net_id)
    if [[ -n "$net_id" ]]; then
        local net="--nic net-id=$net_id"
    fi

    openstack server create --image $DEFAULT_IMAGE_NAME \
        --flavor $DEFAULT_INSTANCE_TYPE \
        --security-group $NOVA_USER \
        $net \
        $NOVA_SERVER --wait

    # Add a floating IP because this is something which will work in
    # either n-net or neutron. More advanced server creates with
    # neutron should be done in neutron test.
    eval $(openstack floating ip create public -f shell -c id -c ip -c floating_ip_address)
    # NOTE(dhellmann): Around version 3.0.0 of python-openstackclient
    # the column name changed from "ip" to "floating_ip_address". We
    # look for both here to support upgrades.
    if [[ -z "$ip" ]]; then
        ip="$floating_ip_address"
    fi
    resource_save nova nova_server_ip $ip
    resource_save nova nova_server_float $id
    openstack server add floating ip $NOVA_SERVER $ip


    uuid=$(openstack server show $NOVA_SERVER -f value -c id)
    resource_save nova nova_server_uuid $uuid

    # ping check on the way up to ensure we're really running
    ping_check_public $ip 30

    # NOTE(sdague): for debugging when things go wrong, so we have a
    # before and an after
    worlddump nova_resources_created
}

function verify {
    local side="$1"
    # we aren't doing any API verification here, so just call
    # verify_noapi for now. Additional API verification can be added
    # later.
    verify_noapi

    if [[ "$side" = "post-upgrade" ]]; then
        # We can only verify the cells v2 setup if we created the mappings by
        # calling simple_cell_setup.
        if [ "$NOVA_CONFIGURE_CELLSV2" == "True" ]; then
            uuid=$(resource_get nova nova_server_uuid)
            nova-manage cell_v2 verify_instance --uuid $uuid
        fi
    fi
}

function verify_noapi {
    local server_ip=$(resource_get nova nova_server_ip)
    ping_check_public $server_ip 30
}

function destroy {
    _nova_set_user
    openstack server remove floating ip $NOVA_SERVER $(resource_get nova nova_server_ip)
    openstack floating ip delete $(resource_get nova nova_server_float)
    openstack server delete $NOVA_SERVER
    # wait for server to be down before we delete the security group
    # TODO(mriedem): Use the --wait option with the openstack server delete
    # command when python-openstackclient>=1.4.0 is in global-requirements.
    local wait_cmd="while openstack server show $NOVA_SERVER >/dev/null; do sleep 1; done"
    timeout 30 sh -c "$wait_cmd"

    nova secgroup-delete $NOVA_USER || /bin/true

    # lastly, get rid of our user - done as admin
    source_quiet $TOP_DIR/openrc admin admin
    local user_id=$(resource_get nova user_id)
    local project_id=$(resource_get nova project_id)
    openstack user delete $user_id
    openstack project delete $project_id
}

# Dispatcher
case $1 in
    "create")
        create
        ;;
    "verify_noapi")
        verify_noapi $2
        ;;
    "verify")
        verify $2
        ;;
    "destroy")
        destroy
        ;;
    "force_destroy")
        set +o errexit
        destroy
        ;;
esac
