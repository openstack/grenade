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

Development has begun for the Folsom -> Grizzly upgrade.

Goals
-----

* Install base OpenStack using current stable/XXXX DevStack
* Perform basic testing (exercise.sh)
* Create some non-default configuration to use as a conversion reference
* Install current trunk DevStack to support the upgrades
* Run upgrade scripts preserving (running?) instances and data


Terminology
-----------

Grenade has two DevStack installs present and distinguished between then
as 'work' and 'trunk'.

* **Work**: The initial install that is will be upgraded.
* **Trunk**: The reference install of trunk OpenStack (maybe just DevStack)


Install Grenade
---------------

Grenade knows how to install a current release of itself using the included
``setup-grenade`` script.  The only argument is the hostname of the target
system that will run the upgrade testing.

::

    ./setup-grenade testbox

Grenade includes ``devstack.localrc.work`` and ``devstack.localrc.trunk``
for DevStack that is used to customize its behaviour for use with Grenade.
If ``$DEST/devstack.essex/localrc`` does not exist the following is
performed by ``prep-work``:

* ``devstack.localrc.work`` is copied to to ``$DEST/devstack.folsom/localrc``
* if ``devstack.localrc`` exists it is appended ``$DEST/devstack.folsom/localrc``

Similar steps are performed by ``prep-trunk`` for ``devstack.grizzly``.

``devstack.localrc`` is not included in Grenade and will not be overwritten
it if it exists.


Prepare For An Upgrade Test
---------------------------

::

    ./grenade.sh

``grenade.sh`` installs DevStack for the **Work** release (Folsom) and
runs its ``stack.sh``.  Then it creates a 'javelin' project containing
some non-default configuration.

This is roughly the equivalent to::

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

The **Trunk** release (Grizzly) of DevStack is installed in a different
directory from the **Work** release.

While the **Work** release is running an imaginary **Javelin** tenant
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
