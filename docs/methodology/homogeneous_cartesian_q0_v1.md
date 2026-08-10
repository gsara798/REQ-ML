# Controlled homogeneous Cartesian Q0 baseline v1

## Purpose and scope

This experiment tests whether the existing observable REQ spectrum features can
learn `q_target_from_center_truth` in homogeneous media before heterogeneous
geometry or purity estimation is introduced. The experiment trains Q0 only.
Every patch has material purity 1, `REQ_M = 2`, and
`REQ_cs_guess_m_s = 3`. Truth SWS, purity, field labels, and geometry labels
are diagnostic metadata and are not model predictors.

## Cartesian design

The physical condition is

\[
(c_s, f_0, \Delta x, \text{field regime}),
\]

with (c_s \in \{1,2,3,4\}\) m/s,
(f_0 \in \{200,300,400,500,600\}\) Hz,
(\Delta x=\Delta z \in \{0.25,0.30,0.50\}\) mm, and field regime in
`single`, `directional`, `intermediate`, or `diffuse`. This gives 240 physical
conditions. Three independent seed-controlled wavefield realizations per
condition give 720 base runs.

The four fields use respectively `(direction count, requested in-plane count,
solid angle)` equal to `(1,1,0.01)`, `(4,2,0.5)`, `(16,4,pi)`, and
`(32,8,4*pi)`. REQ-ML deterministically derives a different cap axis from each
run seed. In the framework, the same seed also controls source phase, transverse
polarization, and configured amplitude jitter. The framework records realized
directions, support axis, amplitudes, phases, and polarization vectors in sample
provenance. A realization is therefore not merely a rigid rotation.

## Patch geometry and quota

The exact odd REQ window width (W) is resolved by
`reqml.config.default_req_config`; it is not estimated independently. For this
square-window design the extraction stride is

\[
s_x=s_z=\max(4,\lceil W/2\rceil).
\]

The domain has `W + 9*s` points per spatial dimension, yielding a deterministic
10 by 10 grid of candidate centers. In the nominal case all 100 unique,
stride-separated candidates are retained in extraction order; no random
subsampling occurs when available count equals target count. If more than 100
candidates are available, a seeded permutation samples without replacement. If
fewer are available, all are retained and deficit logic applies. Available,
selected, target, and deficit counts are persisted per run. Structural deficits
request the next deterministic larger domain; non-structural deficits request a
new independent realization. The coverage gate must pass before training.

## Workspace setup

Versioned configurations use `${REPOSITORY_ROOT}` for REQ-ML artifacts and
`${SWSIM_ROOT}` for the simulation framework. Configure, for example:

```text
SWSIM_ROOT=/path/to/shear-wave-simulation-framework
```

Resolution fails with `reqml:MissingWorkspaceRoot` when a required root is not
configured; it never substitutes a developer-specific home directory.

## Executed campaign and dataset

The extreme smoke test completed six runs, selected 600 patches, and completed
both tested physical conditions. The full campaign then completed all 720 base
runs with no failed or supplementary runs. All 240 conditions contain exactly
300 selected patches, for 72,000 examples total. Dataset validation confirmed:

- the exact 240-condition Cartesian product;
- homogeneous purity equal to 1 for every patch;
- `M=2` and `cs_guess=3` for every patch;
- unique example IDs and unique run/center records;
- no geometry or quota deficits.

An explicit comparison of planned versus extracted patch width, height, and
both stride components found zero mismatches across all 720 runs.

Recorded runtimes were 255.87 seconds for the full simulation campaign and
172.46 seconds for final dataset construction.

## Splits and model

Splits group all patches from a physical condition and therefore prohibit
condition leakage. The in-domain split contains 168/36/36 train/validation/test
conditions (50,400/10,800/10,800 examples). Frozen definitions also exist for
holding out all (c_s=3) conditions and all 400-Hz conditions.

The baseline is a fixed-seed bagged-tree Q0 regressor with 160 learning cycles
and minimum leaf size 8. Training rows are evaluated using five-fold grouped
out-of-fold predictions; validation and test rows use the final model trained
only on the training partition. Training took 195.25 seconds.

## Internal results

The grouped test partition achieved Q MAE 0.01239, Q RMSE 0.02547, Q bias
0.00083, SWS MAE 0.03139 m/s, SWS RMSE 0.08855 m/s, and SWS MAPE 1.131%.
Test MAPE by SWS was 1.275%, 0.765%, 1.245%, and 1.152% for 1, 2, 3, and
4 m/s. Test MAPE by field was 0.326% (`single`), 1.028% (`directional`),
1.824% (`intermediate`), and 1.091% (`diffuse`).

The critical 3-m/s, 400-Hz condition is assigned to the training partition, so
its reported values are honest grouped out-of-fold predictions rather than
in-sample final-model predictions. MAPE was 0.141% with 0.025% bias for
`single`, and 0.776% with 0.156% bias for `directional`.

## External homogeneous transfer

The final model was evaluated without retraining on dense, previously existing
homogeneous controls. The deployment contract remained `M=2`, `cs_guess=3`.

| Backend | SWS (m/s) | Patches | MAPE (%) | Bias (%) |
|---|---:|---:|---:|---:|
| projected3d Eikonal | 2 | 19,881 | 0.074 | 0.018 |
| projected3d Eikonal | 3 | 19,881 | 0.175 | -0.158 |
| 3D k-Wave | 2 | 4,026 | 0.832 | -0.738 |
| 3D k-Wave | 3 | 4,026 | 0.595 | 0.032 |

External evaluation took 77.59 seconds. These results remove the earlier
approximately 10% systematic 3-m/s underestimation on both backends. They do
not establish heterogeneous transfer; inclusion, bilayer, and sphere samples
remain out-of-distribution diagnostics for a later phase and were not added to
training.

## Output layout

- Campaign manifest: `outputs/homogeneous_cartesian_q0_v1/campaign/campaign_manifest.json`
- Run and condition coverage: `outputs/homogeneous_cartesian_q0_v1/coverage/`
- Dataset: `outputs/homogeneous_cartesian_q0_v1/dataset/examples.mat`
- Frozen splits: `outputs/homogeneous_cartesian_q0_v1/splits/`
- Model and internal diagnostics: `outputs/homogeneous_cartesian_q0_v1/training/q0_bagged_v1/`
- External diagnostics: `outputs/homogeneous_cartesian_q0_v1/external_controls/`
- Execution logs: `outputs/homogeneous_cartesian_q0_v1/logs/`

Generated campaign data, MAT files, plots, CSV reports, and logs are ignored by
Git. The versioned configuration, reusable functions, tests, and this document
are the reproducible source record.
