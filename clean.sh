#!/usr/bin/env bash

# ``clean.sh`` does its best to eradicate traces of a Grenade
# run except for the following:
# - both base and target code repos are left alone
# - packages (system and pip) are left alone

# This means that all data files are removed.  More??

# Keep track of the Grenade directory
GRENADE_DIR=$(cd $(dirname "$0") && pwd)

# Import common functions
source $GRENADE_DIR/grenaderc

source $GRENADE_DIR/functions

# Determine what system we are running on.  This provides ``os_VENDOR``,
# ``os_RELEASE``, ``os_UPDATE``, ``os_PACKAGE``, ``os_CODENAME``
# and ``DISTRO``
GetDistro


# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace

# First attempt a pair of unstack calls
if [[ -d $BASE_DEVSTACK_DIR ]]; then
    bash -c "
        cd $BASE_DEVSTACK_DIR; \
        source stackrc; \
        source lib/tls; \
        source lib/cinder; \
        DATA_DIR=${STACK_ROOT}/data; \
        ./unstack.sh --all; \
        cd -; \
        sudo losetup -d \$(sudo losetup -j \$DATA_DIR/\${VOLUME_GROUP}-backing-file | awk -F':' '/backing-file/ { print \$1}'); \
        if mount | grep \$DATA_DIR/swift/drives; then \
            umount \$DATA_DIR/swift/drives/sdb1; \
        fi; \
        sudo rm -rf \$DATA_DIR \$DATA_DIR.hide; \
    "
    # get rid of the hard-coded filename above!!!
fi
if [[ -d $TARGET_DEVSTACK_DIR ]]; then
    bash -x -c "
        cd $TARGET_DEVSTACK_DIR; \
        source stackrc; \
        source lib/tls; \
        source lib/cinder; \
        DATA_DIR=${STACK_ROOT}/data; \
        ./unstack.sh --all; \
        cd -; \
        # need to test if volume is present
        sudo losetup -d \$(sudo losetup -j \$DATA_DIR/\${VOLUME_GROUP}-backing-file | awk -F':' '/backing-file/ { print \$1}'); \
        if mount | grep \$DATA_DIR/swift/drives; then \
            sudo umount \$DATA_DIR/swift/drives/sdb1; \
        fi; \
        sudo rm -rf \$DATA_DIR; \
    "
fi

# Clean out /etc
sudo rm -rf /etc/keystone /etc/glance /etc/nova /etc/cinder /etc/swift /etc/neutron

# Clean out tgt
sudo rm /etc/tgt/conf.d/*

# Get ruthless with #$%%&^^#$%#@$%ing rabbit
ps auxw | grep ^rabbitmq | awk '{print $2}' | sudo xargs kill
sudo service rabbitmq-server stop
sudo apt-get purge -y rabbitmq-server .*erlang

# Get ruthless with mysql
service mysqld stop
sudo apt-get  purge -y .*mysql-server
sudo rm -rf /var/lib/mysql

# kill off swift, which doesn't live in screen, so doesn't die in screen
ps auxw | grep swift | awk '{print $2}' | xargs kill

# purge all the repo pulls
sudo rm -rf $BASE_RELEASE_DIR
sudo rm -rf $TARGET_RELEASE_DIR
