Stable Branch Testing Policy
============================

Since the `Extended Maintenance policy`_ for stable branches was adopted,
OpenStack projects are keeping stable branches around after a "stable"
or "maintained" period, for a phase of indeterminate length called "Extended
Maintenance". Prior to this resolution, Grenade supported a running
voting job down to the oldest+1 stable branch which was supported upstream.
Grenade testing on any branch requires prior branch in a working state,
DevStack-wise.
Due to this requirement and team's resource constraints, Grenade will only
provide support for branches in the "Maintained" phase from the documented
`Support Phases`_. This means Grenade testing on oldest "Maintained" and all
"Extended Maintenance" branches will be made non-voting if they start
failing. All other "Maintained" branches, that is down to the oldest
"Maintained"+1, will be tested and maintained by the Grenade team.

"Extended Maintenance" team, if any, is always welcome to maintain the Grenade
testing on "Extended Maintenance" branches and the oldest "Maintained" branch,
and make the jobs voting again.

.. _Extended Maintenance policy: https://governance.openstack.org/tc/resolutions/20180301-stable-branch-eol.html
.. _Support Phases: https://docs.openstack.org/project-team-guide/stable-branches.html#maintenance-phases
