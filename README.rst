=========
 Grenade
=========

Grenade is an OpenStack test harness to exercise the upgrade process
between releases. It uses DevStack to perform an initial OpenStack
install and as a reference for the final configuration. Currently
Grenade can upgrade Keystone, Glance, Nova, Neutron, Cinder, Swift,
and Ceilometer in their default DevStack configurations.

Goals
=====

Grenade has the following goals:

- Block unintentional project changes that would break the `Theory of
  Upgrade`_. Most Grenade fails that people hit are of this nature.
- Ensure that upgrading a cloud doesn't do something dumb like delete
  and recreate all your servers/volumes/networks.
- Be able to grow to support additional upgrade scenarios (like
  sideways migrations from one configuration to another equivalent
  configuration)

.. _Theory of Upgrade:

Theory of Upgrade
=================

Grenade works under the following theory of upgrade.

- New code should work with old configs

The upgrade process should not require a config change to run a new
release. All config behavior is supposed to be deprecated over a
release cycle, so that upon release new code works with the last
releases configs. Those configs may create deprecation warnings which
need to be addressed before the next release, but they should still
work and largely have the same behavior.

- New code should need nothing more than 'db migrations'

Clearly the release of new code may include new database
models. Standard upgrade procedure is to turn off all services that
touch the database, run the db migration script, and start with new
code.

- Resources created by services before upgrade, should still be there
  after the system is upgraded

When upgrading Nova you expect all your VMs to still function during
the entire upgrade (whether or not Nova services are up). Taking down
the control plane should not take down your VMs.

- Any other required changes on upgrade are an *exception* and must be
  called out in the release notes.

Grenade supports per release specific upgrade scripts (from-juno,
from-kilo). These are designed to support upgrades where additional
manual steps are needed for a specific upgrade (i.e. from juno to
kilo). These should be used sparingly.

The Grenade core team requires the following before landing these
kinds of changes:

- The Release Notes for the release where this will be required
  clearly specify these manual upgrade steps.

- The PTL for the project in question has signed off on this change.

Status
======

Grenade is now running on every patch for projects that support
upgrade. Gating Grenade configurations exist for the following in
OpenStack's CI system.

- A cloud with nova-network upgraded between releases
- A cloud with neutron upgraded between releases
- A cloud with nova-network that upgrades all services except
  nova-compute, thus testing RPC backwards compatibility for rolling
  upgrades.

Basic Flow
==========

The grenade.sh script attempts to be reasonably readable, so it's
worth looking there to see what's really going on. This is the super
high level version of what that does.

- get 2 devstacks (base & target)
- install base devstack
- perform some sanity checking (currently tempest smoke) to ensure
  this is right
- allow projects to create resources that should survive upgrade
  - see projects/\*/resources.sh
- shut down all services
- verify resources are still working during shutdown
- upgrade and restart all services
- verify resources are still working after upgrade
- perform some sanity checking (currently tempest smoke) to ensure
  everything seems good.


Terminology
-----------

Grenade has two DevStack installs present and distinguished between then
as 'base' and 'target'.

* **Base**: The initial install that will be upgraded.
* **Target**: The reference install of target OpenStack (maybe just DevStack)


Directory Structure
===================

Grenade creates a set of directories for both the base and target
OpenStack installation sources and DevStack::

    $STACK_ROOT
     |- logs                # Grenade logs
     |- save                # Grenade state logs
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
============

This is a non-exhaustive list of dependencies:

* git
* tox

Install Grenade
===============

Get Grenade from GitHub in the usual way::

    git clone git://git.openstack.org/openstack-dev/grenade

Optional: running grenade against a remote target
-------------------------------------------------

There is an *optional* setup-grenade script that is useful if you are
running Grenade against a remote VM from a local laptop.

Grenade knows how to install the current master branch using the included
``setup-grenade`` script.  The arguments are the hostname of the target
system that will run the upgrade testing and the user for the target
system:

::

    ./setup-grenade [testbox [testuser]]

If you are running Grenade on the same maching you cloned to, you **do
not** need to do this.

Configuration
-------------

The Grenade repo and branch used can be changed by adding something like
this to ``localrc``::

  GRENADE_REPO=git@github.com:dtroyer/grenade.git
  GRENADE_BRANCH=dt-test

If you need to configure your local devstacks for your specific
environment you can do that by creating ``devstack.localrc``. This
will get appended to the stub devstack configs for BASE and TARGET.

For instance, specifying interfaces for Nova is a common use of
``devstack.localrc``::

  FLAT_INTERFACE=eth1
  VLAN_INTERFACE=eth1


Run the Upgrade Testing
-----------------------

::

    ./grenade.sh

Read ``grenade.sh`` for more details of the steps that happen from
here.
