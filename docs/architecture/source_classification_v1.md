# Source Classification v1

This is the initial classification of the pre-rebuild `src/+reqml` tree.

## KEEP

These packages contain reusable scientific functionality and remain candidates
for the active core:

- `+spectrum`
- `+quantile`
- `+estimators`
- `+features`
- `+inference`
- `+metrics`
- `+theory`
- `+config` functions that are still needed by the new pipeline

Individual functions still require review and tests before becoming part of a
new baseline.

## PORT

The following responsibilities are useful but currently live in mixed or
historical packages:

### From `+analysis`

- training functions -> `+models`
- model registration and persistence -> `+models`
- prediction helpers -> `+inference`
- feature builders -> `+features`
- spectral decomposition -> `+spectrum`
- summary and grouped-error functions -> `+evaluation`
- plotting and figure saving -> `+visualization`

### From `+integration`

- `load_wavefield_sample` -> `+io`
- `assess_req_readiness` -> `+readiness`
- active external validation functions -> `+evaluation` or thin experiment
  entry points

### From `+figures` and `+templates`

Consolidate active plotting and styling utilities under `+visualization`.

### From `+simulate`

`build_patch_windows` may be retained under `+datasets` or another
estimator-facing package after its responsibility is reviewed.

## RETIRE

The following code should not remain in the active architecture:

- `+kwave`, because simulation belongs to the shear-wave simulation framework;
- synthetic wavefield generation duplicated by `swsynth`;
- `+studies` orchestration tied to historical experiments;
- `Test12Analysis`;
- historical Monte Carlo and aperture sweep runners;
- deployment or training helpers that depend on untracked historical outputs.

## Decision rule

A PORT candidate becomes active only after:

1. its new responsibility and package are selected;
2. its inputs and outputs are explicit;
3. hidden path/output dependencies are removed;
4. tests confirm the required behavior;
5. an active baseline workflow needs it.
