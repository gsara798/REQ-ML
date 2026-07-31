# Center-pixel REQ quantile target contract v1

## Scientific definition

Each local REQ example predicts the physical state at the center pixel of its
analysis patch.

For a patch centered at `(z_c, x_c)`:

```text
c_target = c_true(z_c, x_c)
k_target = 2*pi*f / c_target
q_target_from_center_truth = Ecum_patch(k_target)
```

## Meaning of the patch

The patch supplies local spectral context. It does not redefine the physical
target as a patch mean, median, dominant-material value, or purity-weighted
value.

## Heterogeneous windows

A patch may cross an interface or contain multiple materials. The target
remains the truth at the center pixel.

Material purity and within-patch SWS statistics remain diagnostic variables
for estimability, reliability, stratified evaluation, and possible sample
weighting. They do not alter the target definition.

## Dataset columns

The dataset layer publishes:

- `target_cs_center_m_s`;
- `target_k_center_rad_m`;
- `q_target_from_center_truth`;
- `target_valid`;
- `target_definition = center_pixel_truth`.

## Legacy diagnostic

`q_local_req` remains available temporarily for compatibility. In the current
estimator it is derived using the estimator's configured global reference
wavenumber and must not be used as the heterogeneous ML target.

The active supervised-learning target is
`q_target_from_center_truth`.
