Grenade
=======

Grenade is an OpenStack test harness to exercise the upgrade process
between releases.  It uses DevStack to perform an initial OpenStack
install and as a reference for the final configuration.

While the initial incarnation of Grenade is written to upgrade
from Essex to Folsom it needs to be generalized for future releases.

# Goals

* Install base Essex OpenStack using stable/essex DevStack
* Perform basic testing (exercise.sh)
* Create some non-default configuration to use as a conversion reference
* Install base Folsom (trunk) DevStack to support the upgrades
* Run upgrade scripts preserving (running?) instances and data


# Terminology

Grenade has two DevStack installs present and distinguished between then
as 'work' and 'trunk'.

* **Work**: The initial install that is will be upgraded.
* **Trunk**: The reference install of trunk OpenStack (maybe just DevStack)


# Install Grenade

Grenade knows how to install a current release of itself using the included
``setup-grenade`` script.  The only argument is the hostname of the target
system that will run the upgrade testing.

    ./setup-grenade testbox

Grenade includes ``devstack.localrc.work`` for DevStack that is used to
customize its behaviour for use with Grenade.  By default ``setup-grenade``
will set HOST_IP and DEST when copying it to the Grenade DevStack direcotry.


# Prepare For An Upgrade

    ./grenade.sh

``grenade.sh`` installs DevStack for the **Work** release (Essex) and
runs its ``stack.sh``.  This is roughly the equivalent to:

    grenade/prep-work
    cd /opt/stack/devstack.essex
    ./stack.sh
    grenade/setup-javelin
    ./unstack.sh
    # dump databases to $DEST/save
    grenade/prep-trunk
    grenade/upgrade-packages
    grenade/upgrade-devstack
    grenade/upgrade-keystone
    grenade/upgrade-glance
    grenade/upgrade-nova
    grenade/upgrade-volume

The **Trunk** release (Folsom) of DevStack is installed in a different
directory from the **Work** release.

While the **Work** release is running an imaginary **Javelin** tenant
is configured to populate the databases with some non-default content::

    grenade/setup-javelin

Set up the **javelin** credentials with ``javelinrc``.


# Testing Upgrades

The ``upgrade-*`` scripts are the individual components of the
DevStack/Grenade upgrade process.  They typically stop any running
processes, checkout updated sources, migrate the database, any other
tasks that need to be done then start the processes in ``screen``.

These scripts are written to be idmpotent.
