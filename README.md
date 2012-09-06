Grenade is an OpenStack upgrade test harness to exercise the
upgrade process between releases.  It uses DevStack to perform
the initial OpenStack install and as a reference for the final
configuration.

While the initial incarnation of Grenade is written to upgrade
from Essex to Folsom it needs to be generalized for future releases.

# Goals

* Install base Folsom (trunk) OpenStack for reference to upgrade
* Install base Essex OpenStack using stable/essex DevStack
* Perform basic testing (exercise.sh)
* Create some non-default configuration to use as a conversion reference
* Run upgrade script preserving (running?) instances and data


# Terminology

Grenade has two DevStack installs present and distinguished between then
as 'work' and 'trunk'.

* **work**: The initial install that is will be upgraded.
* **trunk**: The reference install of trunk OpenStack (maybe just DevStack)


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

``grenade.sh`` installs DevStack for both the **Work** release (Essex) and
the **Trunk** release (Folsom) in separate directories.  It then runs the
**Work** release ``stack.sh``.  This is roughly the equivalent to:

    ./prep-trunk
    ./prep-work
    cd /opt/stack.essex/devstack
    ./stack.sh

At this point the **Work** release is running.  Configure an
imaginary **Javelin** tenant to populate the databases with some
non-default content::

    ./setup-javelin

This should leave an instance named ``peltast`` running.

Now run ``unstack.sh`` to shut down the **Work** OpenStack and begin the
upgrade testing.

Set up the **javelin** credentials with ``javelinrc``.


# Testing Upgrades

The ``upgrade-*`` scripts are the individual components of the
DevStack/Grenade upgrade process.
