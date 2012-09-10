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


# Install 'Work' Build of OpenStack
# =================================

$GRENADE_DIR/prep-work

cd $WORK_DEVSTACK_DIR
./stack.sh

# Operation
# ---------

# Validate the install
echo $WORK_DEVSTACK_DIR/exercise.sh

# Create a project, users and instances
$GRENADE_DIR/setup-javelin

# Shut down running code
$WORK_DEVSTACK_DIR/unstack.sh


# Logging
# =======

# Set up logging
# Set ``LOGFILE`` to turn on logging
# Append '.xxxxxxxx' to the given name to maintain history
# where 'xxxxxxxx' is a representation of the date the file was created
if [[ -n "$LOGFILE" ]]; then
    LOGDAYS=${LOGDAYS:-7}
    TIMESTAMP_FORMAT=${TIMESTAMP_FORMAT:-"%F-%H%M%S"}
    CURRENT_LOG_TIME=$(date "+$TIMESTAMP_FORMAT")

    # First clean up old log files.  Use the user-specified ``LOGFILE``
    # as the template to search for, appending '.*' to match the date
    # we added on earlier runs.
    LOGDIR=$(dirname "$LOGFILE")
    LOGNAME=$(basename "$LOGFILE")
    mkdir -p $LOGDIR
    find $LOGDIR -maxdepth 1 -name $LOGNAME.\* -mtime +$LOGDAYS -exec rm {} \;

    LOGFILE=$LOGFILE.${CURRENT_LOG_TIME}
    # Redirect stdout/stderr to tee to write the log file
    exec 1> >( tee "${LOGFILE}" ) 2>&1
    echo "grenade.sh log $LOGFILE"
    # Specified logfile name always links to the most recent log
    ln -sf $LOGFILE $LOGDIR/$LOGNAME
fi


# Upgrades
# ========

source $TRUNK_DEVSTACK_DIR/stackrc

# Create a new named screen to run processes in
screen -d -m -S $SCREEN_NAME -t shell -s /bin/bash
sleep 1
# Set a reasonable statusbar
SCREEN_HARDSTATUS=${SCREEN_HARDSTATUS:-'%{= .} %-Lw%{= .}%> %n%f %t*%{= .}%+Lw%< %-=%{g}(%{d}%H/%l%{g})'}
screen -r $SCREEN_NAME -X hardstatus alwayslastline "$SCREEN_HARDSTATUS"

# Upgrade OS packages and known Python updates
$GRENADE_DIR/upgrade-packages

# Upgrade DevStack
#$GRENADE_DIR/upgrade-devstack
$GRENADE_DIR/prep-trunk

# Upgrade Keystone
$GRENADE_DIR/upgrade-keystone

# Upgrade Glance
$GRENADE_DIR/upgrade-glance

# Upgrade Nova
#$GRENADE_DIR/upgrade-nova

# Upgrade Volumes to Cinder
#$GRENADE_DIR/upgrade-volume


# Fin
# ===

echo "Grenade has completed the initial setup of the upgrade test."
echo "The following upgrade scripts are available:"
ls $GRENADE_DIR/upgrade-*
