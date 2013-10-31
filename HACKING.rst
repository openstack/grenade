Contributing to Grenade
=======================


General
-------

Grenade is written in POSIX shell script. It specifies BASH and is
compatible with Bash 3.

Grenade's official repository is located on GitHub at
https://github.com/openstack-dev/grenade.git.


Scripts
-------

Grenade scripts should generally begin by calling ``env(1)`` in the shebang line::

    #!/usr/bin/env bash

The script needs to know the location of the Grenade install directory.
``GRENADE_DIR`` should always point there, even if the script itself is located in
a subdirectory::

    # Keep track of the current devstack directory.
    GRENADE_DIR=$(cd $(dirname "$0") && pwd)

Many scripts will utilize shared functions from the ``functions`` file.  This
file is copied directly from DevStack trunk periodically.  There is also an
rc file (``grenaderc``) that is sourced to set the default configuration of
the user environment::

    # Keep track of the current devstack directory.
    GRENADE_DIR=$(cd $(dirname "$0") && pwd)

    # Import common functions
    source $GRENADE_DIR/functions

    # Import configuration
    source $GRENADE_DIR/grenaderc


Documentation
-------------

The GitHub repo includes a gh-pages branch that contains the web documentation
for Grenade. This is the primary Grenade documentation along with the
Grenade scripts themselves.

All of the scripts are processed with shocco_ to render them with the comments
as text describing the script below.  For this reason we tend to be a little
verbose in the comments _ABOVE_ the code they pertain to.  Shocco also supports
Markdown formatting in the comments; use it sparingly.  Specifically, ``grenade.sh``
uses Markdown headers to divide the script into logical sections.

.. _shocco: http://rtomayko.github.com/shocco/


Exercises
---------

The scripts in the exercises directory are meant to 1) perform additional
operational checks on certain aspects of OpenStack; and b) set up some instances
and data that can be used to verify the upgrade process is non-destructive
for the end-user.

* Begin and end with a banner that stands out in a sea of script logs to aid
  in debugging failures, particularly in automated testing situations.  If the
  end banner is not displayed, the script ended prematurely and can be assumed
  to have failed.

  ::

    echo "**************************************************"
    echo "Begin Grenade Exercise: $0"
    echo "**************************************************"
    ...
    set +o xtrace
    echo "**************************************************"
    echo "End Grenade Exercise: $0"
    echo "**************************************************"

* The scripts will generally have the shell ``xtrace`` attribute set to display
  the actual commands being executed, and the ``errexit`` attribute set to exit
  the script on non-zero exit codes::

    # This script exits on an error so that errors don't compound and you see
    # only the first error that occured.
    set -o errexit

    # Print the commands being run so that we can see the command that triggers
    # an error.  It is also useful for following allowing as the install occurs.
    set -o xtrace

* Settings and configuration are stored in ``exerciserc``, which must be
  sourced after ``grenaderc``::

    # Import exercise configuration
    source $TOP_DIR/exerciserc

* There are a couple of helper functions in the common ``functions`` sub-script
  that will check for non-zero exit codes and unset environment variables and
  print a message and exit the script.  These should be called after most client
  commands that are not otherwise checked to short-circuit long timeouts
  (instance boot failure, for example)::

    swift post $CONTAINER
    if [[ $? != 0 ]]; then
        die $LINENO "Failure creating container $CONTAINER"
    fi

    FLOATING_IP=`euca-allocate-address | cut -f2`
    die_if_not_set $LINENO FLOATING_IP "Failure allocating floating IP"

* If you want an exercise to be skipped when for example a service wasn't
  enabled for the exercise to be run, you can exit your exercise with the
  special exitcode 55 and it will be detected as skipped.

* The exercise scripts should only use the various OpenStack client binaries to
  interact with OpenStack.  This specifically excludes any ``*-manage`` tools
  as those assume direct access to configuration and databases, as well as direct
  database access from the exercise itself.

* The exercise MUST clean up after itself even if it is not successful.  This is
  different from current DevStack practice.  The exercise SHOULD also clean up
  or graciously handle possible artifacts left over from previous runs if executed
  again.
