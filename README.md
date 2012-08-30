Grenade is an OpenStack upgrade test harness to exercise the
upgrade process from Essex to Folsom.  It uses DevStack to perform
the initial OpenStack install.

# Goals

* Install base Essex OpenStack using stable/essex devstack
* Perform basic testing (exercise.sh) and leave some instances running with data
* Run upgrade script preserving running instances and data
* Install base Folsom (trunk) OpenStack and compare to upgrade


# Install Grenade

Grenade knows how to install a current release of itself using the included
``setup-grenade`` script.  The only argument is the hostname of the target
system that will run the upgrade testing.

    ./setup-grenade testbox

Grenade includes ``devstack.start.localrc`` for DevStack that is used to
customize its behaviour for use with Grenade.  By default ``setup-grenade``
will set HOST_IP and DEST when copying it to the Grenade DevStack direcotry.


# Prepare For An Upgrade

    ./grenade.sh

``grenade.sh`` installs DevStack for both the **Start** release (Essex) and
the **Final** release (Folsom) in separate directories.  It then runs the
**Start** release ``stack.sh``.  This si roughly the equivalent to:

    ./prep-final
    ./prep-start
    cd /opt/stack.essex/devstack
    ./stack.sh

At this point the **Start** release is running.  Configure an
imaginary **Javelin** tenant to populate the databases with some
non-default content::

    ./setup-javelin

This should leave an instance named ``peltast`` running.

Now run ``unstack.sh`` to shut down the **Start** OpenStack and begin the
upgrade testing.

Set up the **javelin** credentials with ``javelinrc``.


# Testing Upgrades

The ``upgrade-*`` scripts are the individual components of the
DevStack/Grenade upgrade process.
