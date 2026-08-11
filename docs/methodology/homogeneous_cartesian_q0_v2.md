# Controlled homogeneous Cartesian Q0 v2

## Scope

Version 2 closes the controlled homogeneous Q0 development study. It changes
only the sampling density of shear-wave speed and angular-field complexity,
and adds joint support for `M=2` and `M=3`. It does not change the REQ
estimator, introduce material purity as a predictor, or start purity-aware
training. All v2 physical simulations, seeds, manifests, datasets, splits,
models, and external controls have v2 identities. No v1 wavefield sample is
scientific input to v2.

## Angular design coordinate

The legacy nominal angular coverage remains available as a diagnostic:

\[
D_{\mathrm{nom}} = \frac{N}{128}\frac{\Omega}{4\pi}.
\]

It is not the primary v2 coordinate because it multiplies support and source
count, and therefore does not measure either physical quantity directly. The
primary controlled coordinate is the spherical support fraction

\[
A = \frac{\Omega}{4\pi}.
\]

The direction count `N` and exact acquisition-plane count `P` increase
monotonically with `A`; they are not independently Cartesian-producted.

| Level | Name | A | N | P | Omega (sr) | Legacy Dnom |
|---:|---|---:|---:|---:|---:|---:|
| 1 | near_single | 0.000795775 | 1 | 1 | 0.01 | 0.000006217 |
| 2 | narrow | 0.01 | 3 | 1 | 0.125664 | 0.000234375 |
| 3 | directional | 0.04 | 6 | 2 | 0.502655 | 0.001875 |
| 4 | low_intermediate | 0.125 | 10 | 3 | 1.570796 | 0.009765625 |
| 5 | intermediate | 0.25 | 16 | 4 | 3.141593 | 0.03125 |
| 6 | broad | 0.5 | 24 | 6 | 6.283185 | 0.09375 |
| 7 | diffuse | 1.0 | 32 | 8 | 12.566371 | 0.25 |

Angular design metadata is retained for design and subgroup diagnostics only.
Q0 does not receive `A`, `Dnom`, `N`, `P`, solid angle, angular level, or field
name as predictors. It continues to infer directional structure only from
observable spectral features.

## Physical Cartesian design

The training grid is

- SWS: `1.00:0.25:4.00` m/s (13 levels);
- frequency: `[200, 300, 400, 500, 600]` Hz;
- spacing: `[0.25, 0.50]` mm;
- the seven coupled angular regimes above;
- three independent deterministic seeds per physical condition;
- fixed `cs_guess=3.0` m/s.

This gives 910 conditions and 2730 newly generated physical wavefields. Each
wavefield is analyzed twice, once with `M=2` and once with `M=3`; M never
duplicates wave propagation. The target is exactly 100 unique patches per
run and M, or 546,000 examples in total. For each M, window width is computed
from its own wavelength support and the stride is

\[
s = \max(4,\lceil W/2\rceil).
\]

The physical domain is sized from the more demanding M3 geometry. Planned and
extracted width/stride are audited separately for M2 and M3.

## Development isolation and gates

Three frozen grouped experiments use the same 160-tree bagged regressor,
minimum leaf size 8, fixed seed, observable predictor registry, and
center-truth quantile target:

1. an in-domain grouped train/validation/test split;
2. SWS interpolation trained on `[1,1.5,2,2.5,3,3.5,4]` and tested on
   `[1.25,1.75,2.25,2.75,3.25,3.75]` m/s;
3. angular interpolation trained on levels `[1,3,5,7]` and tested on
   `[2,4,6]`.

The closure gates are 3% overall MAPE for alternating-SWS interpolation and
4% for alternating-angular interpolation. A newly simulated 0.30-mm set is
reserved for discretization interpolation and has a 3% target. The final
model is trained on all approved homogeneous examples only after the
development gates are evaluated. External results are never used to tune it.

## Clean external matrix

The v2 external matrix contains newly seeded Eikonal and native 3D k-Wave
controls at 400 Hz for homogeneous SWS 2 and 3 m/s, a 2/3-m/s inclusion, and
an oblique 2/3-m/s bilayer at 30 degrees. Each geometry uses angular levels
1, 5, and 7 (low, middle, high), with exactly matched requested `N`, `P`, and
solid angle across backends. Requested directions, realized directions,
plane counts, mapping error, seeds, and angular diagnostics remain in
simulation provenance.

At 0.50-mm external spacing, M2 uses `W=31`, stride 16, while M3 uses `W=45`,
stride 23. A 150-mm x-z domain and 52-mm inclusion radius yield, on the actual
discrete Eikonal truth mask, 86/32 pure inclusion-core patches and 110/40 pure
background patches for M2/M3. The oblique bilayer yields 131/107 pure layer
cores for M2 and 55/53 for M3. Thus both geometries exceed 25 stride-matched
pure patches per material and M.

The native k-Wave preflight uses 301x48x301 grids for homogeneous and bilayer
controls (1.566 GB conservative estimate). A true 52-mm sphere requires
301x225x301 points so that it fits physically in all three dimensions; its
conservative estimate is 7.339 GB. Every k-Wave campaign is dry-run validated
before solver execution.

External maps are extracted densely (`StepX=StepZ=1`). Primary quantitative
metrics use the M-specific stride and do not treat overlapping dense patches
as independent. Inclusion ROIs are `background_far`, `inclusion_core`, and
`interface_band`; bilayer ROIs are `layer_1_core`, `layer_2_core`, and
`interface_band`. A patch is an interface patch exactly when its full truth
support contains more than one material. Truth purity is diagnostic only and
is never supplied to Q0.
