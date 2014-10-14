===========================================
 Kilo to Kilo specific sideways upgrade scripts
===========================================
This directory can house service scripts for upgrading within the Kilo
release.

To do this add ``upgrade-$servicename`` script to this directory and
include a ``configure_$servicename_upgrade`` function in the file. All
services that don't have a specific upgrade script will just use the
generic one, which performs a db-sync and installs the updated code.
