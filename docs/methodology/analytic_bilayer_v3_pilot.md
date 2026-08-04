# Analytic bilayer V3 adaptive pilot

## Scope and decision

The campaign
`reqml_adaptive_scientific_4d_v3_analytic_bilayer_pilot` ran ten adaptive
iterations on 2026-08-04. It used the complete 500-cell scientific grid,
analytic bilayers for bootstrap and adaptive planning, at most 12 planned
conditions per adaptive batch, and two realizations per condition.

All ten iterations completed in 85.074 seconds. The result is **not suitable
for immediate continuation**. Analytic targeting greatly improved exact-cell
hit rate, but the one-condition/one-center policy produced only one patch per
run. It therefore accumulated too few examples to satisfy the four-example
threshold efficiently.

Generated campaign data, simulation MAT files, audit CSV files, and logs are
ignored outputs and are not committed.

## Iteration results

| Iteration | Executed runs | Accumulated runs | Examples | Observed cells | Deficient cells | New observed | New complete | Request hits/conditions | Hit rate | Median absolute purity error | Maximum absolute purity error |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 50 | 50 | 50 | 25 | 500 | 25 | 0 | 25/25 | 1.000 | 0 | 0.030303 |
| 2 | 24 | 74 | 74 | 37 | 500 | 12 | 0 | 12/12 | 1.000 | 0.010989 | 0.013333 |
| 3 | 24 | 98 | 98 | 48 | 499 | 11 | 1 | 11/12 | 0.917 | 0.011236 | 0.018868 |
| 4 | 24 | 122 | 122 | 60 | 499 | 12 | 0 | 12/12 | 1.000 | 0 | 0.018182 |
| 5 | 24 | 146 | 146 | 70 | 497 | 10 | 2 | 10/12 | 0.833 | 0 | 0.022222 |
| 6 | 24 | 170 | 170 | 81 | 496 | 11 | 1 | 11/12 | 0.917 | 0 | 0.024390 |
| 7 | 24 | 194 | 194 | 92 | 496 | 11 | 0 | 11/12 | 0.917 | 0.027027 | 0.030303 |
| 8 | 24 | 218 | 218 | 104 | 496 | 12 | 0 | 12/12 | 1.000 | 0 | 0.032258 |
| 9 | 24 | 242 | 242 | 116 | 496 | 12 | 0 | 12/12 | 1.000 | 0 | 0.032258 |
| 10 | 24 | 266 | 266 | 128 | 496 | 12 | 0 | 12/12 | 1.000 | 0 | 0.013699 |

Across all iterations, V3 hit 128 of 133 requested four-dimensional cells
(0.962). No condition had zero patches or zero valid patches, so exact-center
extraction did not fail.

## Equal-budget V2 comparison

V2 and V3 both accumulated 266 runs by iteration 10. V2 produced 1,131
examples, observed 210 cells, and left 375 cells deficient. V3 produced 266
examples, observed 128 cells, and left 496 cells deficient. V2's recomputed
current-definition request hit rate was 41/133 (0.308), but its regular center
sampling supplied many patches per run and incidental coverage of multiple
cells.

Thus analytic control solved the request-placement problem but did not improve
full-grid convergence under the current one-patch-per-run extraction policy.
V3 reduced deficient cells from 500 to 496; V2 had 375 deficient cells at the
same iteration and run count.

## Final difficulty

The final audit found 496 difficult cells, 372 never-observed cells, 397
stagnant cells, and zero deficient cells whose entire request history missed.
The zero request-miss-cell count is compatible with five missed conditions:
each affected cell was hit by another request during the pilot.

The strongest apparent difficulty is planner-order/throughput limited:

- SWS `[2.5,3)`, `[3,3.5)`, and `[3.5,4]` each have 95 never-observed cells;
  SWS `[1.5,2)` has no never-observed cells.
- Purity `[0.9,0.98)` has the highest mean difficulty score and 95
  never-observed cells. Purity `[0.98,1]` leaves all 125 cells deficient and
  has the largest total example deficit.
- Frequency bins `[450,550)` and `[550,601]` leave all 100 cells deficient;
  frequency `[250,350)` has the highest mean difficulty score.
- Nominal angular-coverage difficulty is nearly uniform across its five bins.

These ten-iteration counts must not be interpreted as evidence that high SWS
or high frequency is intrinsically infeasible: the planner had not reached
most of those cells.

## Purity discrepancy found by the pilot

The completed pilot was generated before a coordinate-consistency correction.
Its overall median absolute predicted-versus-achieved error was zero, mean
absolute error was 0.008192, maximum absolute error was 0.032258, and 55 of
133 condition medians were nonzero. All five requested-cell misses were final
purity-bin conditions predicted just above 0.98 but measured one material
column lower.

The cause was floating-point coordinate construction. `swsynth` builds its
grid with `linspace(0,L,N)`, while the predictor used `(index-1)*spacing`.
Those expressions can differ in the last bit at a strict grid-aligned `>`
interface. REQ-ML now evaluates candidate masks with the simulator's exact
`linspace` convention. A direct in-memory cross-repository check of an
89-pixel final-bin patch produced identical predicted and simulator truth
purity after the correction.

An earlier bootstrap preflight also exposed a small-window final-bin edge
case. The final coverage bin is `[0.98,1]`, not `[0.98,1)`, under MATLAB
`discretize`. When no sub-unity grid fraction exists, the corrected placement
uses the purity-1 limiting bilayer with the interface outside the patch.
No analytic placement was infeasible during the completed ten-iteration run.

## Angular direction-generation audit

### End-to-end path

REQ-ML materializes `direction_count`, `in_plane_count`, and `solid_angle_sr`
in `materializePhysicalConditions`. `physicalConditionToSwsynthRuns` writes
the condition seed plus these overrides to the generated campaign JSON. It
sets `directions.sampling_method="fibonacci"` but does not override the cap
axis. The bilayer base config supplies
`directions.support.axis_xyz=[1,0,0]`.

The simulation campaign executor resolves the config and calls
`swsynth.run`. That function calls `swsynth.generateDirections`, which uses
`swsynth.sampleSolidAngleDirections` for the cap. Projected-3D synthesis calls
`swsynth.propagation.projected3d.selectPropagatingDirections`; if filtering
requires a denser candidate set, it samples the same axis and support again
and applies deterministic farthest-point selection.

The cap is therefore always centered on the fixed **+x propagation axis**.
It is not randomly rotated per condition and is not rotated from the
condition seed. `generateDirections` initializes the random-number generator,
but the solid-angle Fibonacci branch contains no random draw. Directions
change deterministically when count, solid angle, or requested in-plane count
changes. The propagation convention states that `ux>0` enters from the left
and travels toward +x.

The MAT sample stores both requested and effective direction vectors in
`sample.requested_directions.xyz` and `sample.directions.xyz`. It also stores
the angular-support config, requested and retained plane-intersection metrics,
and the resolved config in provenance. The campaign CSV stores support type,
solid angle, requested in-plane count, retained in-plane count, and retained
fraction; it does not store the full vectors or cap axis.

### Meaning of `in_plane_count`

The REQ-ML approximation

```text
min(direction_count, max(1, round(sqrt(direction_count))))
```

is not metadata-only. The framework consumes it as the exact number of
directions constrained to the x-z observation plane (`uy=0`). The cap sampler
constructs that many plane directions, and projected-3D selection preserves
them while filling the remaining count with out-of-plane directions.
Consequently, the approximation changes the synthesized wavefield.

The generator and selector enforce exact-plane membership with
`abs(uy)<=1e-12`. `summarizePlaneIntersection` separately reports a post-hoc
count using its default `abs(uy)<=1e-6` tolerance; that summary is stored as
the retained count. Since the requested and effective vectors are stored, any
alternative definition can be recomputed.

A focused follow-up should replace the square-root policy with an explicit
scientific contract, without changing this completed pilot:

1. Define contractual in-plane directions as x-z-plane directions with a
   single shared numerical tolerance, preferably the generator's exact-plane
   tolerance.
2. If near-plane directions are scientifically useful, store a separate
   count defined by angular distance to the plane,
   `asin(abs(uy)) <= theta_tolerance`, and record `theta_tolerance`.
3. Select that angular tolerance from estimator sensitivity and observation
   geometry rather than from `sqrt(direction_count)`.
4. Persist exact and near-plane counts separately in MAT and campaign
   summaries.

No simulation-framework source change was required for this pilot or audit.

## Recommendation

Stop and revise rather than resume V3. The next controlled pilot should use a
new campaign identity, retain analytic bilayer targeting, and address examples
per requested cell—for example, four realizations per condition, deliberate
repeat scheduling until the four-example threshold is met, or traceable
multi-center packing only when one interface satisfies every packed request.
It should also start after the `linspace` purity correction and verify zero
prediction error before evaluating convergence.
