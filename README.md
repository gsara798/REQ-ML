# REQ-ML

REQ-ML is MATLAB research software for estimating local shear-wave speed
(SWS) from harmonic wavefields with the Radial Energy-Quantile (REQ) method.

**REQ-ML analyzes wavefields.** The companion
[shear-wave-simulation-framework](https://github.com/gsara798/shear-wave-simulation-framework)
generates synthetic, projected-3D Eikonal, and k-Wave wavefields.

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

The companion repository is optional for appropriately formatted experimental
wavefields. REQ-ML does not require simulated data at inference time. This is
research software, not a clinical product.

## Quick start

Clone the repository, start MATLAB in its root, and add the source package:

```matlab
setup_reqml;

result = reqml.predictSWS("path/to/wavefield_sample.mat", "M", 2);

imagesc(result.x_mm, result.z_mm, result.cs_map);
axis image; colorbar;
xlabel("x (mm)"); ylabel("z (mm)");
```

The current model is too large for normal Git history. See
[`models/README.md`](models/README.md) to install it, set `REQML_Q0_MODEL`, or
pass `"Model", model_file` to `reqml.predictSWS`.

## Minimal analysis example

The public API supports `M=2` and `M=3` and uses the validated deployment
contract with `cs_guess=3` m/s:

```matlab
result = reqml.predictSWS(sample_file, ...
    "Model", model_file, ...
    "M", 3);
```

It returns `cs_map`, `q_map`, `valid_mask`, `x_mm`, `z_mm`, and `metadata`.
Model internals, feature extraction, Q clipping, and Q-to-SWS conversion remain
behind this interface.

## Generate a wavefield

Install the [companion repository](https://github.com/gsara798/shear-wave-simulation-framework)
as a sibling of REQ-ML, or set `SWSIM_ROOT` to its location. Its documentation
is authoritative for simulation backends, physical sources, k-Wave setup, and
synthetic/Eikonal generation. REQ-ML examples call its public
`simcampaigns.runCampaign` entry point and reuse its canonical configurations.

## Homogeneous example

Edit `cs`, `f0`, `field_regime`, and `M` near the top of
[`examples/homogeneous/run_example.m`](examples/homogeneous/run_example.m).

```matlab
run("examples/homogeneous/run_example.m")
```

```bash
matlab -batch 'run("examples/homogeneous/run_example.m")'
```

## Inclusion example

Edit `cs_background`, `cs_inclusion`, `inclusion_radius_mm`, `f0`,
`field_regime`, and `M` in
[`examples/inclusion/run_example.m`](examples/inclusion/run_example.m). This is
a computationally modest demonstration, not the full scientific validation
campaign.

```matlab
run("examples/inclusion/run_example.m")
```

```bash
matlab -batch 'run("examples/inclusion/run_example.m")'
```

## Common parameters

- `M`: REQ window-width multiplier; the current model supports 2 and 3.
- `f0`: harmonic frequency in Hz; validated training range is 200–600 Hz.
- `field_regime`: `"directional"`, `"intermediate"`, or `"diffuse"`.
- `cs`: homogeneous SWS in m/s; validated training range is 1–4 m/s.

## Current Q0 model

The public **REQ Q0 model** is scientifically frozen from the internal
`homogeneous_cartesian_q0_v2` experiment. That identifier remains in manifests
for reproducibility but is not part of the user-facing API. The model supports
M=2/M=3 and controlled angular coverage from near-directional to diffuse.
Distribution, SHA-256, provenance, validation, and limitations are documented
under [`models/current/`](models/current/README.md).

## Installation and dependencies

REQ-ML was validated with MATLAB R2025a. Prediction with the frozen bagged-tree
bundle requires Statistics and Machine Learning Toolbox. Parallel Computing
Toolbox is optional. Clone the companion repository only when generating the
example wavefields.

```bash
git clone https://github.com/gsara798/REQ-ML.git
git clone https://github.com/gsara798/shear-wave-simulation-framework.git
```

## Repository structure

```text
src/       reusable MATLAB packages
examples/  two canonical end-to-end examples
configs/   active and reproducible configurations
models/    model-distribution metadata (large bundle excluded)
docs/      methodology, validation, and release notes
tests/     unit, integration, and regression tests
archive/   retained pre-release research provenance
scripts/   maintained workflow helpers
outputs/   generated artifacts excluded from Git
```

## Scientific methodology

REQ forms a cumulative radial spectral-energy curve `E_cum(k)`, predicts an
operational quantile `q`, resolves `k_q` from `E_cum(k_q)=q`, and estimates
`c_s=2*pi*f0/k_q`. The model uses deployment-observable local spectral features
and never true SWS as a predictor. See
[`docs/methodology/homogeneous_cartesian_q0_v2.md`](docs/methodology/homogeneous_cartesian_q0_v2.md).

## Validation summary

Observed SWS MAPE was approximately 2% in-domain, 3% for alternating-SWS
interpolation, 3% for alternating-angular interpolation, 2% for external
homogeneous Eikonal data, and 3% for external homogeneous k-Wave data. M=3 was
generally more stable than M=2. These summaries describe the frozen evaluation
scope; they are not clinical performance claims.

## Limitations

Mixed/interface patches remain harder than homogeneous patches. External
validation is deliberately limited, and localized k-Wave hotspot/outlier
structures exist even though they do not dominate global homogeneous
estimates. Experimental inputs must follow the documented
`wavefield_sample.mat` schema and remain within a scientifically appropriate
deployment domain.

## Legacy research

Older v1 entry points are retained under [`archive/legacy_v1/`](archive/legacy_v1/README.md)
for provenance. Adaptive/scientific-5D material is also retained as research
history, but it is not the recommended v0.1.0 interface.

## Citation

Please cite this repository using [`CITATION.cff`](CITATION.cff). Licensed under
Apache License 2.0. Maintainer: **Sara Gomez-Ramirez**
([@gsara798](https://github.com/gsara798)).
