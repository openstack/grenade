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

NEUTRON_NET=neutron_grenade

# TODO: this is a placeholder file until such time as the appropriate
# resource flow can be sorted out, unwinding what's currently hard
# coded in javelin is a little odd.

function early_create {
    # this builds a default network for other services to use
    local net_id=$(neutron net-create --shared $NEUTRON_NET | grep ' id ' | get_field 2)
    resource_save network net_id $net_id

    local subnet_params=""
    subnet_params+="--ip_version 4 "
    subnet_params+="--gateway $NETWORK_GATEWAY "
    subnet_params+="--name $NEUTRON_NET "
    subnet_params+="$net_id $FIXED_RANGE"

    local subnet_id=$(neutron subnet-create $subnet_params | grep ' id ' | get_field 2)
    resource_save network subnet_id $subnet_id

    local router_id=$(neutron router-create $NEUTRON_NET | grep ' id ' | get_field 2)
    resource_save network router_id $router_id

    neutron router-interface-add $NEUTRON_NET $subnet_id
    neutron router-gateway-set $NEUTRON_NET public
}

function verify {
    :
}

function verify_noapi {
    :
}

function destroy {
    # Must clean the router before we can remove a net
    # set +o errexit
    neutron router-gateway-clear $(resource_get network router_id) || /bin/true
    neutron router-interface-delete $(resource_get network router_id) $(resource_get network subnet_id) || /bin/true
    neutron router-delete $(resource_get network router_id) || /bin/true
    neutron net-delete $(resource_get network net_id) || /bin/true
}


# Dispatcher
case $1 in
    "early_create")
        early_create
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
