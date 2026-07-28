# Homogeneous projected-3D control dataset v3

## Purpose

This dataset extends the homogeneous projected-3D control pipeline with an explicit discrete-theory baseline for each simulation condition.

Version 3 preserves the same 300 wavefields and REQ extraction configuration used in version 2, while adding a traceable mapping between projected-3D direction count and the theoretical REQ field class used for comparison.

The dataset is built from:

```text
homogeneous_projected3d_clean_v1
```

The physical campaign varies:

- homogeneous SWS: 2.0–4.0 m/s;
- frequency: 300–600 Hz;
- projected-3D direction count: 1, 4, 8, 32, and 128;
- three random seeds.

## Extraction configuration

The REQ operational configuration remains fixed:

```text
REQ_M = 2
REQ_cs_guess_m_s = 3.0
StepX = 8
StepZ = 8
StoreReqCurves = false
UseWindowParfor = true
```

Frequency varies through the simulation campaign and remains a trainable operational predictor.

`REQ_M` and `REQ_cs_guess_m_s` are registered as trainable operational variables, but they are constant in this control dataset. Therefore this dataset cannot identify dependence on M or cs_guess.

## Discrete-theory baseline

The discrete-theory quantile is computed using the same effective REQ implementation parameters used for each example:

- spatial sampling: `GRID_dx_m`, `GRID_dz_m`;
- frequency: `campaign_frequency_hz`;
- assumed speed: `REQ_cs_guess_m_s`;
- window size: `REQ_M`;
- window shape: `gamma_win`;
- zero padding: `pad_factor`;
- radial bin count: `REQ_Nbins_effective`;
- spectral smoothing: `smooth_sigma_2d`.

The theory calculation reproduces the discrete FFT grid, REQ windowing, radial binning, spectral smoothing, and cumulative-energy evaluation used by the estimator.

## Theory-class mapping

The current control dataset uses the following operational mapping:

```text
1 direction    -> SingleWave
4 directions   -> PartialDiffuse3D
8 directions   -> PartialDiffuse3D
32 directions  -> Diffuse3D
128 directions -> Diffuse3D
```

This mapping is versioned in:

```text
configs/datasets/homogeneous_projected3d_control_v3.json
```

It is a controlled baseline decision for this dataset and should not be interpreted as a universal physical rule for all projected-3D wavefields.

## Partial-diffuse definition

The partially diffuse theoretical quantile is defined as the arithmetic mean of the discrete directional and projected-diffuse-3D quantiles:

```text
q_partial_diffuse_3d =
    0.5 * (q_single_wave_discrete + q_diffuse3d_discrete)
```

This preserves the operational definition used in the earlier REQ analyses.

## Theory columns

Version 3 adds the following nontrainable diagnostic columns:

```text
theory_field_class
q_theory_single_wave_discrete
q_theory_diffuse3d_discrete
q_theory_discrete
q_theory_valid
```

### `theory_field_class`

The configured theory class assigned to the complete simulation run:

```text
SingleWave
PartialDiffuse3D
Diffuse3D
```

All patches extracted from the same run receive the same theory class.

### `q_theory_single_wave_discrete`

The discrete-theory REQ quantile calculated under the `SingleWave` model.

### `q_theory_diffuse3d_discrete`

The discrete-theory REQ quantile calculated under the `Diffuse3D` model.

### `q_theory_discrete`

The selected theoretical baseline for the run:

- `SingleWave`: uses `q_theory_single_wave_discrete`;
- `PartialDiffuse3D`: uses the mean of the single-wave and diffuse-3D values;
- `Diffuse3D`: uses `q_theory_diffuse3d_discrete`.

### `q_theory_valid`

Logical indicator that the component calculations and selected theoretical quantile are finite and lie within the valid quantile interval `[0, 1]`.

## Trainability

All theory columns are explicitly registered as:

```text
role = diagnostic
source = discrete_req_theory
group = theory_baseline
trainable = false
```

They are intended for theoretical comparison, auditing, and baseline evaluation. They must not be included in the trainable predictor matrix.

The simulation direction count also remains nontrainable because it is not generally observable in experimental measurements.

## Target

For every local patch:

```text
target_cs = cs_true(center pixel)
target_k = 2*pi*f / target_cs
q_target = Ecum_patch(target_k)
```

Patch purity does not redefine the target.

## Intended comparisons

This dataset supports the following minimal baseline comparison:

```text
fixed_q
q_theory_discrete
ridge_full
bagged_full
```

The theoretical model is a nontrained comparator. The ridge and bagged-tree models use only variables marked as trainable in the dataset variable registry.

## Outputs

The dataset build writes:

- `examples.mat`;
- `samples.csv`;
- `sample_summaries.csv`;
- `variable_registry.csv`;
- `dataset_summary.json`;
- `dataset_manifest.json`.

## Scope

This dataset is intended for:

- validating the discrete-theory integration;
- comparing theoretical and learned quantile selection;
- checking performance across direction count and frequency;
- validating the reusable training and evaluation architecture;
- establishing a clean homogeneous control before heterogeneous datasets.

It is not the final multi-M, multi-cs_guess, or heterogeneous training dataset.
