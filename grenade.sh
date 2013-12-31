#!/usr/bin/env bash

# ``grenade.sh`` is an OpenStack upgrade test harness to exercise the
# OpenStack upgrade process.  It uses DevStack to perform the initial
# OpenStack install.

# Grenade assumes it is running on the system that will be hosting the
# upgrade processes

# ``grenade.sh [-b] [-t] [-s stop-label] [-q]``
#
# ``-b``    Run only the base part
# ``-t``    Run only the target part (assumes a base run is in place)
# ``-q``    Quiet mode
# ``-s stop-label`` is the name of the step after which the script will stop.
# This is useful for debugging upgrades.

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

RUN_BASE=$(trueorfalse True $RUN_BASE)
RUN_TARGET=$(trueorfalse True $RUN_TARGET)
VERBOSE=$(trueorfalse True $VERBOSE)

while getopts bqs:t c; do
    case $c in
        b)
            RUN_TARGET=False
            ;;
        q)
            VERBOSE=False
            ;;
        s)
            STOP=$2
            ;;
        t)
            RUN_BASE=False
            ;;
    esac
done
shift `expr $OPTIND - 1`

function echo_summary() {
    echo $@ >&6
}

function echo_nolog() {
    echo $@ >&3
}

function stop() {
    stop=$1
    shift
    if [[ "$@" =~ "$stop" ]]; then
        echo "STOP called for $1"
        exit 1
    fi
}

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
    echo "Creating $LOGDIR...."

    mkdir -p $LOGDIR
    find $LOGDIR -maxdepth 1 -name $LOGNAME.\* -mtime +$LOGDAYS -exec rm {} \;
    LOGFILE=$LOGFILE.${CURRENT_LOG_TIME}
    SUMFILE=$LOGFILE.${CURRENT_LOG_TIME}.summary

    # Redirect output according to config
    # Copy stdout to fd 3
    exec 3>&1
    if [[ "$VERBOSE" == "True" ]]; then
        # Redirect stdout/stderr to tee to write the log file
        exec 1> >( tee "${LOGFILE}" ) 2>&1
        # Set up a second fd for output
        exec 6> >( tee "${SUMFILE}" )
    else
        # Set fd 1 and 2 to primary logfile
        exec 1> "${LOGFILE}" 2>&1
        # Set fd 6 to summary logfile and stdout
        exec 6> >( tee "${SUMFILE}" /dev/fd/3 )
    fi

    echo_summary "grenade.sh log $LOGFILE"
    # Specified logfile name always links to the most recent log
    ln -sf $LOGFILE $LOGDIR/$LOGNAME
    ln -sf $SUMFILE $LOGDIR/$LOGNAME.summary
else
    # Set up output redirection without log files
    # Copy stdout to fd 3
    exec 3>&1
    if [[ "$VERBOSE" != "yes" ]]; then
        # Throw away stdout and stderr
        exec 1>/dev/null 2>&1
    fi
    # Always send summary fd to original stdout
    exec 6>&3
fi

# Set up logging of screen windows
# Set ``SCREEN_LOGDIR`` to turn on logging of screen windows to the
# directory specified in ``SCREEN_LOGDIR``, we will log to the the file
# ``screen-$SERVICE_NAME-$TIMESTAMP.log`` in that dir and have a link
# ``screen-$SERVICE_NAME.log`` to the latest log file.
# Logs are kept for as long specified in ``LOGDAYS``.
if [[ -n "$SCREEN_LOGDIR" ]]; then

    # We make sure the directory is created.
    if [[ -d "$SCREEN_LOGDIR" ]]; then
        # We cleanup the old logs
        find $SCREEN_LOGDIR -maxdepth 1 -name screen-\*.log -mtime +$LOGDAYS -exec rm {} \;
    else
        mkdir -p $SCREEN_LOGDIR
    fi
fi

# This script exits on an error so that errors don't compound and you see
# only the first error that occured.
set -o errexit

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace


# More Setup
# ==========

# Set up for exercises
BASE_RUN_EXERCISES=${BASE_RUN_EXERCISES:-RUN_EXERCISES}
TARGET_RUN_EXERCISES=${TARGET_RUN_EXERCISES:-RUN_EXERCISES}

# Set up for smoke tests (default to False)
TARGET_RUN_SMOKE=${TARGET_RUN_SMOKE:=False}

# Install 'Base' Build of OpenStack
# =================================

if [[ "$RUN_BASE" == "True" ]]; then
    #echo_summary "Sourcing base DevStack config"
    #source $BASE_DEVSTACK_DIR/stackrc

    echo_summary "Running prep-base"
    $GRENADE_DIR/prep-base
    stop $STOP prep-base 01

    echo_summary "Running base stack.sh"
    cd $BASE_DEVSTACK_DIR
    ./stack.sh
    stop $STOP stack.sh 10

    # Cache downloaded instances
    # --------------------------

    echo_summary "Caching downloaded images"
    mkdir -p $BASE_RELEASE_DIR/images
    echo "Images: $IMAGE_URLS"
    for image_url in ${IMAGE_URLS//,/ }; do
        IMAGE_FNAME=`basename "$image_url"`
        if [[ -r $BASE_DEVSTACK_DIR/files/$IMAGE_FNAME ]]; then
            rsync -av $BASE_DEVSTACK_DIR/files/$IMAGE_FNAME $BASE_RELEASE_DIR/images
        fi
    done
    rsync -av $BASE_DEVSTACK_DIR/files/images/ $BASE_RELEASE_DIR/images
    stop $STOP image-cache 20

    # Operation
    # ---------

    # Validate the install
    echo_summary "Running base exercises"
    if [[ "$BASE_RUN_EXERCISES" == "True" ]]; then
        $BASE_DEVSTACK_DIR/exercise.sh
    fi
    stop $STOP base-exercise 110

    # Create a project, users and instances
    echo_summary "Creating Javelin project"
    $GRENADE_DIR/setup-javelin
    stop $STOP setup-javelin 120

    # Save some stuff before we shut that whole thing down
    echo_summary "Saving current state information"
    $GRENADE_DIR/save-state
    stop $STOP save-state 130

    # Shut down running code
    echo_summary "Shutting down base"
    # unstack.sh is too aggressive in cleaning up by default
    # so we'll do it ourselves...
    $GRENADE_DIR/stop-base
    stop $STOP stop-base 140
fi


# Upgrades
# ========

if [[ "$RUN_TARGET" == "True" ]]; then
    # Get target bits ready
    echo_summary "Running prep-target"
    $GRENADE_DIR/prep-target
    stop $STOP prep-target 210

    # Upgrade OS packages and known Python updates
    echo_summary "Running upgrade-packages"
    #$GRENADE_DIR/upgrade-packages
    stop $STOP upgrade-packages 220

    # Upgrade DevStack
    echo_summary "Running upgrade-devstack"
    #$GRENADE_DIR/upgrade-devstack
    stop $STOP upgrade-devstack 230

    # Upgrade Infra
    echo_summary "Running upgrade-infra"
    $GRENADE_DIR/upgrade-infra || die $LINENO "Failure in upgrade-infra"
    stop $STOP upgrade-infra 232

    # Upgrade Oslo
    echo_summary "Running upgrade-oslo"
    $GRENADE_DIR/upgrade-oslo || die $LINENO "Failure in upgrade-oslo"
    stop $STOP upgrade-oslo 235

    # Upgrade Keystone
    echo_summary "Running upgrade-keystone"
    $GRENADE_DIR/upgrade-keystone || die $LINENO "Failure in upgrade-keystone"
    stop $STOP upgrade-keystone 240

    # Upgrade Swift
    echo_summary "Running upgrade-swift"
    $GRENADE_DIR/upgrade-swift || die $LINENO "Failure in upgrade-swift"
    stop $STOP upgrade-swift 245

    # Upgrade Glance
    echo_summary "Running upgrade-glance"
    $GRENADE_DIR/upgrade-glance || die $LINENO "Failure in upgrade-glance"
    stop $STOP upgrade-glance 250

    # Upgrade Nova
    echo_summary "Running upgrade-nova"
    $GRENADE_DIR/upgrade-nova || die $LINENO "Failure in upgrade-nova"
    stop $STOP upgrade-nova 260

    # Upgrade Cinder
    echo_summary "Running upgrade-cinder"
    $GRENADE_DIR/upgrade-cinder || die $LINENO "Failure in upgrade-cinder"
    stop $STOP upgrade-cinder 270

    # Upgrade Tempest
    if [[ "$ENABLE_TEMPEST" == "True" ]]; then
        echo_summary "Running upgrade-tempest"
        $GRENADE_DIR/upgrade-tempest || die $LINENO "Failure in upgrade-tempest"
        stop $STOP upgrade-tempest 290
    fi

    # Upgrade Horizon
    echo_summary "Running upgrade-horizon"
    $GRENADE_DIR/upgrade-horizon || die $LINENO "Failure in upgrade-horizon"
    stop $STOP upgrade-horizon 240

    # Upgrade Checks
    echo_summary "Running upgrade sanity check"
    $GRENADE_DIR/check-sanity || die $LINENO "Failure in check-sanity"
    stop $STOP check-sanity 310

    # Upgrade Tests
    # =============

    # Validate the upgrade
    echo_summary "Running target exercises"
    if [[ "$TARGET_RUN_EXERCISES" == "True" ]]; then
        $TARGET_DEVSTACK_DIR/exercise.sh
    fi
    stop $STOP target-exercise 320

    if [[ "$TARGET_RUN_SMOKE" == "True" ]]; then
        echo_summary "Running tempest smoke tests"
        $TARGET_RELEASE_DIR/tempest/run_tests.sh -N -s
        stop $STOP run-smoke 330
    fi

    # Save databases
    # --------------

    echo_summary "Sourcing target DevStack config"
    source $TARGET_DEVSTACK_DIR/stackrc
    echo_summary "Dumping target databases"
    mkdir -p $SAVE_DIR
    for db in keystone glance nova cinder; do
        mysqldump -uroot -p$MYSQL_PASSWORD $db >$SAVE_DIR/$db.sql.$TARGET_RELEASE
    done
fi


# Fin
# ===

echo_summary "Grenade has completed the pre-programmed upgrade scripts."
# Indicate how long this took to run (bash maintained variable ``SECONDS``)
echo_summary "grenade.sh completed in $SECONDS seconds."
