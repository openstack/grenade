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

function echo_summary {
    echo $@ >&6
}

function echo_nolog {
    echo $@ >&3
}

function stop {
    stop=$1
    shift
    if [[ "$@" =~ "$stop" ]]; then
        echo "STOP called for $1"
        exit 1
    fi
}

function upgrade_service {
    local local_service=$1
    # figure out if the service should be upgraded
    echo "Checking for $local_service is enabled"
    local enabled=""
    # TODO(sdague) terrible work around because of missing
    # devstack functions
    if [[ $local_service == 'keystone' ]]; then
        enabled="True"
    else
        enabled=$(
            source $TARGET_DEVSTACK_DIR/functions;
            source $TARGET_DEVSTACK_DIR/stackrc;
            is_service_enabled $local_service || echo "False")
    fi
    if [[ "$enabled" == "False" ]]; then
        echo_summary "Not upgrading $local_service"
        return
    fi
    echo_summary "Upgrading $local_service..."
    $GRENADE_DIR/upgrade-$local_service || die $LINENO "Failure in upgrade-$local_service"
}

# Ensure that we can run this on a fresh system
sudo mkdir -p $(dirname $BASE_DEVSTACK_DIR)
sudo mkdir -p $(dirname $TARGET_DEVSTACK_DIR)
sudo chown -R `whoami` $(dirname $(dirname $BASE_DEVSTACK_DIR))

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

    sudo mkdir -p $LOGDIR
    find $LOGDIR -maxdepth 1 -name $LOGNAME.\* -mtime +$LOGDAYS -exec rm {} \;
    LOGFILE=$LOGFILE.${CURRENT_LOG_TIME}
    SUMFILE=$LOGFILE.${CURRENT_LOG_TIME}.summary

    # Redirect output according to config
    # Copy stdout to fd 3
    exec 3>&1
    if [[ "$VERBOSE" == "True" ]]; then
        echo "Running in verbose mode:"
        echo "  Full logs found at => ${LOGFILE}"
        echo "  Summary logs at => ${SUMFILE}"
        # Redirect stdout/stderr to tee to write the log file
        exec 1> >( ./tools/outfilter.py -v -o "${LOGFILE}" ) 2>&1
        # Set up a second fd for output
        exec 6> >( ./tools/outfilter.py -o "${SUMFILE}" )
    else
        echo "Running in summary mode:"
        echo "  Full logs found at => ${LOGFILE}"
        echo "  Summary logs at => ${SUMFILE}"
        # Set fd 1 and 2 to primary logfile
        exec 1> >( ./tools/outfilter.py -o "${LOGFILE}") 2>&1
        # Set fd 6 to summary logfile and stdout
        exec 6> >( ./tools/outfilter.py -v -o "${SUMFILE}" >&3)
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
    exec 6> >( ./tools/outfilter.py -v -o "${SUMFILE}" >&3)
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
        sudo mkdir -p $SCREEN_LOGDIR
    fi
fi

# Setup Exit Traps for debug purposes
trap exit_trap EXIT
function exit_trap {
    # really important that this is the *first* line in this
    # function, otherwise we corrupt the exit code
    local r=$?
    # we don't need tracing during this
    set +o xtrace
    if [[ $r -ne 0 ]]; then
        echo "Exit code: $r"
        $TARGET_DEVSTACK_DIR/tools/worlddump.py -d $LOGDIR
        sleep 1
    fi
    exit $r
}

# This script exits on an error so that errors don't compound and you see
# only the first error that occurred.
set -o errexit

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace


# More Setup
# ==========

# Set up for smoke tests (default to True)
RUN_SMOKE=${RUN_SMOKE:=True}
BASE_RUN_SMOKE=${BASE_RUN_SMOKE:-$RUN_SMOKE}
TARGET_RUN_SMOKE=${TARGET_RUN_SMOKE:-$RUN_SMOKE}

# Install 'Base' Build of OpenStack
# =================================

if [[ "$RUN_BASE" == "True" ]]; then
    echo_summary "Running prep-base"
    $GRENADE_DIR/prep-base
    stop $STOP prep-base 01

    echo_summary "Running base stack.sh"
    cd $BASE_DEVSTACK_DIR
    GIT_BASE=$GIT_BASE ./stack.sh
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
    echo_summary "Running base smoke test"
    if [[ "$BASE_RUN_SMOKE" == "True" ]]; then
        cd $BASE_RELEASE_DIR/tempest
        tox -esmoke -- --concurrency=$TEMPEST_CONCURRENCY
    fi
    stop $STOP base-smoke 110

    cd $GRENADE_DIR

    # initialize javalin config
    TEMPEST_DIR=$BASE_RELEASE_DIR/tempest
    TEMPEST_CONF=$TEMPEST_DIR/etc/tempest.conf
    JAVELIN_CONF=$TEMPEST_DIR/etc/javelin.conf
    cp $TEMPEST_CONF $JAVELIN_CONF
    # Make javelin write logs to stderr
    iniset $JAVELIN_CONF DEFAULT use_stderr True

    # Create a project, users and instances
    echo_summary "Creating Javelin project"
    (source $BASE_DEVSTACK_DIR/openrc admin admin;
        javelin2 -m create -r $GRENADE_DIR/resources.yaml -d $BASE_DEVSTACK_DIR -c $JAVELIN_CONF)

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
    upgrade_service keystone
    stop $STOP upgrade-keystone 240

    # Upgrade Swift
    upgrade_service swift
    stop $STOP upgrade-swift 245

    # Upgrade Glance
    upgrade_service glance
    stop $STOP upgrade-glance 250

    # Upgrade Neutron
    upgrade_service neutron
    stop $STOP upgrade-neutron 255

    # Upgrade Nova
    upgrade_service nova
    stop $STOP upgrade-nova 260

    # Upgrade Cinder
    upgrade_service cinder
    stop $STOP upgrade-cinder 270

    # Upgrade Ceilometer
    upgrade_service ceilometer
    stop $STOP upgrade-ceilometer 280

    # Upgrade Horizon
    upgrade_service horizon
    stop $STOP upgrade-horizon 285

    # Upgrade Tempest
    if [[ "$ENABLE_TEMPEST" == "True" ]]; then
        echo_summary "Running upgrade-tempest"
        $GRENADE_DIR/upgrade-tempest || die $LINENO "Failure in upgrade-tempest"
        stop $STOP upgrade-tempest 290
    fi

    # Upgrade Checks
    echo_summary "Running upgrade sanity check"
    $GRENADE_DIR/check-sanity || die $LINENO "Failure in check-sanity"
    stop $STOP check-sanity 310

    # Upgrade Tests
    # =============

    # Validate the created resources
    cd $GRENADE_DIR
    echo_summary "Validating Javelin resources"
    (source $BASE_DEVSTACK_DIR/openrc admin admin;
        javelin2 -m check -r $GRENADE_DIR/resources.yaml -d $BASE_DEVSTACK_DIR -c $JAVELIN_CONF)

    # Validate the upgrade
    if [[ "$TARGET_RUN_SMOKE" == "True" ]]; then
        echo_summary "Running tempest scenario and smoke tests"
        cd $TARGET_RELEASE_DIR/tempest
        tox -esmoke -- --concurrency=$TEMPEST_CONCURRENCY
        stop $STOP run-smoke 330
    fi

    # Save databases
    # --------------

    echo_summary "Sourcing target DevStack config"
    source $TARGET_DEVSTACK_DIR/functions
    source $TARGET_DEVSTACK_DIR/stackrc
    echo_summary "Dumping target databases"
    mkdir -p $SAVE_DIR
    MYSQL_SERVICES="keystone glance nova cinder"
    if grep -q 'connection *= *mysql' /etc/ceilometer/ceilometer.conf; then
        MYSQL_SERVICES+=" ceilometer"
    elif grep -q 'connection *= *mongo' /etc/ceilometer/ceilometer.conf; then
        mongodump --db ceilometer --out $SAVE_DIR/ceilometer-dump.$TARGET_RELEASE
    fi
    for db in $MYSQL_SERVICES ; do
        mysqldump -uroot -p$MYSQL_PASSWORD $db >$SAVE_DIR/$db.sql.$TARGET_RELEASE
    done
    neutron_db_names=$(mysql -uroot -p$MYSQL_PASSWORD -e "show databases;" | grep neutron || :)
    for neutron_db in $neutron_db_names; do
        mysqldump -uroot -p$MYSQL_PASSWORD $neutron_db >$SAVE_DIR/$neutron_db.sql.$TARGET_RELEASE
    done
fi


# Fin
# ===

echo_summary "Grenade has completed the pre-programmed upgrade scripts."
# Indicate how long this took to run (bash maintained variable ``SECONDS``)
echo_summary "grenade.sh completed in $SECONDS seconds."
