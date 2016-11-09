#!/usr/bin/env bash

# ``upgrade-neutron``

echo "*********************************************************************"
echo "Begin $0"
echo "*********************************************************************"

# Clean up any resources that may be in use
cleanup() {
    set +o errexit

    echo "*********************************************************************"
    echo "ERROR: Abort $0"
    echo "*********************************************************************"

    # Kill ourselves to signal any calling process
    trap 2; kill -2 $$
}

trap cleanup SIGHUP SIGINT SIGTERM

# Keep track of the grenade directory
RUN_DIR=$(cd $(dirname "$0") && pwd)

# Source params
source $GRENADE_DIR/grenaderc

# Import common functions
source $GRENADE_DIR/functions

# Determine what system we are running on.  This provides ``os_VENDOR``,
# ``os_RELEASE``, ``os_UPDATE``, ``os_PACKAGE``, ``os_CODENAME``
# and ``DISTRO``
GetDistro


# This script exits on an error so that errors don't compound and you see
# only the first error that occurred.
set -o errexit

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace

# Upgrade Neutron
# ===============

# Make sure neutron is available
if $(source $BASE_DEVSTACK_DIR/stackrc; ! is_service_enabled neutron); then
    exit 0
fi

MYSQL_HOST=${MYSQL_HOST:-localhost}
MYSQL_USER=${MYSQL_USER:-root}
BASE_SQL_CONN=$(source $BASE_DEVSTACK_DIR/stackrc; echo ${BASE_SQL_CONN:-mysql://$MYSQL_USER:$MYSQL_PASSWORD@$MYSQL_HOST})

# Duplicate some setup bits from target DevStack
source $TARGET_DEVSTACK_DIR/stackrc

# From stack.sh
FLOATING_RANGE=${FLOATING_RANGE:-172.24.4.224/28}
FIXED_RANGE=${FIXED_RANGE:-10.0.0.0/24}
FIXED_NETWORK_SIZE=${FIXED_NETWORK_SIZE:-256}

HOST_IP=$(get_default_host_ip $FIXED_RANGE $FLOATING_RANGE "$HOST_IP_IFACE" "$HOST_IP")
if [ "$HOST_IP" == "" ]; then
    die $LINENO "Could not determine host ip address. Either localrc specified dhcp on ${HOST_IP_IFACE} or defaulted"
fi

# Allow the use of an alternate hostname (such as localhost/127.0.0.1) for service endpoints.
SERVICE_HOST=${SERVICE_HOST:-$HOST_IP}

# Allow the use of an alternate protocol (such as https) for service endpoints
SERVICE_PROTOCOL=${SERVICE_PROTOCOL:-http}

# Configure services to use syslog instead of writing to individual log files
SYSLOG=`trueorfalse False $SYSLOG`
SYSLOG_HOST=${SYSLOG_HOST:-$HOST_IP}
SYSLOG_PORT=${SYSLOG_PORT:-516}

# Set for DevStack compatibility
TOP_DIR=$TARGET_DEVSTACK_DIR

# Get functions from current DevStack
source $TARGET_DEVSTACK_DIR/lib/apache
source $TARGET_DEVSTACK_DIR/lib/tls
source $TARGET_DEVSTACK_DIR/lib/keystone
[[ -r $TARGET_DEVSTACK_DIR/lib/neutron ]] && source $TARGET_DEVSTACK_DIR/lib/neutron
source $TARGET_DEVSTACK_DIR/lib/neutron-legacy
source $TARGET_DEVSTACK_DIR/lib/database
source $TARGET_DEVSTACK_DIR/lib/nova

#TODO(jlibosva): Remove once neutron starts using oslo.messaging.
#python-qpid was removed as a part of unfubar_setuptools() function
sudo apt-get -y install python-qpid

# Install latest bits
install_neutron
install_neutronclient
install_neutron_agent_packages

Q_L3_CONF_FILE=${Q_L3_CONF_FILE:-"$NEUTRON_CONF_DIR/l3_agent.ini"}
Q_FWAAS_CONF_FILE=${Q_FWAAS_CONF_FILE:-"$NEUTRON_CONF_DIR/fwaas_driver.ini"}

upgrade_project neutron $RUN_DIR $BASE_DEVSTACK_BRANCH $TARGET_DEVSTACK_BRANCH

# Get plugin config paths
neutron_plugin_configure_common
Q_PLUGIN_CONF_FILE=$Q_PLUGIN_CONF_PATH/$Q_PLUGIN_CONF_FILENAME

# Migrate DB
neutron-db-manage --config-file $NEUTRON_CONF --config-file /$Q_PLUGIN_CONF_FILE upgrade head

# Set binaries and config file paths for neutron services
# FIXME(jlibosva): Separate variables setting from config files configuration in devstack
AGENT_DHCP_BINARY=${AGENT_DHCP_BINARY:-"$NEUTRON_BIN_DIR/neutron-dhcp-agent"}
Q_DHCP_CONF_FILE=${Q_DHCP_CONF_FILE:-"$NEUTRON_CONF_DIR/dhcp_agent.ini"}

AGENT_META_BINARY=${AGENT_META_BINARY:-"$NEUTRON_BIN_DIR/neutron-metadata-agent"}
Q_META_CONF_FILE=${Q_META_CONF_FILE:-"$NEUTRON_CONF_DIR/metadata_agent.ini"}

if [ "$Q_AGENT" == "linuxbridge" ]; then
    AGENT_BINARY=${AGENT_BINARY:-"$NEUTRON_BIN_DIR/neutron-linuxbridge-agent"}
else
    # fall back to openvswitch as the default
    AGENT_BINARY=${AGENT_BINARY:-"$NEUTRON_BIN_DIR/neutron-openvswitch-agent"}
fi

AGENT_LBAAS_BINARY=${AGENT_LBAAS_BINARY:-"$NEUTRON_BIN_DIR/neutron-lbaas-agent"}
LBAAS_AGENT_CONF_FILENAME=${LBAAS_AGENT_CONF_FILENAME:-"/etc/neutron/services/loadbalancer/haproxy/lbaas_agent.ini"}

AGENT_METERING_BINARY=${AGENT_METERING_BINARY:-"$NEUTRON_BIN_DIR/neutron-metering-agent"}
METERING_AGENT_CONF_FILENAME=${METERING_AGENT_CONF_FILENAME:-"/etc/neutron/services/metering/metering_agent.ini"}

AGENT_L3_BINARY=${AGENT_L3_BINARY:-"$NEUTRON_BIN_DIR/neutron-l3-agent"}
AGENT_VPN_BINARY=${AGENT_VPN_BINARY:-"$NEUTRON_BIN_DIR/neutron-vpn-agent"}

# Start neutron and agents
start_neutron_service_and_check
start_neutron_agents

# Don't succeed unless the services come up
# TODO: service names ensure_services_started
ensure_logs_exist q-svc

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End $0"
echo "*********************************************************************"
