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

CINDER_USER=cinder_grenade
CINDER_PROJECT=cinder_grenade
CINDER_PASS=pass
CINDER_SERVER=cinder_server1
CINDER_KEY=cinder_key
CINDER_KEY_FILE=$SAVE_DIR/cinder_key.pem
CINDER_VOL=cinder_grenade_vol
# don't put ' or " in this, it complicates things
CINDER_STATE="I am a teapot"
CINDER_STATE_FILE=verify.txt

DEFAULT_INSTANCE_TYPE=${DEFAULT_INSTANCE_TYPE:-m1.tiny}
DEFAULT_IMAGE_NAME=${DEFAULT_IMAGE_NAME:-cirros-0.3.2-x86_64-uec}

# glance v2 api doesn't implement the name based resources needed by
# OSC, so we disable it for now.
#
# Remove when:
# https://bugs.launchpad.net/python-openstackclient/+bug/1501362 is
# resolved.
export OS_IMAGE_API_VERSION=1

# BUG openstack client doesn't work with cinder v2
export OS_VOLUME_API_VERSION=1

if ! is_service_enabled c-api; then
    echo "Cinder is not enabled. Skipping resource phase $1 for cinder."
    exit 0
fi

function _cinder_set_user {
    OS_TENANT_NAME=$CINDER_PROJECT
    OS_PROJECT_NAME=$CINDER_PROJECT
    OS_USERNAME=$CINDER_USER
    OS_PASSWORD=$CINDER_PASS
}

function create {
    # creates a tenant for the server
    eval $(openstack project create -f shell -c id $CINDER_PROJECT)
    if [[ -z "$id" ]]; then
        die $LINENO "Didn't create $CINDER_PROJECT project"
    fi
    resource_save cinder project_id $id

    # creates the user, and sets $id locally
    eval $(openstack user create $CINDER_USER \
        --project $id \
        --password $CINDER_PASS \
        -f shell -c id)
    if [[ -z "$id" ]]; then
        die $LINENO "Didn't create $CINDER_USER user"
    fi
    resource_save cinder user_id $id

    # set ourselves to the created cinder user
    _cinder_set_user

    # setup a working security group
    # BUG(sdague): I have no idea how to make openstack security group work
    # openstack security group create --description "BUG" $CINDER_USER
    # openstack security group rule create --proto icmp --dst-port 0 $CINDER_USER
    # openstack security group rule create --proto tcp --dst-port 22 $CINDER_USER
    nova secgroup-create $CINDER_USER "BUG: this should not be mandatory"
    nova secgroup-add-rule $CINDER_USER icmp -1 -1 0.0.0.0/0
    nova secgroup-add-rule $CINDER_USER tcp 22 22 0.0.0.0/0

    # create key pairs for access
    openstack keypair create $CINDER_KEY > $CINDER_KEY_FILE
    chmod 600 $CINDER_KEY_FILE

    # Create a bootable volume
    eval $(openstack volume create --image $DEFAULT_IMAGE_NAME --size 1 $CINDER_VOL -f shell)
    resource_save cinder cinder_volume_id $id

    # BUG: openstack client doesn't support --wait on volumes, so loop
    # and wait until it's bootable. This typically only takes a second
    # or two.
    local timeleft=30
    while [[ $timeleft -gt 0 ]]; do
        eval $(openstack volume show cinder_grenade_vol -f shell -c bootable)
        if [[ "$bootable" != "true" ]]; then
            echo "Volume is not yet bootable, waiting..."
            sleep 1
            timeleft=$((timeleft - 1))
            if [[ $timeleft == 0 ]]; then
                die $LINENO "Volume failed to become bootable"
            fi
        else
            break
        fi
    done

    # work around for neutron because there is no such thing as a default
    local net_id=$(resource_get network net_id)
    if [[ -n "$net_id" ]]; then
        local net="--nic net-id=$net_id"
    fi

    # Boot from this volume
    openstack server create --volume $id \
        --flavor $DEFAULT_INSTANCE_TYPE \
        --security-group $CINDER_USER \
        --key-name $CINDER_KEY \
        $net \
        $CINDER_SERVER --wait

    # Add a floating IP because this is something which will work in
    # either n-net or neutron.
    eval $(openstack floating ip create public -f shell -c id -c ip -c floating_ip_address)
    # NOTE(dhellmann): Around version 3.0.0 of python-openstackclient
    # the column name changed from "ip" to "floating_ip_address". We
    # look for both here to support upgrades.
    if [[ -z "$ip" ]]; then
        ip="$floating_ip_address"
    fi
    resource_save cinder cinder_server_ip $ip
    resource_save cinder cinder_server_float $id
    openstack server add floating ip $CINDER_SERVER $ip

    # ping check on the way up so we can add ssh content
    ping_check_public $ip 30

    # turn of errexit for this portion of the retry
    set +o errexit
    local timeleft=30
    while [[ $timeleft -gt 0 ]]; do
        local start=$(date +%s)
        timeout 30 $FSSH -i $CINDER_KEY_FILE cirros@$ip \
                "echo '$CINDER_STATE' > $CINDER_STATE_FILE"
        local rc=$?

        if [[ "$rc" -ne 0 ]]; then
            echo "SSH not responding yet, trying again..."
            sleep 1
            local end=$(date +%s)
            local took=$((end - start))
            timeleft=$((timeleft - took))
            if [[ $timeleft -le 0 ]]; then
                die $LINENO "SSH to the client did not work, something very wrong"
            fi
        else
            break
        fi
    done

    # NOTE(sdague): for debugging when things go wrong, so we have a
    # before and an after
    worlddump cinder_resources_created
}

function verify {
    # just call verify_noapi, as that's an actual resource survival test
    verify_noapi
}

function verify_noapi {
    local server_ip=$(resource_get cinder cinder_server_ip)
    ping_check_public $server_ip 30
    # this sync is here to ensure that we don't accidentally pass when
    # the volume is actually down.
    timeout 30 $FSSH -i $CINDER_KEY_FILE cirros@$server_ip \
        "sync"
    local state=$($FSSH -i $CINDER_KEY_FILE cirros@$server_ip \
        "cat $CINDER_STATE_FILE")
    if [[ "$state" != "$CINDER_STATE" ]]; then
        die $LINENO "The expected state left in the volume isn't there!"
    fi
    echo "Cinder verify found the expected state file: SUCCESS!"
}

function destroy {
    _cinder_set_user
    openstack server remove floating ip $CINDER_SERVER $(resource_get cinder cinder_server_ip)
    openstack floating ip delete $(resource_get cinder cinder_server_float)

    openstack server delete $CINDER_SERVER
    # wait for server to be down before we delete the volume
    # TODO(mriedem): Use the --wait option with the openstack server delete
    # command when python-openstackclient>=1.4.0 is in global-requirements.
    local wait_cmd="while openstack server show $CINDER_SERVER >/dev/null; do sleep 1; done"
    timeout 30 sh -c "$wait_cmd"

    openstack volume delete $CINDER_VOL

    nova secgroup-delete $CINDER_USER

    # lastly, get rid of our user - done as admin
    source_quiet $TOP_DIR/openrc admin admin
    local user_id=$(resource_get cinder user_id)
    local project_id=$(resource_get cinder project_id)
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
    "force_destroy")
        set +o errexit
        destroy
        ;;
esac
