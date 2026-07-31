# Active Scientific Core — Source Classification v2

## Status

The repository rebuild is complete.

Historical simulation, k-Wave, study-specific, frozen-model, deployment, plotting, and exploratory analysis workflows were moved to `archive/legacy_v1/`.

The active API contains only the scientific and infrastructure components required to rebuild datasets and train REQ-ML models from the new simulation contract.

## Active packages

- `+baselines`: simple reproducible reference predictors.
- `+config`: active feature and REQ estimator configuration.
- `+datasets`: simulation campaign ingestion, patch-level truth and feature extraction, targets, and dataset artifacts.
- `+estimators`: active local REQ estimator orchestration.
- `+evaluation`: prediction evaluation and spatial reconstruction diagnostics.
- `+features`: reusable patch-level REQ feature extraction.
- `+io`: versioned input loading.
- `+quantile`: local REQ mappings and quantile operations.
- `+readiness`: estimator-specific suitability checks.
- `+schema`: dataset variable roles and leakage prevention.
- `+spectrum`: local spectral preprocessing and radial integration.
- `+splits`: reproducible leakage-safe grouping and splits.
- `+theory`: active discrete theoretical REQ baselines.
- `+training`: reproducible model fitting and prediction.

## Next active package

### `+coverage`

Initial functions:

```text
assignCoverageBins
summarizeCoverage
findCoverageDeficits
```

Later planning functions may include:

```text
proposeNextSimulationBatch
writeSimulationCampaign
```

Coverage decisions are patch-based. The primary joint coverage plane is:

```text
patch purity × measured field diffusivity
```

with required diversity across local SWS, frequency, runs, conditions, and seeds.

## Archived responsibilities

The following are not part of the active API:

- internal wavefield and medium simulation;
- k-Wave execution;
- synthetic wavefield generators;
- historical aperture and Monte Carlo studies;
- Test12-specific workflows;
- old training and frozen-model deployment pipelines;
- legacy validation sample compatibility;
- study-specific plotting;
- duplicate figure template packages;
- unreferenced global-field and metrics helpers.

## Decision rule for future additions

A function may enter the active API only when:

1. an active workflow requires it;
2. its package responsibility is clear;
3. its inputs and outputs are explicit;
4. hidden output or path dependencies are absent;
5. tests cover the required behavior;
6. provenance requirements are preserved.
