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
VIRT_DRIVER=${VIRT_DRIVER:-$DEFAULT_VIRT_DRIVER}

if [[ "$VIRT_DRIVER" == ironic ]]; then
    NOVA_IRONIC_RESOURCE_CLASS=${IRONIC_DEFAULT_RESOURCE_CLASS:-baremetal}
    # Ironic does not use standard resource classes starting with Stein,
    # verify its custom resource class instead.
    NOVA_VERIFY_RESOURCE_CLASSES=CUSTOM_${NOVA_IRONIC_RESOURCE_CLASS^^}
else
    NOVA_VERIFY_RESOURCE_CLASSES="VCPU MEMORY_MB DISK_GB"
fi

function _nova_set_user {
    OS_TENANT_NAME=$NOVA_PROJECT
    OS_PROJECT_NAME=$NOVA_PROJECT
    OS_USERNAME=$NOVA_USER
    OS_PASSWORD=$NOVA_PASS
}

function _get_inventory_value() {
    local key
    local provider

    key="$1"

    # Get the uuid of the first resource provider
    provider=$(openstack resource provider list -f value | head -n1 | cut -d ' ' -f 1)

    # Return the inventory total for $uuid and resource class $key
    openstack resource provider inventory show $provider $key -f value -c total
}

function _get_allocation_value() {
    local consumer
    local key

    consumer="$1"
    key="$2"

    # Return the allocated amount for $consumer and resource class $key;
    # we can't use -c $key here because the resource class amounts are
    # dumped in a json blob.
    openstack resource provider allocation show -f value $consumer | grep -o ".${key}.: [0-9]*" | cut -d ' ' -f 2
}

function create {
    # creates a tenant for the server
    eval $(openstack project create -f shell -c id $NOVA_PROJECT)
    if [[ -z "$id" ]]; then
        die $LINENO "Didn't create $NOVA_PROJECT project"
    fi
    resource_save nova project_id $id
    local project_id=$id

    # creates the user, and sets $id locally
    eval $(openstack user create $NOVA_USER \
        --project $project_id \
        --password $NOVA_PASS \
        -f shell -c id)
    if [[ -z "$id" ]]; then
        die $LINENO "Didn't create $NOVA_USER user"
    fi
    resource_save nova user_id $id

    openstack role add member --user $id --project $project_id

    # set ourselves to the created nova user
    _nova_set_user

    # setup a working security group
    # BUG(sdague): I have no idea how to make openstack security group work
    openstack security group create --description " BUG: this should not be mandatory" $NOVA_USER
    openstack security group rule create --proto icmp --dst-port 0 $NOVA_USER
    openstack security group rule create --proto tcp --dst-port 22 $NOVA_USER

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

    # Save some inventory and allocation values (requires admin)
    source_quiet $TOP_DIR/openrc admin admin
    local key
    for key in $NOVA_VERIFY_RESOURCE_CLASSES; do
        resource_save nova nova_inventory_$key $(_get_inventory_value $key)
    done
    for key in $NOVA_VERIFY_RESOURCE_CLASSES; do
        resource_save nova nova_server_allocation_$key $(_get_allocation_value $uuid $key)
    done

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

    local key
    local uuid
    local sval
    local cval
    uuid=$(resource_get nova nova_server_uuid)

    if [[ "$side" = "post-upgrade" ]]; then
        # Verify the cells v2 simple_cell_setup
        nova-manage cell_v2 verify_instance --uuid $uuid
    fi

    # Verify inventory and allocation values (requires admin)
    source_quiet $TOP_DIR/openrc admin admin

    for key in $NOVA_VERIFY_RESOURCE_CLASSES; do
        cval=$(_get_inventory_value $key)
        sval=$(resource_get nova nova_inventory_$key)
        if [ "$cval" != "$sval" ]; then
            die $LINENO "Checking inventory value ${key}=${sval} does not match current value ${cval}"
        fi
    done

    for key in $NOVA_VERIFY_RESOURCE_CLASSES; do
        cval=$(_get_allocation_value $uuid $key)
        sval=$(resource_get nova nova_server_allocation_$key)
        if [ "$cval" != "$sval" ]; then
            die $LINENO "Checking allocation value ${key}=${sval} does not match current value ${cval}"
        fi
    done
}

function verify_noapi {
    local server_ip=$(resource_get nova nova_server_ip)
    ping_check_public $server_ip 30
}

function destroy {
    _nova_set_user
    # Disassociate the floating IP from the server.
    openstack floating ip unset --port $(resource_get nova nova_server_ip)
    openstack floating ip delete $(resource_get nova nova_server_float)
    openstack server delete --wait $NOVA_SERVER

    openstack security group delete $NOVA_USER || /bin/true

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
