# Campaign sample inventory contract v1

## Purpose

`reqml.datasets.load_campaign_samples` converts a simulation-framework
`campaign_runs.csv` file into a validated REQ-ML sample inventory.

This layer validates metadata and paths only. It does not load wavefield
contents and does not run REQ.

## Accepted rows

A row is usable when:

- `status` is `completed` or `skipped_completed`;
- `outcome_status` is `completed_valid`;
- `valid` equals `1`;
- `wavefield_sample_path` exists, unless path checking is disabled.

## Traceability

The loader rejects duplicate run IDs, hashes, and sample paths. Rows are sorted
by campaign ordinal before `MaxSamples` is applied, making smoke builds
reproducible.

## Scope

This contract does not define readiness, window extraction, feature
computation, target construction, or data splits.
