#!/usr/bin/env python
# Copyright (c) 2014 Hewlett-Packard Development Company, L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import argparse
import yaml
import os
import sys

ENABLED_SERVICES = None

# Maps service names to possible entries in devstack's ENABLED_SERVICES
DEVSTACK_SERVICE_MAP = {
    'ceilometer': 'ceilometer-',
    'cinder': 'c-',
    'glance': 'g-',
    'heat': 'h-',
    'ironic': 'ir-',
    'keystone': 'key',
    'nova': 'n-',
    'neutron': 'q-',
    'trove': 'tr-',
    'swift': 's-',
}


def load_base_resources():
    """Load the yaml file containing all possible resources"""
    d = os.path.dirname(sys.argv[0])
    f = os.path.join(d, 'base_resources.yaml')
    return yaml.load(open(f, 'r'))


def service_enabled(service):
    """Duplicate devstack's is_service_enabled()"""
    if service in ENABLED_SERVICES:
        return True
    abr = DEVSTACK_SERVICE_MAP.get(service)
    if abr:
        for svc in ENABLED_SERVICES:
            if svc.startswith(abr):
                return True
    return False


def get_options():
    parser = argparse.ArgumentParser(
        description="Generate a javelin resources yaml configuration based "
                    "on devstack's enabled services.")
    parser.add_argument('-o', '--output', action='store', required=False,
                        help='Output file to write yaml javelin resources '
                             'config.')
    parser.add_argument('enabled_services', metavar='$ENABLED_SERVICES',
                        help='Devstack $ENABLED_SERVICES.')
    return parser.parse_args()


def main():
    opts = get_options()
    global ENABLED_SERVICES
    ENABLED_SERVICES = opts.enabled_services.split(',')
    base_resources = load_base_resources()
    enabled_resources = {
        'tenants': base_resources['tenants'],
        'users': base_resources['users'],
        'images': base_resources['images'],
        'secgroups': base_resources['secgroups'],
    }

    if service_enabled('cinder'):
        enabled_resources['volumes'] = base_resources['volumes']

    if service_enabled('swift'):
        enabled_resources['objects'] = base_resources['objects']

    if service_enabled('neutron'):
        enabled_resources['networks'] = base_resources['networks']
        enabled_resources['subnets'] = base_resources['subnets']
        enabled_resources['routers'] = base_resources['routers']

    # do not create servers for ironic, we need the node resources
    # to run tempest.
    if not service_enabled('ironic'):
        enabled_resources['servers'] = base_resources['servers']
        # if neutron is not enabled, remove networks
        if not service_enabled('neutron'):
            for server in enabled_resources['servers']:
                del server['networks']

    out = yaml.dump(enabled_resources, default_flow_style=False)
    print '# Grenade generated javelin2 resources yaml:'
    print out
    if opts.output:
        with open(opts.output, 'w') as f:
            f.write(out)

if __name__ == '__main__':
    main()
