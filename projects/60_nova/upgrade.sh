#!/usr/bin/env bash

# ``upgrade-nova``

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

# This script exits on an error so that errors don't compound and you see
# only the first error that occurred.
set -o errexit

# Upgrade Nova
# ============

# Duplicate some setup bits from target DevStack
source $TARGET_DEVSTACK_DIR/stackrc
source $TARGET_DEVSTACK_DIR/lib/tls
source $TARGET_DEVSTACK_DIR/lib/apache
source $TARGET_DEVSTACK_DIR/lib/nova
source $TARGET_DEVSTACK_DIR/lib/rpc_backend
source $TARGET_DEVSTACK_DIR/lib/placement

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace

# Save current config files for posterity
[[ -d $SAVE_DIR/etc.nova ]] || cp -pr $NOVA_CONF_DIR $SAVE_DIR/etc.nova

# calls pre-upgrade hooks for within-$base before we upgrade
upgrade_project nova $RUN_DIR $BASE_DEVSTACK_BRANCH $BASE_DEVSTACK_BRANCH

# install_nova()
stack_install_service nova

# calls upgrade-nova for specific release
upgrade_project nova $RUN_DIR $BASE_DEVSTACK_BRANCH $TARGET_DEVSTACK_BRANCH

# Simulate init_nova()
create_nova_keys_dir

# Migrate the database
$NOVA_BIN_DIR/nova-manage --config-file $NOVA_CONF db sync || die $LINENO "DB sync error"
$NOVA_BIN_DIR/nova-manage --config-file $NOVA_CONF api_db sync || die $LINENO "API DB sync error"

iniset $NOVA_CONF upgrade_levels compute auto

if [[ "$FORCE_ONLINE_MIGRATIONS" == "True" ]]; then
    # Run "online" migrations that can complete before we start
    $NOVA_BIN_DIR/nova-manage --config-file $NOVA_CONF db online_data_migrations || die $LINENO "Failed to run online_data_migrations"
fi

# Setup cellsv2 records, if necessary.
if [ "$NOVA_CONFIGURE_CELLSV2" == "True" ]; then
    ($NOVA_BIN_DIR/nova-manage cell_v2 map_cell0 --database_connection $(database_connection_url nova_cell0) || true)
    $NOVA_BIN_DIR/nova-manage cell_v2 simple_cell_setup --transport-url $(get_transport_url)
fi

# Start Nova
start_nova_api
start_nova
start_placement

# Don't succeed unless the services come up
expected_runnning_services="nova-api nova-conductor placement "
# NOTE(vsaienko) Ironic should be upgraded before nova according to requirements
# http://docs.openstack.org/developer/ironic/deploy/upgrade-guide.html#general-upgrades-all-versions
# using reverse order will lead to nova-compute start failure.
# Ironic will restart n-cpu after its upgrade.
# TODO(vsaienko) remove this once grenade allows to setup dependency between grenade plugin and
# core services: https://bugs.launchpad.net/grenade/+bug/1660646
if ! is_service_enabled ironic; then
    expected_runnning_services+=' nova-compute'
fi
ensure_services_started $expected_runnning_services
ensure_logs_exist n-api n-cond n-cpu

if [[ "$FORCE_ONLINE_MIGRATIONS" == "True" ]]; then
    # Run "online" migrations after we've got all the services running
    $NOVA_BIN_DIR/nova-manage --config-file $NOVA_CONF db online_data_migrations || die $LINENO "Failed to run online_data_migrations"
fi

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End $0"
echo "*********************************************************************"
