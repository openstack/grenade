#!/bin/bash
#
# Copyright 2015 Hewlett-Packard Development Company, L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

set -o errexit

DEVSTACK_DIR=""

function usage {
    cat - <<EOF
Usage: run_resource.sh [-d devstackdir] <project> <phase>

Runs the resource test scripts for the project. This is done
automatically during grenade runs, however when developing new
resource scripts, it's extremely helpful to iterate with this tool.

This tool can also be used to build same resources with only a
devstack tree. In that case run this script from your devstack tree
with the -d option.

  ../grenade/run_resource.sh -d . nova create

EOF
    exit
}

# Process command-line args
while getopts hd: opt; do
    case $opt in
        h)
            usage
            ;;
        d)
            DEVSTACK_DIR=$OPTARG
            shift $((OPTIND-1))
            ;;
    esac
done

export GRENADE_DIR=${GRENADE_DIR:-$(cd $(dirname "$0") && pwd)}
TARGET_DEVSTACK_DIR=$DEVSTACK_DIR
source $GRENADE_DIR/grenaderc
export TOP_DIR=${DEVSTACK_DIR:-$BASE_DEVSTACK_DIR}


PROJECT=$1
PHASE=$2

# These are required elements
if [[ -z "$PROJECT" || -z "$PHASE" ]]; then
    usage
fi


FILE=$(ls -d $GRENADE_DIR/projects/*_$PROJECT/)

if [[ -e $FILE/resources.sh ]]; then
    set -o xtrace
    $FILE/resources.sh $PHASE
else
    echo "Couldn't find $PROJECT"
    exit
fi
