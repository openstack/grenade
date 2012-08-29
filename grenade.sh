#!/usr/bin/env bash

# ``grenade.sh`` is an OpenStack upgrade test harness to exercise the
# upgrade process from Essex to Folsom.  It uses DevStack to perform
# the initial Openstack install

# Grenade assumes it is running on the system that will be hosting the upgrade processes


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


# Start Configutation
# ===================

# Essex Preparation
# -----------------

$GRENADE_DIR/prep-start

# Essex Install
# -------------

# TODO(dtroyer): the django admin account bug seems to be present, work
#                around it or fix it.  why haven't we heard from others
#                about this in stable/essex?

cd $DEVSTACK_START_DIR
./stack.sh

# Operation
# ---------

# Validate the install
echo ./exercise.sh

# Create a project, users and instances
echo $GRENADE_DIR/setup-javelin

# Cleanup
# -------

# Shut down running code
./unstack.sh

$GRENADE_DIR/wrap-start


# Final Configuration
# ===================

# Folsom Preparation
# ------------------

$GRENADE_DIR/prep-final

# Folsom Install
# --------------

cd $DEVSTACK_FINAL_DIR
./stack.sh

# Exercises
# ---------

echo ./exercise.sh

# Cleanup
# -------

# Shut down running code
./unstack.sh

$GRENADE_DIR/wrap-final
