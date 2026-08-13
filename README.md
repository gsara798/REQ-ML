# REQ-ML

REQ-ML is MATLAB research software for estimating local shear-wave speed
(SWS) from harmonic wavefields using the Radial Energy-Quantile (REQ) method.

REQ-ML takes a complex harmonic wavefield as input and returns spatial maps of
the estimated REQ quantile and shear-wave speed.

```text
complex harmonic wavefield
          |
          v
 wavefield_sample.mat
          |
          v
        REQ-ML
          |
          +--> Q map
          |
          +--> SWS map
```

REQ-ML analyzes wavefields; it does not require a simulation backend at
inference time.

The companion
[shear-wave-simulation-framework](https://github.com/gsara798/shear-wave-simulation-framework)
can generate synthetic, projected-3D Eikonal, and k-Wave wavefields for
simulation studies and examples:

```text
shear-wave-simulation-framework
              |
              v
       wavefield_sample.mat
              |
              v
            REQ-ML
              |
              v
           SWS map
```

The companion repository is optional when analyzing appropriately formatted
experimental data.

> REQ-ML is research software and is not intended for clinical use.

## Requirements

REQ-ML has been validated with MATLAB R2025a.

Required for prediction with the released bagged-tree Q0 model:

- MATLAB
- Statistics and Machine Learning Toolbox

Optional:

- Parallel Computing Toolbox
- `shear-wave-simulation-framework`, only when generating example or simulated
  wavefields

## Installation

Clone REQ-ML:

```bash
git clone https://github.com/gsara798/REQ-ML.git
cd REQ-ML
```

Start MATLAB from the repository root and initialize the project:

```matlab
setup_reqml;
```

### Install the REQ Q0 model

The trained model bundle is too large for normal Git history and is distributed
separately as a GitHub Release asset.

The model can be provided in any of three ways:

1. Place it at

   ```text
   models/current/model_bundle.mat
   ```

2. Set the environment variable

   ```bash
   export REQML_Q0_MODEL=/path/to/model_bundle.mat
   ```

3. Pass it explicitly to `reqml.predictSWS`:

   ```matlab
   result = reqml.predictSWS( ...
       sample_file, ...
       Model="/path/to/model_bundle.mat", ...
       M=2);
   ```

The expected file size, SHA-256 checksum, and model provenance are recorded in
[`models/current/model_manifest.json`](models/current/model_manifest.json).

See [`models/README.md`](models/README.md) for model-distribution details.

## Quick start: analyze a wavefield

For an existing `wavefield_sample.mat`:

```matlab
setup_reqml;

result = reqml.predictSWS( ...
    "path/to/wavefield_sample.mat", ...
    M=2);

imagesc(result.x_mm, result.z_mm, result.cs_map);
axis image;
colorbar;
xlabel("x (mm)");
ylabel("z (mm)");
title("REQ Q0 shear-wave speed");
```

The main outputs are:

- `result.cs_map` — estimated shear-wave-speed map in m/s
- `result.q_map` — predicted local REQ quantile
- `result.valid_mask` — valid prediction locations
- `result.x_mm`, `result.z_mm` — map coordinates
- `result.metadata` — model and processing metadata

The current public model supports `M=2` and `M=3`.

## Input data

The public prediction API expects a `wavefield_sample.mat` file following the
REQ-ML wavefield contract.

The sample contains:

- a complex 2-D harmonic wavefield
- x and z coordinates and spatial sampling
- harmonic frequency
- wavefield component, quantity, and units
- provenance and validation metadata

Simulation-generated samples may also contain ground-truth material information
for validation. Ground truth is optional for public inference and is not used
by `reqml.predictSWS` to compute the SWS estimate.

## Run the public examples

The easiest end-to-end check is:

```matlab
run("examples/run_all.m")
```

or from the terminal:

```bash
matlab -batch 'run("examples/run_all.m")'
```

This runs two canonical examples:

1. a homogeneous medium
2. a circular inclusion

For each case, the example:

```text
builds the simulation configuration
              |
              v
generates the harmonic wavefield
              |
              v
plots amplitude / phase / real(U)
              |
              v
runs the REQ Q0 model
              |
              v
creates the SWS map and validation metrics
```

Generated figures are saved under:

```text
outputs/examples/figures/
```

The examples require the companion
[shear-wave-simulation-framework](https://github.com/gsara798/shear-wave-simulation-framework).

Place that repository beside REQ-ML:

```text
parent_directory/
├── REQ-ML/
└── shear-wave-simulation-framework/
```

or set:

```bash
export SWSIM_ROOT=/path/to/shear-wave-simulation-framework
```

## Homogeneous example

Run:

```matlab
run("examples/homogeneous/run_example.m")
```

The default example uses:

- SWS: 2.0 m/s
- frequency: 400 Hz
- directional field
- `M=2`
- prediction step: 4 pixels

The underlying public runner is:

```matlab
example = reqml.examples.runExample( ...
    "homogeneous", ...
    Cs=2.0, ...
    FrequencyHz=400, ...
    FieldRegime="directional", ...
    M=2, ...
    StepPixels=4);
```

## Inclusion example

Run:

```matlab
run("examples/inclusion/run_example.m")
```

The default example uses:

- background SWS: 2.0 m/s
- inclusion SWS: 3.0 m/s
- inclusion radius: 15 mm
- frequency: 400 Hz
- directional field
- `M=2`
- prediction step: 4 pixels

The underlying public runner is:

```matlab
example = reqml.examples.runExample( ...
    "inclusion", ...
    CsBackground=2.0, ...
    CsInclusion=3.0, ...
    InclusionRadiusMm=15, ...
    FrequencyHz=400, ...
    FieldRegime="directional", ...
    M=2, ...
    StepPixels=4);
```

The inclusion example reports metrics separately in the background and
inclusion-core ROIs. A band around the material interface is excluded from
these summary metrics.

## Common parameters

### `M`

REQ window-width multiplier.

The released model supports:

```text
M = 2 or 3
```

### `FrequencyHz`

Harmonic wave frequency.

The frozen Q0 model was trained over:

```text
200–600 Hz
```

### `FieldRegime`

Example wavefield angular complexity:

```text
"directional"
"intermediate"
"diffuse"
```

### `StepPixels`

Spatial interval between neighboring REQ evaluations.

For example:

```matlab
StepPixels=4
```

evaluates overlapping REQ windows every four input pixels.

`StepPixels` controls the sampling density of the output map. It does **not**
change the physical REQ window size and should not be interpreted as the
intrinsic spatial resolution of the estimator.

## Current REQ Q0 model

The public model is referred to as the **REQ Q0 model**.

It was scientifically frozen from the internal
`homogeneous_cartesian_q0_v2` experiment. That internal identifier is retained
in manifests and scientific documentation for reproducibility, but is not part
of the public user-facing model name.

The model:

- supports `M=2` and `M=3`
- was trained over SWS values from 1 to 4 m/s
- was trained over frequencies from 200 to 600 Hz
- includes controlled angular support from near-directional to diffuse fields
- uses deployment-observable spectral features
- does not use true SWS as a predictor

Model provenance and checksum information are documented under
[`models/current/`](models/current/README.md).

## Scientific methodology

REQ computes a local radial spatial-frequency energy distribution.

For each analysis window, the method forms the cumulative radial spectral-energy
curve

```text
E_cum(k)
```

and determines the radial wavenumber `k_q` satisfying

```text
E_cum(k_q) = q.
```

The released Q0 model predicts the operational quantile `q` from local
wavefield-derived spectral features.

Shear-wave speed is then estimated from

```text
c_s = 2*pi*f0/k_q.
```

The full scientific methodology and frozen-model development are documented in
[`docs/methodology/homogeneous_cartesian_q0_v2.md`](docs/methodology/homogeneous_cartesian_q0_v2.md).

## Validation summary

The frozen model was evaluated across internal generalization tests and
independent simulation backends.

Approximate homogeneous SWS errors were:

- ~2% MAPE for in-domain evaluation
- ~3% MAPE when alternating SWS levels were held out
- ~3% MAPE when alternating angular-support levels were held out
- ~2% MAPE on external homogeneous Eikonal simulations
- ~3% MAPE on external homogeneous k-Wave simulations

An independent spatial-sampling validation at 0.30 mm produced approximately
2% MAPE.

External heterogeneous cases were also evaluated as transfer tests. Errors are
generally larger near interfaces and in locally complex wavefields than in
homogeneous regions.

These values describe the frozen scientific evaluation scope and are not
clinical performance claims.

## Interpretation and limitations

REQ is a local spectral estimator. Its effective spatial resolution depends on
the physical analysis-window size, which depends on frequency, spatial
sampling, `M`, and the deployment configuration.

Important limitations include:

- mixed-material and interface patches are more difficult than homogeneous
  patches
- highly complex local interference can increase estimation error
- localized k-Wave hotspot/outlier structures have been observed even when
  global homogeneous estimates remain accurate
- experimental inputs should remain within a scientifically appropriate
  deployment domain
- the currently released model was trained on simulated harmonic wavefields;
  experimental validation is separate from the simulation-based validation
  summarized above
- the software is not clinically validated

## Repository structure

```text
src/       reusable MATLAB packages and public API
examples/  canonical end-to-end examples
configs/   active and reproducible scientific configurations
models/    model-distribution metadata; large bundles are excluded from Git
docs/      methodology, validation, and release documentation
tests/     unit, integration, and regression tests
archive/   retained legacy research provenance
scripts/   maintained workflow helpers
outputs/   generated local artifacts; excluded from Git
```

## Research and legacy workflows

The recommended public v0.1.0 interface is:

```matlab
reqml.predictSWS(...)
```

with `reqml.examples.runExample(...)` available for the canonical simulation
examples.

Older v1 workflows are retained under
[`archive/legacy_v1/`](archive/legacy_v1/README.md) for scientific provenance.

Adaptive and scientific-5D code is retained as research infrastructure and is
not required for normal use of the released Q0 model.

## Citation

Please cite this repository using [`CITATION.cff`](CITATION.cff).

Licensed under the Apache License 2.0.

Maintainer: **Sara Gomez-Ramirez**
([@gsara798](https://github.com/gsara798)).
