#!/usr/bin/env bash

# ``grenade.sh`` is an OpenStack upgrade test harness to exercise the
# upgrade process from Essex to Folsom.  It uses DevStack to perform
# the initial # Openstack install

# Grenade assumes it is running on the system that will be hosting the upgrade processes


# Keep track of the devstack directory
TOP_DIR=$(cd $(dirname "$0") && pwd)

# Import common functions
source $TOP_DIR/functions

# Determine what system we are running on.  This provides ``os_VENDOR``,
# ``os_RELEASE``, ``os_UPDATE``, ``os_PACKAGE``, ``os_CODENAME``
# and ``DISTRO``
GetDistro

# Source params
source $TOP_DIR/grenaderc

# For debugging
set -o xtrace


# System Preparation
# ==================

# perform cleanup to ensure a clean starting environment

# check out devstack
git_clone $DEVSTACK_START_REPO $DEVSTACK_START_DIR $DEVSTACK_START_BRANCH

# Set up localrc
cp -p $TOP_DIR/devstack.start.localrc $DEVSTACK_START_DIR/localrc

# clean up apache config
# essex devstack uses 000-default
# folsom devstack uses horizon -> ../sites-available/horizon
if [[ -e /etc/apache2/sites-enabled/horizon ]]; then
    # Clean up folsom-style
    sudo "a2dissite horizon; service apache2 reload"
fi

# TODO(dtroyer): Needs to get rid of modern glance command too
#                all command-line libs?  how do we want to handle them?


# Essex Install
# =============

cd $DEVSTACK_START_DIR

# TODO(dtroyer): the django admin account bug seems to be present, work
#                around it or fix it.  why haven't we heard from others
#                about this in stable/essex?

echo ./stack.sh


# Exercises
# =========

echo ./exercise.sh

