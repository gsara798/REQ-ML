# Homogeneous control baseline v1

## Purpose

This baseline validates the complete REQ-ML path before the heterogeneous
training dataset is designed.

The baseline is intentionally compact. It establishes reusable contracts for:

- grouped physical-condition splits;
- model training;
- q prediction;
- conversion from predicted q to SWS;
- scalar metrics;
- per-run aggregation;
- map-level diagnostics;
- spectral diagnostics for representative patches.

## Dataset

```text
homogeneous_projected3d_control_v2
```

The dataset contains 300 homogeneous projected-3D simulations spanning:

- SWS: 2.0–4.0 m/s;
- frequency: 300–600 Hz;
- direction count: 1, 4, 8, 32, and 128;
- three random seeds.

## Primary split

Conditions are grouped by:

```text
background SWS + frequency + direction count
```

All seeds, runs, and patches belonging to one condition remain in the same
partition.

The deterministic holdout uses:

```text
70% train
15% validation
15% test
seed = 4101
```

Patch-random splitting is forbidden.

## Planned models

- fixed-q baseline;
- operational-context-only baseline;
- ridge regression with all trainable predictors;
- bagged regression trees with all trainable predictors.

## Planned map diagnostics

For representative test runs, the baseline will generate:

- q target map;
- q prediction map;
- q error map;
- true SWS map;
- predicted SWS map;
- SWS percent-error map.

For the central valid patch of each selected run, it will also save:

- 2D local power spectrum;
- radial spectrum `Srad`;
- cumulative-energy curve `Ecum`;
- target and predicted q locations on `Ecum`.

Additional useful map diagnostics considered for the final baseline are:

- target-validity map;
- material-purity map for heterogeneous data;
- confidence or estimability map;
- local spectral anisotropy map;
- per-pixel absolute error and signed bias maps.

Only diagnostics that are interpretable and reusable will be implemented in
the control baseline.
