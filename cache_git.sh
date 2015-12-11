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

GIT_DIR=/opt/git

PROJECTS=""
PROJECTS+="openstack/requirements "
PROJECTS+="openstack/keystone "
PROJECTS+="openstack/nova "
PROJECTS+="openstack/glance "
PROJECTS+="openstack/cinder "
PROJECTS+="openstack/keystone "
PROJECTS+="openstack/swift "
PROJECTS+="openstack/tempest "
PROJECTS+="openstack/neutron "
PROJECTS+="openstack/ceilometer "
PROJECTS+="openstack/horizon "
PROJECTS+="openstack-dev/devstack "
PROJECTS+="kanaka/noVNC "

function usage {
    cat - <<EOF
Usage: cache_git.sh [-d dir]

Builds a local git cache of OpenStack projects for use with grenade
testing. After running this set GIT_BASE in localrc to the value of
DIRECTORY.

 -d DIRECTORY: defaults to /opt/git

EOF
    exit
}

# Process command-line args
while getopts hd: opt; do
    case $opt in
        d)
            GIT_DIR=$OPTARG
            ;;
        h)
            usage
            ;;
    esac
done

for dir in $@; do
    PROJECTS+="$dir "
done

function git_update_mirror {
    local project=$1
    local dir=$GIT_DIR/$project.git
    if [[ ! -d $(dirname $dir) ]]; then
        echo "Creating $(dirname $dir)"
        sudo mkdir -p $(dirname $dir)
        sudo chown -R `whoami` $(dirname $dir)
    fi
    if [[ ! -d $dir ]]; then
        echo "Creating initial git mirror for $project"
        git clone --mirror https://github.com/$project $dir
    else
        echo "Updating git mirror for $project"
        git --git-dir ${dir} fetch 2>/dev/null
        echo "    head is now: $(git --git-dir ${dir} log --oneline -1)"
    fi
}

for project in $PROJECTS; do
    git_update_mirror $project
done
