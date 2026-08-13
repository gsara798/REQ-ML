# Final adaptive scientific dataset generation

## Production policy

The production campaign uses analytic bilayers, a guaranteed analytic target,
relationship-aware opportunistic centers, and residual-deficit scheduling. It
is configured by
`configs/adaptive/reqml_adaptive_scientific_4d_final.json` with campaign ID
`reqml_adaptive_scientific_4d_final`. Legacy center selection, analytic-only
selection, and the V4 uniform-separation hybrid remain unchanged.

The analytic target is always selected first. For resolved odd REQ window
width `W`, every later center must satisfy the following Euclidean distances:

```text
distance(target, opportunistic)              >= 0.25 W
distance(different-cell opportunistic pair)  >= 0.25 W
distance(same-cell opportunistic pair)       >= 0.50 W
```

The selector retains at most 12 centers per run, at most two opportunistic
centers per cell per run, a two-pixel candidate step, and a valid-mask
fraction of one. All candidate cells are computed from the discrete truth
mask and the frozen pre-iteration coverage state. Multiple patches from one
run remain one independent run and one independent condition.

## Packing-aware analytic placement

Let `h = (W - 1) / 2`. The legal center interval on each axis is the closed
integer interval remaining after the half-window and configured margin are
removed. The interface-normal coordinate is placed deterministically at the
domain center. The interface-tangential coordinate is placed at the low end
of its legal interval, leaving the largest contiguous tangential packing
span on one side of the target.

The interface placement is then recomputed from this selected center. Thus
the signed center-to-interface distance remains the discrete offset selected
for the requested purity. A future normal displacement would translate the
interface with the center; the current edge-aware strategy changes only the
tangential coordinate, for which a planar interface needs no physical
translation. The achieved purity is still evaluated on the exact discrete
support before the condition is accepted.

For target-to-opportunistic separation `s = 0.25 W`, the geometric packing
capacity along the available tangential span `S` is

```text
Nmax = 1 + floor(S / s).
```

The persisted control metadata records the chosen center, strategy, span,
resolved window, selected domain, expansion decision, and `Nmax`.

## Conditional domain policy

The default physical domain is `0.05 m x 0.05 m`. The helper first evaluates
that domain at the bilayer grid spacing. It selects `0.07 m x 0.07 m` only
when the default cannot geometrically hold the analytic target plus one
additional potentially useful center. If the expanded domain also cannot
meet the configured minimum, materialization fails rather than silently
changing the requested physical cell.

This decision is a property of the physical condition and does not change
when later realizations reuse its `condition_id`. That invariance is required
because a repeated condition must preserve its material, wavefield, geometry,
and domain. The opportunistic selector itself accepts only centers mapped to
cells deficient in the frozen pre-iteration state.

## Residual-deficit scheduling

For every requested cell the planner persists residual example, independent-
run, and independent-condition deficits. It then applies:

1. A condition deficit, or no prior analytic condition for the cell, creates
   a newly materialized `condition_id`. Two base realizations are used, or
   more if the independent-run deficit is larger. The action is
   `new_condition` or `combined`.
2. A run deficit with an existing condition reuses that `condition_id` and
   starts after its greatest prior realization index. Every new realization
   receives a new design/run ID and a deterministic distinct simulation seed.
   The action is `additional_realization` or `combined`.
3. An example-only deficit retains opportunistic extraction and requests the
   number of realizations estimated to close the remaining example count. The
   action is `opportunistic_examples`.
4. A complete cell is absent from the deficit table and is never directly
   requested.

New condition IDs produce stable, condition-specific physical seeds, so a
new condition is rematerialized rather than being an identical condition
renamed. Repeated condition IDs reproduce the same physical values while
their increasing realization indices change the simulation seeds.

## Fifteen-iteration production preflight

The clean preflight completed 15 iterations in 237.46 seconds. It accumulated
386 runs and 2,768 examples. Requested-cell hit rate was `1.0` in every
iteration, median and maximum predicted-versus-achieved analytic purity error
were zero, and no analytic target cell mismatch occurred.

| Iteration | Runs | Examples | Examples/run | Observed | Complete | Deficient |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 50 | 450 | 9.00 | 92 | 67 | 433 |
| 2 | 74 | 556 | 7.51 | 116 | 84 | 416 |
| 3 | 98 | 704 | 7.18 | 142 | 103 | 397 |
| 4 | 122 | 968 | 7.93 | 180 | 138 | 362 |
| 5 | 146 | 1,256 | 8.60 | 224 | 178 | 322 |
| 6 | 170 | 1,544 | 9.08 | 277 | 219 | 281 |
| 7 | 194 | 1,650 | 8.51 | 296 | 238 | 262 |
| 8 | 218 | 1,800 | 8.26 | 317 | 266 | 234 |
| 9 | 242 | 1,980 | 8.18 | 337 | 289 | 211 |
| 10 | 266 | 2,156 | 8.11 | 355 | 309 | 191 |
| 11 | 290 | 2,258 | 7.79 | 372 | 326 | 174 |
| 12 | 314 | 2,412 | 7.68 | 388 | 343 | 157 |
| 13 | 338 | 2,550 | 7.54 | 410 | 366 | 134 |
| 14 | 362 | 2,650 | 7.32 | 427 | 386 | 114 |
| 15 | 386 | 2,768 | 7.17 | 440 | 400 | 100 |

At the equal ten-iteration, 266-run boundary, V4 had 764 examples, 223
observed cells, and 398 deficient cells. The final policy had 2,156 examples,
355 observed cells, and 191 deficient cells. This is 2.82 times as many
examples at the same run count and 207 fewer deficient cells.

Twenty-seven of 193 materialized conditions (14.0%) used the expanded domain.
Every expanded condition had a resolved window from 81 through 91 pixels;
every 31-through-79-pixel condition retained the normal domain. Independence
recomputation from unique run and condition IDs matched the coverage table in
all 15 iterations.

The preflight contained 25 bootstrap `new_condition` actions and 168
`combined` actions. All 386 runs belonged to newly materialized conditions,
because the remaining never-observed cells still had condition deficits and
therefore ranked ahead of repeat-only deficits. The additional-realization
path was not exercised by this finite preflight; focused tests verify stable
condition reuse, increasing realization IDs, and distinct seeds.

The hardest remaining groups are SWS `[3.5,4]` (57 deficient, 49 never
observed), purity `[0.9,0.98)` (32 deficient), and frequency `[199,250)` (26
deficient). There were no requested-cell misses. The campaign is safe to
resume by setting `resume_existing_loop` to `true` and increasing only
`maximum_iterations`. The first resumed audit should confirm the transition
from new-condition actions to actual additional-realization actions before a
long unattended run is approved.

## Audit artifacts

`reqml.analysis.auditFinalAdaptiveCampaign` writes:

- `final_iteration_progress.csv`;
- `final_center_yield.csv`;
- `final_residual_deficit_actions.csv`;
- `final_domain_expansion_summary.csv`;
- `final_independence_audit.csv`; and
- `final_difficulty_by_dimension.csv`.

Generated campaign data, audit CSV files, MAT files, logs, and parallel-job
storage are runtime artifacts and are intentionally excluded from Git.
