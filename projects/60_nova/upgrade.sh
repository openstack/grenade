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

# Determine what system we are running on.  This provides ``os_VENDOR``,
# ``os_RELEASE``, ``os_UPDATE``, ``os_PACKAGE``, ``os_CODENAME``
# and ``DISTRO``
GetDistro

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
source $TARGET_DEVSTACK_DIR/lib/database
source $TARGET_DEVSTACK_DIR/lib/rpc_backend

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
$NOVA_BIN_DIR/nova-manage --config-file $NOVA_CONF api_db sync || die $LINENO "API DB sync error"
$NOVA_BIN_DIR/nova-manage --config-file $NOVA_CONF db sync || die $LINENO "DB sync error"

iniset $NOVA_CONF upgrade_levels compute auto

if [[ "$NOVA_ENABLE_UPGRADE_WORKAROUND" == "True" ]]; then
    iniset $NOVA_CONF workarounds disable_compute_service_check_for_ffu True
    iniset $NOVA_COND_CONF workarounds disable_compute_service_check_for_ffu True
    iniset $NOVA_CPU_CONF workarounds disable_compute_service_check_for_ffu True
fi

if [[ "$FORCE_ONLINE_MIGRATIONS" == "True" ]]; then
    # Run "online" migrations that can complete before we start
    $NOVA_BIN_DIR/nova-manage --config-file $NOVA_CONF db online_data_migrations || die $LINENO "Failed to run online_data_migrations"
fi

# Setup cellsv2 records
$NOVA_BIN_DIR/nova-manage cell_v2 map_cell0 --database_connection $(database_connection_url nova_cell0)
$NOVA_BIN_DIR/nova-manage cell_v2 simple_cell_setup --transport-url $(get_transport_url)

# Ensure the Placement service - this needs to be running before the nova-status
# upgrade check command is run since that validates that we can connect to
# the placement endpoint.
ensure_services_started placement-api

# The nova-status upgrade check has the following return codes:
# 0: Success - everything is good to go.
# 1: Warning - there is nothing blocking, but some issues were identified
# 2: Failure - something is definitely wrong and the upgrade will fail
# 255: Some kind of unexpected error occurred.
# The funky || here is to allow us to trap the exit code and not fail the
# entire run if the return code is non-zero.
$NOVA_BIN_DIR/nova-status upgrade check || {
    rc=$?
    if [[ $rc -ge 2 ]]; then
        echo "nova-status upgrade check has failed."
    fi
}

# Start Nova
start_nova_api
# NOTE(danms): Transition to conductor fleet; for now just start
# a conductor the old way to mirror people upgrading with the same
# service topology.
if [ $(type -t start_nova_conductor) ]; then
    run_process n-cond "$NOVA_BIN_DIR/nova-conductor --config-file $NOVA_CONF"
fi
start_nova_rest
start_nova_compute

# Don't succeed unless the services come up
expected_runnning_services="n-api n-cond "
# NOTE(vsaienko) Ironic should be upgraded before nova according to requirements
# https://docs.openstack.org/ironic/latest/admin/upgrade-guide.html#general-upgrades-all-versions
# using reverse order will lead to nova-compute start failure.
# Ironic will restart n-cpu after its upgrade.
# TODO(vsaienko) remove this once grenade allows to setup dependency between grenade plugin and
# core services: https://bugs.launchpad.net/grenade/+bug/1660646
if ! is_service_enabled ironic; then
    expected_runnning_services+=' n-cpu'
fi
ensure_services_started $expected_runnning_services

if [[ "$FORCE_ONLINE_MIGRATIONS" == "True" ]]; then
    # Run "online" migrations after we've got all the services running
    $NOVA_BIN_DIR/nova-manage --config-file $NOVA_CONF db online_data_migrations || die $LINENO "Failed to run online_data_migrations"
fi

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End $0"
echo "*********************************************************************"
