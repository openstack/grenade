==============================
 Modular Grenade Architecture
==============================

Grenade was originally created to demonstrate some level of upgrade
capacity for OpenStack projects. Orginally this just included a small
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
- resources-create
- shutdown
  - for project in projects; do shutdown; done
- snapshot.sh pre_upgrade
- resources-survive-shutdown
- upgrade ...
- resources-survive-upgrade
- verify_target
- resources_cleanup



Modular Components
==================

Assuming the following tree in target projects::

  devstack/    - devstack plugin directory
     upgrade/   - upgrade scripts
         settings   - adds settings for the upgrade path
         upgrade.sh
         snapshot.sh - snapshots the state of the service, typically a
            database dump
         from-juno/ - per release
         within-juno/
         from-kilo/
         within-kilo/
         resources.sh
         verify.sh


This same modular structure exists in the grenade tree with::
  grenade/
     projects/
        10_ceilometer/
           settings
           upgrade.sh

resources.sh
=================

This is a script that's designed to be called in the following ways:

- resources.sh create

  creates a set of sample resources that should survice
  upgrade. Script should exit with a non zero exit code if any
  resources could not be created.

- resources.sh survived_shutdown

  resource survival checks for after all services are shut down (the
  in between phase for upgrades). Script should exit with a non zero
  exit code if any resources were detected as offline.

- resources.sh survived_upgrade

  resource survival checks for after all services are started on the
  new code revisions. Script should exit with a non zero exit code if
  any resources no longer exist after the upgrade.

- resources.sh cleanup

  cleanup all resources


In order to assist with the checks listed the following functions
exist::

  resource_data_add project key value
  resource_data_get project key
