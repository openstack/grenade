Contributing to Grenade
=======================


General
-------

Grenade is written in POSIX shell script. It specifies BASH and is
compatible with Bash 3.

Grenade's official repository is located at
https://git.openstack.org/cgit/openstack-dev/grenade.


Scripts
-------

Grenade scripts should generally begin by calling ``env(1)`` in the shebang line::

    #!/usr/bin/env bash

The script needs to know the location of the Grenade install directory.
``GRENADE_DIR`` should always point there, even if the script itself is located in
a subdirectory::

    # Keep track of the current grenade directory.
    GRENADE_DIR=$(cd $(dirname "$0") && pwd)

Many scripts will utilize shared functions from the ``functions`` file.  This
file is copied directly from DevStack trunk periodically.  There is also an
rc file (``grenaderc``) that is sourced to set the default configuration of
the user environment::

    # Keep track of the current grenade directory.
    GRENADE_DIR=$(cd $(dirname "$0") && pwd)

    # Import common functions
    source $GRENADE_DIR/functions

    # Import configuration
    source $GRENADE_DIR/grenaderc


Documentation
-------------

The GitHub repo includes a gh-pages branch that contains the web documentation
for Grenade. This is the primary Grenade documentation along with the
Grenade scripts themselves.

All of the scripts are processed with shocco_ to render them with the comments
as text describing the script below.  For this reason we tend to be a little
verbose in the comments _ABOVE_ the code they pertain to.  Shocco also supports
Markdown formatting in the comments; use it sparingly.  Specifically, ``grenade.sh``
uses Markdown headers to divide the script into logical sections.

.. _shocco: http://rtomayko.github.com/shocco/
