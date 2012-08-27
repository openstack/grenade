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

# Exercises
# ---------

echo ./exercise.sh


# Shut down running code
./unstack.sh


# Final Configuration
# ===================

# Folsom Preparation
# ------------------

$GRENADE_DIR/prep-start

# Rename databases
myauth="-uroot -p$MYSQL_PASSWORD"
for db in glance keystone nova; do
    new_db=${db}_essex
    echo "Renaming $db to $new_db"
    mysql $myauth -e "DROP DATABASE $new_db; CREATE DATABASE $new_db;"
    for i in $(mysql -Ns $1 -e "SHOW TABLES" $db);do
        mysql $myauth -e "RENAME TABLE $db.$i TO $new_db.$i"
    done
    mysql $myauth -e "DROP DATABASE $db"
done

# Folsom Install
# --------------

cd $DEVSTACK_FINAL_DIR
./stack.sh
