#! /usr/bin/env python

# Copyright 2016 Hewlett Packard Enterprise Development Company, L.P.
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

# This script is intended to be run as part of a periodic proposal bot
# job in OpenStack infrastructure.
#
# In order to function correctly, the environment in which the
# script runs must have
#   * network access to the review.opendev.org Gerrit API
#     working directory
#   * network access to https://opendev.org/

import json
try:
    # For Python 3.0 and later
    from urllib.error import HTTPError
    import urllib.request as urllib
except ImportError:
    # Fall back to Python 2's urllib2
    import urllib2 as urllib
    from urllib2 import HTTPError

url = 'https://review.opendev.org/projects/'

# This is what a project looks like
'''
  "openstack-attic/akanda": {
    "id": "openstack-attic%2Fakanda",
    "state": "READ_ONLY"
  },
'''

def is_in_openstack_namespace(proj):
    return proj.startswith('openstack/')


def has_grenade_plugin(proj):
    try:
        r = urllib.urlopen(
            "https://opendev.org/%s/src/branch/master/devstack/upgrade/upgrade.sh" % proj)
        return True
    except HTTPError as err:
        if err.code == 404:
            return False

r = urllib.urlopen(url)
projects = sorted(filter(is_in_openstack_namespace, json.loads(r.read()[4:])))

found_plugins = filter(has_grenade_plugin, projects)

for project in found_plugins:
    print(project[10:])
