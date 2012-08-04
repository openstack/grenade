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
will set HOST_IP and DEST when copying it ti the Grenade DevStack direcotry.


# Start An Upgrade Test

    ./grenade.sh
