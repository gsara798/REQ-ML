# Active Repository Contract

## Purpose

REQ-ML is the active repository for local REQ analysis, patch-level dataset construction, adaptive coverage planning, machine-learning training, and evaluation.

It does not generate physical wavefields.

## Simulation ownership

All physical wavefield generation belongs to `shear-wave-simulation-framework`.

That repository owns:

- media and geometry generation;
- projected-3D Eikonal and k-Wave backends;
- direction, phase, amplitude, and polarization generation;
- physical truth maps;
- simulation seeds and provenance;
- `wavefield_sample.mat`;
- campaign execution and campaign CSV metadata.

REQ-ML consumes simulation artifacts through the versioned `wavefield_sample` contract.

No simulation backend, duplicated medium generator, or internal synthetic-wavefield generator may be added to the active REQ-ML API.

## Active package responsibilities

```text
+baselines   Simple reproducible reference predictors
+config      Active REQ and feature configuration
+datasets    Campaign ingestion, patch extraction, targets, and dataset artifacts
+estimators  Local REQ estimator orchestration
+evaluation  Prediction and SWS evaluation
+features    Patch-level spectral and cumulative-energy features
+io          Versioned input loading
+quantile    REQ mappings and quantile operations
+readiness   Estimator-specific field suitability checks
+schema      Dataset variable roles and contracts
+spectrum    Local spectrum preprocessing and radial analysis
+splits      Leakage-safe grouped data splits
+theory      Active discrete REQ theory
+training    Reproducible model fitting and prediction
+coverage    Patch-level coverage and adaptive campaign planning
```

## Adaptive campaign boundary

REQ-ML may propose the next simulation batch because the proposal depends on patch-level quantities such as purity and measured diffusivity.

REQ-ML must not execute physical simulation internals.

```text
simulation batch
    → wavefield samples
    → patch extraction
    → coverage report
    → deficit analysis
    → next-batch campaign proposal
    → human review
    → execution in shear-wave-simulation-framework
```

## Reproducible artifact requirements

### Dataset run

```text
resolved_config.json
dataset_manifest.json
samples.csv
examples artifact
summary.json
provenance.json
```

### Coverage analysis

```text
resolved_coverage_config.json
coverage_table.csv
coverage_summary.json
coverage_deficits.csv
provenance.json
```

### Next-batch proposal

```text
planner_config.json
parent_coverage_report_hash
next_batch_plan.json
simulation_campaign.json
planner_seed
provenance.json
```

### Training run

```text
resolved_config.json
dataset_manifest.json
split_manifest.json
model_bundle.mat
predictions.csv
metrics.csv
figures/
provenance.json
```

## Dataset independence rule

Patch counts alone are not sufficient evidence of coverage.

Coverage criteria must also track independent:

- simulation runs;
- physical conditions;
- geometry seeds;
- field or excitation realizations;
- local SWS bins;
- frequencies.

All patches from the same run must remain in the same split. Stronger evaluations should group all realizations of one physical condition.

## Model validity rule

A trained model is active only when the repository records:

- code commit;
- dataset identity;
- resolved dataset configuration;
- source simulation campaigns;
- split manifest;
- training configuration;
- all random seeds;
- model bundle;
- evaluation metrics.

Anything without this provenance is exploratory.

## Source policy

Each active source function must be directly required by an active workflow, be a tested scientific primitive required by active code, or define an explicit public contract.

Historical scripts do not justify retaining a function in the active namespace.

## Archive policy

Archived files are preserved for scientific traceability but:

- are excluded from the active MATLAB path;
- are not required to pass the active suite;
- must not be referenced by active code;
- must not define compatibility requirements for new APIs.
