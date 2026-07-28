# Dataset variable registry contract v1

## Purpose

`reqml.schema.dataset_variable_registry` is the central authority for the role,
origin, grouping, and trainability of REQ-ML dataset columns.

Dataset auditing and training code must consult this registry rather than
reimplementing name-based exclusion lists.

## Variable roles

- `identifier`: dataset, sample, example, and run identity;
- `coordinate`: patch and map location;
- `metadata`: campaign and physical acquisition context;
- `prediction`: estimator outputs produced using a selected quantile;
- `truth`: simulation-derived physical truth and patch diagnostics;
- `target`: supervised-learning targets;
- `diagnostic`: REQ curves, mappings, and legacy diagnostics;
- `feature`: numeric wavefield-derived predictor candidate;
- `unregistered`: unknown nonnumeric columns.

## Trainability

Only variables with:

```text
trainable = true
```

are eligible as default predictors.

Trainable inputs may be wavefield-derived features or operational context
metadata available during inference.

Constant, nonfinite, or scientifically excluded features may still be removed
during dataset auditing and training configuration.

## Initial classification policy

Known non-feature columns are registered explicitly.

Remaining numeric or logical columns are classified as wavefield-derived
features. Unknown nonnumeric columns remain unregistered and are never
trainable.

Every row records `classification_rule`, making the decision auditable.

## Extension policy

When a new truth, target, metadata, prediction, coordinate, or diagnostic
column is introduced, it must be added to this registry in the same commit.

New numeric wavefield-derived features are automatically visible, but their
feature group should be added when the default grouping is insufficient.

## Operational context predictors

The canonical trainable operational variables are:

- `REQ_M`: REQ window length in wavelengths;
- `REQ_cs_guess_m_s`: operational SWS guess used to define the window and normalized features;
- `campaign_frequency_hz`: excitation frequency.

Compatibility aliases and simulation truth remain non-trainable:

- `M` duplicates `REQ_M`;
- `SIM_f0` duplicates `campaign_frequency_hz`;
- `SIM_cs_bg` is simulation truth, not an operational guess.

Predictor selection therefore uses `trainable=true`, not `role=feature`.

## Spatial and spectral discretization predictors

The following discretization variables are trainable because they are known
during inference and directly affect the sampled local spectrum:

- `GRID_dx_m`;
- `GRID_dz_m`;
- `REQ_dkx_rad_m`;
- `REQ_dkz_rad_m`;
- `REQ_Nbins_effective`.

`REQ_dkx_rad_m` and `REQ_dkz_rad_m` are the actual Fourier-grid spacings after
window sizing and zero padding. They are preferable to a single scalar
`delta_k` because anisotropic grids may produce different resolutions along x
and z.

These variables may be correlated with M, cs_guess, frequency, grid spacing,
window size, and padding. Their inclusion is valid but should later be tested
with ablation and redundancy analyses.

