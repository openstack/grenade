Set the value of grenade_from_branch and grenade_to_branch
when not specified by the user.
The default values must be updated when grenade is branched.

**Role Variables**

.. zuul:rolevar:: grenade_from_branch
   :default: <previous branch>

   The base branch for the upgrade.

.. zuul:rolevar:: grenade_to_branch
   :default: <current branch>

   The target branch for the upgrade.
