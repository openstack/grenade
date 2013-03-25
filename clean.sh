#!/usr/bin/env bash

# ``clean.sh`` does its best to eradicate traces of a Grenade
# run except for the following:
# - both base and target code repos are left alone
# - packages (system and pip) are left alone

# This means that all data files are removed.  More??

# Keep track of the Grenade directory
GRENADE_DIR=$(cd $(dirname "$0") && pwd)

# Import common functions
source $GRENADE_DIR/functions

# Determine what system we are running on.  This provides ``os_VENDOR``,
# ``os_RELEASE``, ``os_UPDATE``, ``os_PACKAGE``, ``os_CODENAME``
# and ``DISTRO``
GetDistro

# Source params
source $GRENADE_DIR/grenaderc

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace

# First attempt a pair of unstack calls
if [[ -d $BASE_DEVSTACK_DIR ]]; then
    bash -c "
      cd $BASE_DEVSTACK_DIR; \
      source functions; \
      source stackrc; \
      source lib/cinder; \
      DATA_DIR=\${DEST}/data; \
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
      source functions; \
      source stackrc; \
      source lib/cinder; \
      DATA_DIR=\${DEST}/data; \
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
sudo rm -rf /etc/keystone /etc/glance /etc/nova /etc/cinder /etc/swift

# Clean out tgt
sudo rm /etc/tgt/conf.d/*

# Get ruthless with #$%%&^^#$%#@$%ing rabbit
sudo killall epmd
sudo aptitude purge -y rabbitmq-server ~nerlang

# Get ruthless with mysql
service mysqld stop
sudo aptitude purge -y ~nmysql-server
sudo rm -rf /var/lib/mysql

# kill off swift, which doesn't live in screen, so doesn't die in screen
ps auxw | grep swift | awk '{print $2}' | xargs kill

