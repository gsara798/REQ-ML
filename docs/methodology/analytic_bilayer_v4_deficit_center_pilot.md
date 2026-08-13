# Analytic bilayer V4 deficit-center pilot

## Configuration and runtime

The clean V4 pilot used campaign identity
`reqml_adaptive_scientific_4d_v4_analytic_bilayer_deficit_centers_pilot`.
It ran the complete 500-cell scientific grid for 10 iterations with at most
12 conditions per adaptive batch, two realizations per condition, analytic
bilayer geometry, process-parallel sample extraction, and the hybrid center
policy documented in `deficit_aware_bilayer_centers.md`.

All ten iterations completed in 134.45 seconds. The pilot accumulated 266
runs and 764 examples. It observed 223 cells and left 398 deficient cells.
There were no analytic placement infeasibilities, target-cell mismatches,
exact-center extraction failures, simulation failures, or invalid truth
patches.

## Per-iteration convergence

| Iteration | Runs | Examples | Observed | Deficient | Target hit rate | Opportunistic centers |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 50 | 202 | 48 | 472 | 1.00 | 152 |
| 2 | 74 | 226 | 60 | 472 | 1.00 | 0 |
| 3 | 98 | 250 | 72 | 472 | 1.00 | 0 |
| 4 | 122 | 274 | 84 | 472 | 1.00 | 0 |
| 5 | 146 | 362 | 109 | 459 | 1.00 | 64 |
| 6 | 170 | 478 | 137 | 438 | 1.00 | 92 |
| 7 | 194 | 642 | 179 | 409 | 1.00 | 140 |
| 8 | 218 | 716 | 199 | 398 | 1.00 | 50 |
| 9 | 242 | 740 | 211 | 398 | 1.00 | 0 |
| 10 | 266 | 764 | 223 | 398 | 1.00 | 0 |

The 266 analytic targets were all in their requested four-dimensional cells.
Their median and maximum absolute predicted-versus-achieved discrete purity
errors were both zero in every iteration. The selector added 498
opportunistic centers. These contributed to 123 newly observed cells and all
102 cells that became complete during the pilot.

## Equal-budget comparison

All three campaigns had 266 accumulated runs at iteration 10:

| Campaign | Examples | Observed cells | Deficient cells | Iteration-10 target hit rate |
|---|---:|---:|---:|---:|
| V2 mixed geometry | 1,131 | 210 | 375 | 0.00 |
| V3 analytic target only | 266 | 128 | 496 | 1.00 |
| V4 hybrid analytic | 764 | 223 | 398 | 1.00 |

V4 substantially improves on V3 and observes more cells than V2. It does not
reduce deficient cells faster than V2 at ten iterations: V4 leaves 398 versus
375 for V2. Therefore execution success alone does not justify a long
unchanged resume.

## Remaining difficulty

The final audit reports 398 difficult cells, 277 never-observed cells, 296
stagnant cells, and zero requested-but-never-hit cells. The largest dimension
counts are:

- frequency `[199,250)`: 100 difficult cells, 57 never observed;
- frequency `[250,350)`: 100 difficult cells, 65 never observed;
- purity `[0.5,0.7)`: 110 difficult cells, 74 never observed;
- purity `[0.9,0.98)`: 105 difficult cells, 71 never observed;
- nominal angular coverage `[0.05,0.2)`: 87 difficult cells;
- SWS `[2,2.5)`: 93 difficult cells; and
- SWS `[2.5,3)`, `[3,3.5)`, and `[3.5,4]`: 82, 82, and 80 difficult cells.

The first SWS bin is comparatively well observed; the other material side of
the bilayer remains the main SWS limitation.

## Separation bottleneck

Iterations 2--4 and 9--10 planned mostly low-frequency conditions with window
widths of 53--91 pixels. Their centered analytic target and the current
101-pixel domain leave too little legal center-to-center distance to satisfy
the fixed `0.75 W` threshold. Those iterations selected only the analytic
target. In contrast, iterations 5--8 included widths down to 31--43 pixels
and supplied nearly all opportunistic completion gains.

This is not an analytic-purity failure. It is a packing constraint caused by
large low-frequency windows in the unchanged domain. The rejection audit
also shows no invalid-mask or out-of-grid failures. Rejection counts in this
pilot are decision-event counts evaluated during greedy selection, not unique
candidate counts, so their magnitude must not be interpreted as a population
size.

## Recommendation

The campaign is technically safe to resume: the loop state, final coverage
report, dataset, and campaign outputs are complete. Do not resume V4 unchanged
to a long limit. First run a new short controlled pilot that preserves the
analytic target and independence semantics but studies a scientifically
justified low-frequency separation policy. Candidate options are to apply
the `0.75 W` rule only between opportunistic centers, or to use a bounded
window-overlap/novel-cell criterion when the domain makes `0.75 W`
geometrically impossible. Do not enlarge every simulation domain without a
separate cost and boundary-margin study.
