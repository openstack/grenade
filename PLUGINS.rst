==============================
 Modular Grenade Architecture
==============================

Grenade was originally created to demonstrate some level of upgrade
capacity for OpenStack projects. Originally this just included a small
number of services.

Proposed new basic flow:

- setup_grenade
  - all the magic setup involved around err traps and filehandle
    redirects
  - setup devstack trees
- setup_base
  - run stack.sh to build the correct base environment
- verify_base
  - for project in projects; do verify_project; done
- resources.sh create
- resources.sh verify
- shutdown
  - for project in projects; do shutdown; done
- snapshot.sh pre_upgrade (NOT YET IMPLEMENTED)
- resources.sh verify_noapi
- upgrade ...
- resources.sh verify
- verify_target
- resources.sh destroy



Modular Components
==================

Assuming the following tree in target projects::

  devstack/    - devstack plugin directory
     upgrade/   - upgrade scripts
         settings   - adds settings for the upgrade path
         upgrade.sh
         snapshot.sh - snapshots the state of the service, typically a
            database dump (NOT YET IMPLEMENTED)
         from-juno/ - per release
         within-juno/
         from-kilo/
         within-kilo/
         resources.sh


This same modular structure exists in the grenade tree with::
  grenade/
     projects/
        10_ceilometer/
           settings
           upgrade.sh

resources.sh
=================

resources.sh is a per-service resource create / verify / destroy
interface. What a service does inside a script is up to them.

You can assume your resource script will only be called if your
service is running in an upgrade environment. The script should return
zero on success for actions, and nonzero on failure.

Calling Interface
---------

The following is the supported calling interface

- resources.sh create

  creates a set of sample resources that should survive
  upgrade. Script should exit with a nonzero exit code if any
  resources could not be created.

  Example: create an instance in nova or a volume in cinder

- resources.sh verify

  verify that the resources were created. Services are running at this
  point, and the APIs may be expected to work.

  Example: use the nova command to verify that the test instance is
  still ACTIVE, or the cinder command to verify that the volume is
  still available.

- resources.sh verify_noapi

  verify that the resources are still present. This is called in the
  phase where services are stopped, and APIs are expected to not be
  accessible. Resource verification at this phase my require probing
  underlying components to make sure nothing has gone awry during
  service shutdown.

  Example: check with libvirt to make sure the instance is actually
  created and running. Bonus points for being able to ping the
  instance, or otherwise check its live-ness. With cinder, checking
  that the LVM volume exists and looks reasonable.

- resources.sh destroy

  Resource scripts should be responsible and cleanup all their
  resources when asked to destroy.

Calling Sequence
----------------

The calling sequence during a grenade run looks as follows:

- # start old side
- create (create will be called during the working old side)
- verify
- # shutdown all services
- verify_noapi
- # upgrade and start all services
- verify
- destroy

The important thing to remember is verify/verify_noapi will be called
multiple times, with multiple different versions of OpenStack. Those
phases of the script must not be rerunnable multiple times.

While create / destroy are only going to be called once in the current
interface, bonus points for also making those idempotent for
resiliancy in testing.

Supporting Methods
------------------

In order to assist with the checks listed the following functions
exist::

  resource_save project key value
  resource_get project key

This allow resource scripts to have memory, and keep track of things
like the allocated IP addresses, IDs, and other non deterministic data
that is returned from OpenStack API calls.

Environment
-----------

Resource scripts get called in a specific environment already set:

- TOP_DIR - will be set to the root of the devstack directory for the
  BASE version of devstack incase this is needed to find files like a
  working ``openrc``

- GRENADE_DIR - the root directory of the grenade directory.

The following snippet will give you access to both the grenade and
TARGET devstack functions::

  source $GRENADE_DIR/grenaderc
  source $GRENADE_DIR/functions


Best Practices
--------------

Do as many actions as non admin as possible. As early as you can in
your resource script it's worth allocating a user/project for the
script to run as. This ensures isolation against other scripts, and
ensures that actions don't only work because admin gets to bypass
safeties.

Test side effects, not just API actions. The point of these resource
survival scripts is to test that things created beyond the API / DB
interaction still work later. Just testing that data can be stored /
retrieved from the database isn't very interesting, and should be
covered other places. The value in the resource scripts is these side
effects. Actual VMs running, actual iscsi targets running, etc. And
ensuring these things are not disrupted when the control plane is
shifted out from under them.
