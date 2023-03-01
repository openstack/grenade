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
CINDER_VOL2=cinder_grenade_vol2
CINDER_VOL3=cinder_grenade_vol3
CINDER_VOL_ENCRYPTED_TYPE=cinder_grenade_encrypted_type
# don't put ' or " in this, it complicates things
CINDER_STATE="I am a teapot"
CINDER_STATE_FILE=verify.txt

DEFAULT_INSTANCE_TYPE=${DEFAULT_INSTANCE_TYPE:-m1.tiny}
DEFAULT_IMAGE_NAME=${DEFAULT_IMAGE_NAME:-cirros-0.3.2-x86_64-uec}

export OS_IMAGE_API_VERSION=2

# Block Storage API v2 was deprecated in Pike and removed in Xena
export OS_VOLUME_API_VERSION=3

if ! is_service_enabled c-api; then
    echo "Cinder is not enabled. Skipping resource phase $1 for cinder."
    exit 0
fi

function _wait_for_volume_update {
    # TODO(mriedem): Replace with --wait once OSC story 2002158 is complete.
    # https://storyboard.openstack.org/#!/story/2002158
    local volume=$1
    local field=$2
    local desired_status=$3
    local timeleft=30
    local status=""
    while [[ $timeleft -gt 0 ]]; do
        status=$(openstack volume show $volume -f value -c $field)
        if [[ "$status" != "$desired_status" ]]; then
            echo "Volume ${volume} ${field} is ${status} and not yet ${desired_status}, waiting..."
            sleep 1
            timeleft=$((timeleft - 1))
            if [[ $timeleft == 0 ]]; then
                die $LINENO "Timed out waiting for volume ${volume} ${field} to be ${desired_status}"
            fi
        else
            break
        fi
    done
}

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
    local project_id=$id

    # creates the user, and sets $id locally
    eval $(openstack user create $CINDER_USER \
        --project $project_id \
        --password $CINDER_PASS \
        -f shell -c id)
    if [[ -z "$id" ]]; then
        die $LINENO "Didn't create $CINDER_USER user"
    fi
    resource_save cinder user_id $id

    openstack role add member --user $id --project $project_id

    # Create an encrypted volume type as admin
    eval $(openstack volume type create \
        --encryption-provider nova.volume.encryptors.luks.LuksEncryptor \
        --encryption-cipher aes-xts-plain64 --encryption-key-size 256 \
        $CINDER_VOL_ENCRYPTED_TYPE -f shell)
    resource_save cinder cinder_encrypted_volume_type_id $id

    # set ourselves to the created cinder user
    _cinder_set_user

    # setup a working security group
    # BUG(sdague): I have no idea how to make openstack security group work
    openstack security group create --description "BUG" $CINDER_USER
    openstack security group rule create --proto icmp --dst-port 0 $CINDER_USER
    openstack security group rule create --proto tcp --dst-port 22 $CINDER_USER

    # create key pairs for access
    ssh-keygen -f $CINDER_KEY_FILE -N '' -t ecdsa
    openstack keypair create $CINDER_KEY --public-key ${CINDER_KEY_FILE}.pub

    # Create a bootable volume
    eval $(openstack volume create --image $DEFAULT_IMAGE_NAME --size 1 $CINDER_VOL -f shell)
    resource_save cinder cinder_volume_id $id

    # Wait for the volume to be marked as bootable
    _wait_for_volume_update $CINDER_VOL "bootable" "true"

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

    # Create a second (not bootable) volume to test attach/detach
    eval $(openstack volume create --size 1 $CINDER_VOL2 -f shell)
    resource_save cinder cinder_volume2_id $id

    # Wait for the volume to be available before attaching it to the server.
    _wait_for_volume_update $CINDER_VOL2 "status" "available"

    # Attach second volume and ensure it becomes in-use
    openstack server add volume $CINDER_SERVER $CINDER_VOL2
    _wait_for_volume_update $CINDER_VOL2 "status" "in-use"

    # Create an encrypted (non-bootable) volume to attach and detach
    eval $(openstack volume create --size 1 $CINDER_VOL3 --type $CINDER_VOL_ENCRYPTED_TYPE -f shell)
    resource_save cinder cinder_volume3_id $id
    _wait_for_volume_update $CINDER_VOL3 "status" "available"

    # Attach the encrypted volume and ensure it becomes in-use
    openstack server add volume $CINDER_SERVER $CINDER_VOL3
    _wait_for_volume_update $CINDER_VOL3 "status" "in-use"

    # ping check on the way up so we can add ssh content
    ping_check_public $ip 60

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
                # Collect debugging information then die
                openstack console log show $CINDER_SERVER
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
    local side="$1"
    _cinder_set_user

    # call verify_noapi for the resource survival test
    verify_noapi

    # Ensure volume is attached, and verify detach functions as expected post-upgrade
    if [[ "$side" = "post-upgrade" ]]; then
        eval $(openstack volume show $CINDER_VOL2 -f shell -c status)
        if [[ "$status" != "in-use" ]]; then
            die $LINENO "Unexpected status of volume $CINDER_VOL2 (expected in-use, but was $status)"
        fi
        eval $(openstack volume show $CINDER_VOL3 -f shell -c status)
        if [[ "$status" != "in-use" ]]; then
            die $LINENO "Unexpected status of volume $CINDER_VOL3 (expected in-use, but was $status)"
        fi

        # Verify detach
        openstack server remove volume $CINDER_SERVER $CINDER_VOL2
        _wait_for_volume_update $CINDER_VOL2 "status" "available"

        openstack server remove volume $CINDER_SERVER $CINDER_VOL3
        _wait_for_volume_update $CINDER_VOL3 "status" "available"

        echo "Cinder verify post-upgrade successfully detached volume"
    fi
}

function verify_noapi {
    local server_ip=$(resource_get cinder cinder_server_ip)
    ping_check_public $server_ip 60
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

function _wait_for_volume_delete() {
    local DELETE_TIMEOUT=30
    local volume="$1"
    local count=0
    local status=$(openstack volume list --name ${volume} -f value -c ID | wc -l)
    echo "Waiting for volume ${volume} to be deleted."
    while [ $status -ne 0 ]
    do
        sleep 1
        count=$((count+1))
        if [ ${count} -eq ${DELETE_TIMEOUT} ]; then
            die $LINENO "Timed out waiting for volume ${volume} to be deleted."
        fi
        status=$(openstack volume list --name ${volume} -f value -c ID | wc -l)
    done
}

function destroy {
    _cinder_set_user
    # Disassociate the floating IP from the server.
    openstack floating ip unset --port $(resource_get cinder cinder_server_ip)
    openstack floating ip delete $(resource_get cinder cinder_server_float)

    openstack server delete --wait $CINDER_SERVER

    openstack volume delete $CINDER_VOL
    openstack volume delete $CINDER_VOL2
    openstack volume delete $CINDER_VOL3

    # Volume delete is async so wait for the encrypted volume to be removed
    # before proceeding and trying to delete the volume type below.
    _wait_for_volume_delete $CINDER_VOL3

    openstack security group delete $CINDER_USER

    # lastly, get rid of our volume type and user - done as admin
    source_quiet $TOP_DIR/openrc admin admin
    openstack volume type delete $CINDER_VOL_ENCRYPTED_TYPE
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
