# Homogeneous projected-3D control dataset v1

## Purpose

This dataset is the first complete campaign-derived control dataset in the
REQ-ML rebuild.

It uses all 300 wavefields from:

```text
homogeneous_projected3d_clean_v1
```

The physical campaign varies:

- homogeneous SWS: 2.0–4.0 m/s;
- frequency: 300–600 Hz;
- projected-3D direction count: 1, 4, 8, 32, and 128;
- three random seeds.

## Extraction configuration

The first control build fixes:

```text
REQ_M = 2
REQ_cs_guess_m_s = 3.0
StepX = 8
StepZ = 8
StoreReqCurves = false
UseWindowParfor = true
```

Frequency varies with the simulation campaign and remains a trainable
operational predictor.

`REQ_M` and `REQ_cs_guess_m_s` are correctly registered as trainable
operational variables, but they are constant in this dataset. Therefore this
dataset cannot identify dependence on M or cs_guess.

## Target

For every patch:

```text
target_cs = cs_true(center pixel)
target_k = 2*pi*f / target_cs
q_target = Ecum_patch(target_k)
```

Patch purity does not redefine the target.

## Outputs

The build writes:

- `examples.mat`;
- `samples.csv`;
- `sample_summaries.csv`;
- `variable_registry.csv`;
- `dataset_summary.json`;
- `dataset_manifest.json`.

## Scope

This dataset is intended for:

- full-pipeline validation;
- homogeneous projected-3D feature auditing;
- geometry and frequency control analyses;
- an initial fixed-operational-configuration baseline.

It is not the final training dataset. The next dataset-generation stage will
reuse each wavefield under multiple REQ operational configurations so that M
and cs_guess vary explicitly without rerunning the simulations.
