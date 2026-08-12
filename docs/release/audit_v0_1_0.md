# v0.1.0 release audit

This focused audit classifies user-facing surfaces; it is not an exhaustive
archaeological inventory.

| Classification | Items | Release action |
|---|---|---|
| KEEP | `src/+reqml`, current homogeneous Q0 configs, tests, methodology/results documents | Reusable and current scientific machinery remains in place. |
| RENAME | Public references to the validated model | Use “REQ Q0 model” publicly; preserve `homogeneous_cartesian_q0_v2` in provenance. |
| MOVE_TO_LEGACY | Homogeneous v1 configs, v1 preview script, v1 methodology document | Moved under `archive/legacy_v1/`; known references now point there. |
| DELETE_IF_PROVABLY_UNUSED | None | No deletion was sufficiently valuable and certain for this release pass. |
| REVIEW_ONLY | Adaptive/scientific-5D work, analysis entry points, compatibility wrappers | Retained as research history or backward-compatible tooling, but excluded from the quick start. |

The companion simulation-framework public entry point remains
`simcampaigns.runCampaign`. Its canonical source configurations are reused by
the two REQ-ML examples; no simulation-framework code change is required.
