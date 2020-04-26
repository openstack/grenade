Write the configuration files for use by grenade

**Role Variables**

.. zuul:rolevar:: base_dir
   :default: /opt/stack

   The sources base directory.

.. zuul:rolevar:: grenade_base_dir
   :default: /opt/stack

   The grenade base directory.

.. zuul:rolevar:: grenade_localrc_path
   :default: {{ grenade_base_dir }}/grenade/localrc

   The path of the localrc file used by grenade.

.. zuul:rolevar:: grenade_pluginrc_path
   :default: {{ grenade_base_dir }}/grenade/pluginrc

   The path of the pluginrc file used by grenade.

.. zuul:rolevar:: grenade_localrc
   :type: dict

   A dictionary of variables that should be written into
   the localrc file used by grenade.

.. zuul:rolevar:: grenade_plugins
   :type: list

   A list of grenade plugins that should be deployed.

.. zuul:rolevar:: grenade_tempest_concurrency
   :default: 2

   The concurrency level for the tempest tests executed
   by grenade.

.. zuul:rolevar:: grenade_test_timeout
   :default: 1200

   The timeout (in seconds) for each test executed by grenade.
