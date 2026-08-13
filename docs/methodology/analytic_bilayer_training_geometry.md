# Analytic bilayer training geometry

## Purpose

Adaptive REQ-ML training uses planar bilayers when
`planning.training_geometry_mode` is `analytic_bilayer`. The objective is
exact local coverage of the scientific grid, not geometric diversity.
Circular inclusions remain available for validation and out-of-distribution
tests. Explicit homogeneous simulations remain available as a small control
set, but are not selected for adaptive grid filling.

A homogeneous patch is the limiting bilayer case: the interface remains in
the simulation domain but lies outside the complete analysis-patch support,
so every patch pixel belongs to the dominant material.

## Continuous target

For an axis-aligned interface crossing a continuous square window of side
length \(L_{win}\), the dominant-material fraction is

\[
p = 0.5 + \frac{d}{L_{win}},
\qquad
d = (p - 0.5)L_{win},
\]

where \(d\) is measured from the patch center into the dominant material.
REQ-ML initializes the search at the midpoint of the requested interval. For
`[0.9,0.98)`, the continuous target is `p=0.94` and `d=0.44*Lwin`.

The continuous result is only an initial estimate. It is never accepted
without evaluating the discrete mask.

## Coordinate and patch conventions

REQ-ML public truth maps use `material_id_zx(z,x)`. Patch centers are stored
as one-based `[x,z]` indices. A simulation pixel has physical coordinates

\[
x = (i_x-1)\,d_x,
\qquad
z = (i_z-1)\,d_z.
\]

The simulator constructs the actual floating-point coordinate arrays with
`linspace(0,L,N)`. Analytic mask evaluation uses that same construction.
Although `(index-1)*spacing` is algebraically equivalent, its last-bit value
can differ from `linspace`; at a strict grid-aligned interface, that difference
can change one material column.

The REQ window is resolved exactly as in dataset extraction:

```text
win_size = round(M * cs_guess / frequency_hz / dx_m)
win_size = max(3, win_size)
if win_size is even, increment it by one
half_win = floor(win_size / 2)
```

Consequently, active REQ extraction always uses an odd window and the support
is the symmetric inclusive range

```text
x = (cx-half_win):(cx+half_win)
z = (cz-half_win):(cz+half_win)
```

The current synthetic bilayer uses normal angle zero. Its positive material
occupies the strict half-plane

\[
x - x_{interface} > 0,
\]

which is the same threshold implemented by `swsynth`. The nonpositive side
contains the background material. When the positive side is selected as the
dominant side, the requested local SWS is assigned to the object material;
otherwise it is assigned to the background material.

## Discrete correction

`computeBilayerInterfacePlacement` performs the following deterministic
procedure:

1. Resolve the exact odd REQ window for the sampled frequency.
2. Verify that the complete support and configured domain margin fit inside
   the simulator grid.
3. Compute the continuous midpoint target and round its interface coordinate
   to the nearest grid location.
4. Evaluate legal integer interface locations using the strict bilayer mask.
5. Compute purity with the same canonical definition used by dataset
   extraction: the modal material count divided by the number of valid patch
   pixels.
6. Keep only candidates in the requested interval and select the closest
   purity to the target, then the closest location to the analytic rounding.
   Intervals are half-open except for the final coverage interval
   `[lower,1]`, matching MATLAB `discretize`. If a small window has no
   sub-unity fraction in that final interval, purity 1 is legal only with the
   interface outside the patch support.

An exact request `[1,1]` follows a separate rule. The selected interface must
be at least one grid interval beyond the patch support; placing it on the last
patch pixel is not considered outside the patch.

The function reports distinct errors for an invalid/unsupported coordinate
convention, insufficient domain margin, invalid patch support, and absence of
any discrete offset in the requested interval. It never clamps an infeasible
request to another purity.

## Center consistency and packing policy

Each analytic request creates one physical condition. The batch plan stores
the selected center, and dataset construction reads the executed batch plan
and extracts that exact center. Analytic conditions therefore do not use the
legacy post-simulation search for unrelated centers. Multiple requested cells
are not packed into one analytic bilayer in the current implementation.

## Audit metadata

Every analytic physical condition stores:

```text
requested_purity_lower
requested_purity_upper
target_purity
predicted_discrete_purity
interface_offset_pixels
interface_offset_m
interface_position_m
selected_patch_center_indices_xz
selected_patch_center_m
dominant_material_side
geometry_control_mode
patch_size_pixels
grid_spacing_m
domain_size_m
feasibility_diagnostics
```

`interface_offset_pixels` and `interface_offset_m` are signed from the
selected center to the interface along the positive interface normal.
`interface_position_m` is the global plane offset passed to the simulator.

`summarizeRequestedVsAchieved` combines these fields with purity measured from
the extracted truth-map patch. A requested-cell hit requires simultaneous
agreement in SWS, frequency, purity, and nominal angular-coverage bins.

## Backward compatibility

Configs without `planning.training_geometry_mode` use `legacy_balanced`.
That mode retains historical geometry balancing among bilayers, inclusions,
and eligible explicit homogeneous conditions, as well as truth-map-directed
multi-center extraction. No general geometry support was removed.

## Controlled smoke result

The controlled low-frequency configuration is
`configs/validation/reqml_analytic_bilayer_smoke_v1.json`. It covers SWS bins
1, 3, and 5 and Dnom bins 2, 4, and 5 at 210--240 Hz with requested purity
`[0.9,0.98)`. The 2026-08-04 run produced 9 requested-cell hits from 9
conditions (hit rate 1.00). Predicted and achieved purities agreed exactly and
ranged from 0.9333 to 0.9398.
