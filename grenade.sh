#!/usr/bin/env bash

# ``grenade.sh`` is an OpenStack upgrade test harness to exercise the
# OpenStack upgrade process.  It uses DevStack to perform the initial
# OpenStack install.

# Grenade assumes it is running on the system that will be hosting the
# upgrade processes


# Keep track of the devstack directory
GRENADE_DIR=$(cd $(dirname "$0") && pwd)

# Import common functions
source $GRENADE_DIR/functions

# Determine what system we are running on.  This provides ``os_VENDOR``,
# ``os_RELEASE``, ``os_UPDATE``, ``os_PACKAGE``, ``os_CODENAME``
# and ``DISTRO``
GetDistro

# Source params
source $GRENADE_DIR/grenaderc

# For debugging
set -o xtrace


# Prep DevStack
# =============

# We'll need both releases of DevStack eventually so grab them both now.
# Do final first so the 'current' state is pointing to the starting release.

$GRENADE_DIR/prep-final
$GRENADE_DIR/prep-start


# Install 'Start' Build of OpenStack
# ==================================

cd $DEVSTACK_START_DIR
./stack.sh


# Operation
# ---------

# Validate the install
echo $DEVSTACK_START_DIR/exercise.sh

# Create a project, users and instances
$GRENADE_DIR/setup-javelin

# Cleanup
# -------

# Shut down running code
echo $DEVSTACK_START_DIR/unstack.sh

# Don't do this for now
#$GRENADE_DIR/wrap-start


# Fin
# ===

echo "Grenade has completed the initial setup of the upgrade test."
echo "The following upgrade scripts are available:"
ls $GRENADE_DIR/upgrade-*
