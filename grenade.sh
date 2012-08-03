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

#source $TOP_DIR/grenaderc

# Possible grenaderc values

# Destination path for installation ``DEST``
DEST=${DEST:-/opt/stack}

# Release info
START_RELEASE=essex
END_RELEASE=folsom

DEVSTACK_BEFORE_REPO=https://github.com/openstack-dev/devstack.git
DEVSTACK_BEFORE_BRANCH=stable/$START_RELEASE
DEVSTACK_BEFORE_DIR=$DEST/devstack

DEVSTACK_AFTER_REPO=$DEVSTACK_BEFORE_REPO
DEVSTACK_AFTER_BRANCH=master
DEVSTACK_AFTER_DIR=devstack-master


# System Preparation
# ==================

# perform cleanup to ensure a clean starting environment

# check out devstack
git_clone $DEVSTACK_BEFORE_REPO $DEVSTACK_BEFORE_DIR $DEVSTACK_BEFORE_BRANCH


# Essex Install
# =============

# Exercises
# =========

