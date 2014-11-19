Grenade
=======

Grenade is an OpenStack test harness to exercise the upgrade process
between releases.  It uses DevStack to perform an initial OpenStack
install and as a reference for the final configuration.  Currently
Grenade upgrades Keystone, Glance, Nova, Neutron, Cinder and Swift in
their default DevStack configurations.

The master branch tests the upgrade path from the previous release
(aka 'base') to the current trunk (aka 'target').  Stable branches
of Grenade will be created soon after an OpenStack release and after
a corresponding DevStack stable branch is available.

For example, following the release of Grizzly and the creation of
DevStack's stable/grizzly branch a similar stable/grizzly branch
of Grenade will be created.  At that time master will be re-worked
to base on Grizzly and the cycle will continue.


Goals
-----

Continually test the upgrade process between OpenStack releases to
find issues as they are introduced so they can be fixed immediately.


Status
------

Preparations are ongoing to add Grenade as a non-voting job in the
OpenStack CI Jenkins.

* Testing of the 'javelin' project artifacts is incomplete

Process
-------

* Install base OpenStack using current stable/<base-release> DevStack
* Perform basic testing (tempest's smoke and scenarios tests)
* Create some artifacts in a new project ('javelin') for comparison
  after the upgrade process.
* Install current target DevStack to support the upgrades
* Run upgrade scripts preserving (running?) instances and data


Terminology
-----------

Grenade has two DevStack installs present and distinguished between then
as 'base' and 'target'.

* **Base**: The initial install that will be upgraded.
* **Target**: The reference install of target OpenStack (maybe just DevStack)


Directory Structure
-------------------

Grenade creates a set of directories for both the base and target
OpenStack installation sources and DevStack.

$STACK_ROOT
 |- logs                # Grenade logs
 |- <base>
 |   |- data            # base data
 |   |- logs            # base DevStack logs
 |   |- devstack
 |   |- images          # cache of downloaded images
 |   |- cinder
 |   |- ...
 |   |- swift
 |- <target>
 |   |- data            # target data
 |   |- logs            # target DevStack logs
 |   |- devstack
 |   |- cinder
 |   |- ...
 |   |- swift

Dependencies
------------

This is a non-exhaustive list of dependencies:

* git
* tox<1.7

Install Grenade
---------------

Get Grenade from GitHub in the usual way::

    git clone git://git.openstack.org/openstack-dev/grenade

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
If ``$BASE_DEVSTACK_DIR/localrc`` does not exist the following is
performed by ``prep-base``:

* ``devstack.localrc.base`` is copied to to ``$BASE_DEVSTACK_DIR/localrc``
* if ``devstack.localrc`` exists it is appended ``$BASE_DEVSTACK_DIR/localrc``

Similar steps are performed by ``prep-target`` for ``$TARGET_DEVSTACK_DIR``.

``devstack.localrc`` will be appended to both DevStack ``localrc`` files if it
exists.  ``devstack.localrc`` is not included in Grenade and will not be
overwritten it if it exists.


Prepare For An Upgrade Test
---------------------------

::

    ./grenade.sh

``grenade.sh`` installs DevStack for the **Base** release and
runs its ``stack.sh``.  Then it creates a 'javelin' project containing
some non-default configuration.

This is roughly the equivalent to::

    grenade/prep-base
    (cd /opt/stack/grizzly/devstack
     ./stack.sh)
    grenade/setup-javelin
    (cd /opt/stack/grizzly/devstack
     ./unstack.sh)
    # dump databases to $STACK_ROOT/save
    grenade/prep-target
    grenade/upgrade-devstack
    grenade/upgrade-keystone
    grenade/upgrade-glance
    grenade/upgrade-nova
    grenade/upgrade-neutron
    grenade/upgrade-cinder
    grenade/upgrade-swift

The **Target** release of DevStack is installed in a different
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

These scripts are written to be idempotent.
