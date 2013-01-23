Grenade
=======

Grenade is an OpenStack test harness to exercise the upgrade process
between releases.  It uses DevStack to perform an initial OpenStack
install and as a reference for the final configuration.

This branch tests the upgrade path from Folsom to Grizzly development 
for Keystone, Glance, Nova and Cinder.

If you are looking for the Essex -> Folsom upgrade check out the 
``stable/folsom`` branch.

Status
------

Development has begun for the Folsom (base-release) -> Grizzly (target-release) upgrade.

Goals
-----

* Install base OpenStack using current stable/<base-release> DevStack
* Perform basic testing (exercise.sh)
* Create some non-default configuration to use as a conversion reference
* Install current target DevStack to support the upgrades
* Run upgrade scripts preserving (running?) instances and data


Terminology
-----------

Grenade has two DevStack installs present and distinguished between then
as 'base' and 'target'.

* **Base**: The initial install that is will be upgraded.
* **Target**: The reference install of target OpenStack (maybe just DevStack)


Directory Structure
-------------------

Grenade creates a set of directories for both the base and target
OpenStack installation sources and DevStack.

$DEST
 |- data
 |- logs                # Grenade logs
 |- <base>
 |   |- logs            # base DevStack logs
 |   |- devstack
 |   |- cinder
 |   |- ...
 |   |- swift
 |- <target>
 |   |- logs            # target DevStack logs
 |   |- devstack
 |   |- cinder
 |   |- ...
 |   |- swift


Install Grenade
---------------

Get Grenade from GitHub in the usual way::

    git clone https://github.com/nebula/grenade.git

Grenade knows how to install the current master branch using the included
``setup-grenade`` script.  The only argument is the hostname of the target
system that will run the upgrade testing.

::

    ./setup-grenade testbox

The Grenade repo and branch used can be changed by adding something like
this to ``localrc``::

    GRENADE_REPO=git@github.com:dtroyer/grenade.git
    GRENADE_BRANCH=dt-test

Grenade includes ``devstack.localrc.base`` and ``devstack.localrc.target``
for DevStack that are used to customize its behaviour for use with Grenade.
If ``$DEST/devstack.$BASE_RELEASE/localrc`` does not exist the following is
performed by ``prep-base``:

* ``devstack.localrc.base`` is copied to to ``$DEST/devstack.folsom/localrc``
* if ``devstack.localrc`` exists it is appended ``$DEST/devstack.folsom/localrc``

Similar steps are performed by ``prep-target`` for ``devstack.grizzly``.

``devstack.localrc`` will be appended to both DevStack ``localrc`` files if it
exists.  ``devstack.localrc`` is not included in Grenade and will not be
overwritten it if it exists.

To handle differences between the DevStack releases ``GRENADE_PHASE`` will
be set to ``base`` or ``target`` so appropriate decisions can be made::

    if [[ "$GRENADE_PHASE" == "base" ]]; then
        # Handle base-specific local
        :
    else
        # Handle target-specific local
        :
    fi


Prepare For An Upgrade Test
---------------------------

::

    ./grenade.sh

``grenade.sh`` installs DevStack for the **Base** release (Folsom) and
runs its ``stack.sh``.  Then it creates a 'javelin' project containing
some non-default configuration.

This is roughly the equivalent to::

    grenade/prep-base
    cd /opt/stack/devstack.essex
    ./stack.sh
    grenade/setup-javelin
    ./unstack.sh
    # dump databases to $DEST/save
    grenade/prep-target
    grenade/upgrade-packages
    grenade/upgrade-devstack
    grenade/upgrade-keystone
    grenade/upgrade-glance
    grenade/upgrade-nova
    grenade/upgrade-volume

The **Target** release (Grizzly) of DevStack is installed in a different
directory from the **Base** release.

While the **Base** release is running an imaginary **Javelin** tenant
is configured to populate the databases with some non-default content::

    grenade/setup-javelin

Set up the **javelin** credentials with ``javelinrc``.


Testing Upgrades
----------------

The ``upgrade-*`` scripts are the individual components of the
DevStack/Grenade upgrade process.  They typically stop any running
processes, checkout updated sources, migrate the database, any other
tasks that need to be done then start the processes in ``screen``.

These scripts are written to be idmpotent.
