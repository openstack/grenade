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



# ``GRENADE_DIR`` is set once by the top level grenade.sh and exported
# so that all subsequent scripts can find their way back to the
# grenade root directory. No other scripts should set this variable
export GRENADE_DIR=$(cd $(dirname "$0") && pwd)

# Source the bootstrapping facilities
#
# Grenade attempts to reuse as much content from devstack on the
# target side as possible, but we need enough of our own code to get
# there.
#
# ``grenaderc`` is a set of X=Y declarations that don't need *any* of
# the devstack functions to work
#
# ``inc/bootstrap`` is the most minimal amount of functions that
# grenade needs to get going. This includes things like echo
# functions, trueorfalse, and the functions related to git cloning, so
# that we can get our devstack trees.
source $GRENADE_DIR/grenaderc
source $GRENADE_DIR/inc/bootstrap

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


# Create all the base directory structures needed for the rest of the
# environment to run.
#
# This will give you an STACK_ROOT tree that you expect, and that your
# normal user owns for follow on activities.
sudo mkdir -p $BASE_RELEASE_DIR $TARGET_RELEASE_DIR
sudo chown -R `whoami` $STACK_ROOT

# Logging
# =======

# TODO(sdague): should this extract into ``inc/bootstrap``?
#
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
    sudo chown -R `whoami` $LOGDIR
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
# directory specified in ``SCREEN_LOGDIR``, we will log to the file
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
        sudo chown -R `whoami` $SCREEN_LOGDIR
    fi
fi


# This script exits on an error so that errors don't compound and you see
# only the first error that occurred.
set -o errexit

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace


# Devstack Phase 2 initialization
# ===============================
#
# We now have enough infrastructure in grenade.sh to go and get *both*
# SOURCE and TARGET devstack trees. After which point we 'pivot' onto
# the TARGET devstack functions file, then source the rest of the
# grenade settings. This should let us run the bulk of grenade.

# Get both devstack trees, so that BASE_DEVSTACK_DIR, and
# TARGET_DEVSTACK_DIR are now fully populated.
fetch_devstacks

# Source the rest of the Grenade functions. For convenience
# ``$GRENADE_DIR/functions`` implicitly sources
# ``$TARGET_DEVSTACK_DIR/functions``. So this line can't happen until
# we have the devstacks pulled down.
source $GRENADE_DIR/functions

# We now have the 'short_source' function available, so setup our PS4 variable
export PS4='+ $(short_source):   '

# Many calls inside of devstack functions reference $TOP_DIR, which is
# the root of devstack. We export $TOP_DIR to all child processes here
# to be the TARGET_DEVSTACK_DIR.
#
# If you want a script to use functions off of BASE_DEVSTACK_DIR (like
# the shutdown phase) you *must* explicitly reset TOP_DIR in those
# scripts.
export TOP_DIR=$TARGET_DEVSTACK_DIR

# Install 'Base' Build of OpenStack
# =================================

# Collect the ENABLED_SERVICES from the base directory, this is what
# we are starting with.
ENABLED_SERVICES=$(set +o xtrace &&
                   source $BASE_DEVSTACK_DIR/stackrc &&
                   echo $ENABLED_SERVICES)

# Fetch all the grenade plugins which were registered in ``pluginrc``
# via the ``enable_grenade_plugin`` stanza. This must be done before
# settings are loaded, but has to be this late to give access to all
# the devstack functions.
fetch_grenade_plugins

# Load the ``settings`` files for all the in tree ``projects/``. This
# registers all the projects in order that we're going to be upgrading
# when the time is right.
load_settings

# Run the base install of the environment
if [[ "$RUN_BASE" == "True" ]]; then

    # Initialize grenade_db local storage, used for resource tracking
    init_grenade_db

    echo_summary "Running base stack.sh"
    cd $BASE_DEVSTACK_DIR
    GIT_BASE=$GIT_BASE ./stack.sh
    stop $STOP stack.sh 10

    echo_summary "Running post-stack.sh"
    if [[ -e $GRENADE_DIR/post-stack.sh ]]; then
        cd $GRENADE_DIR
        ./post-stack.sh
        stop $STOP post-stack.sh 15
        echo_summary "Completed post-stack.sh"
    fi

    # Cache downloaded instances
    # --------------------------

    echo_summary "Caching downloaded images"
    mkdir -p $BASE_RELEASE_DIR/images
    echo "Images: $IMAGE_URLS"
    for image_url in ${IMAGE_URLS//,/ }; do
        IMAGE_FNAME=`basename "$image_url"`
        if [[ -r $BASE_DEVSTACK_DIR/files/$IMAGE_FNAME ]]; then
            rsync -a $BASE_DEVSTACK_DIR/files/$IMAGE_FNAME $BASE_RELEASE_DIR/images
        fi
    done
    # NOTE(sileht): If glance is not enabled the directory cannot exists.
    if [[ -d $BASE_DEVSTACK_DIR/files/images ]] ; then
        rsync -a $BASE_DEVSTACK_DIR/files/images/ $BASE_RELEASE_DIR/images
    fi
    stop $STOP image-cache 20

    # Operation
    # ---------

    # Validate the install
    if [[ "$BASE_RUN_SMOKE" == "True" ]]; then
        echo_summary "Running base smoke test"
        cd $BASE_RELEASE_DIR/tempest
        tox -esmoke -- --concurrency=$TEMPEST_CONCURRENCY
        # once we are done, copy our created artifacts to the target
        if [[ -e $TARGET_RELEASE_DIR/tempest ]]; then
            for file in .tox .testrepository; do
                rsync -a $BASE_RELEASE_DIR/tempest/$file/ $TARGET_RELEASE_DIR/tempest/$file/
            done
        fi
    fi
    stop $STOP base-smoke 110

    # Early Create resources, used largely for network setup
    resources early_create

    # Create resources
    resources create

    # Verify the resources were created
    resources verify pre-upgrade

    # Save some stuff before we shut that whole thing down
    echo_summary "Saving current state information"
    $GRENADE_DIR/save-state
    stop $STOP save-state 130

    # Shut down running code
    echo_summary "Shutting down all services on base devstack..."
    shutdown_services

    # Verify the resources still exist after the shutdown
    resources verify_noapi pre-upgrade
fi


# Upgrades
# ========

if [[ "$RUN_TARGET" == "True" ]]; then
    # Clone all devstack plugins on the new side, because we're not
    # running a full stack.sh
    fetch_plugins

    # Get target devstack tree ready for services to be run from it,
    # including trying to reuse any existing files we pulled during
    # the base run.
    echo_summary "Preparing the target devstack environment"
    $GRENADE_DIR/prep-target

    # upgrade all the projects in order
    echo "Upgrade projects: $UPGRADE_PROJECTS"
    for project in $UPGRADE_PROJECTS; do
        echo "Upgrading project: $project"
        upgrade_service $project
    done

    # Upgrade Tempest
    if [[ "$ENABLE_TEMPEST" == "True" ]]; then
        echo_summary "Running upgrade-tempest"
        $GRENADE_DIR/upgrade-tempest || die $LINENO "Failure in upgrade-tempest"
        stop $STOP upgrade-tempest 290
    fi

    # Upgrade Tests
    # =============

    # Verify the resources still exist after the upgrade
    resources verify post-upgrade

    # Validate the upgrade
    # This is used for testing grenade locally, and should not be used in the
    # gate. Instead, grenade.sh runs smoke tests on the old cloud above, but
    # smoke tests are run on the upgraded cloud by the gate script after
    # grenade.sh has finished. If this option is enabled in the gate, tempest
    # will be run twice against the new cloud.
    if [[ "$TARGET_RUN_SMOKE" == "True" ]]; then
        echo_summary "Running tempest smoke tests"
        cd $TARGET_RELEASE_DIR/tempest
        tox -esmoke -- --concurrency=$TEMPEST_CONCURRENCY
        stop $STOP run-smoke 330
    fi

    # Save databases
    # --------------
    save_data $TARGET_RELEASE $TARGET_DEVSTACK_DIR

    # Cleanup the resources
    resources destroy

fi


# Fin
# ===

echo_summary "Grenade has completed the pre-programmed upgrade scripts."
# Indicate how long this took to run (bash maintained variable ``SECONDS``)
echo_summary "grenade.sh completed in $SECONDS seconds."
