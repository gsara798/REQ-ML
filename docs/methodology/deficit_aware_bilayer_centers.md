# Deficit-aware centers for analytic bilayer training

## Purpose

The hybrid center mode preserves the exact analytic bilayer target while
using otherwise-idle spatial support in the same truth map to extract patches
for additional deficient coverage cells. It is enabled explicitly with:

```json
"center_selection": {
  "mode": "analytic_target_plus_deficit_aware_centers",
  "candidate_step_pixels": 2,
  "maximum_centers_per_run": 12,
  "maximum_centers_per_cell_per_run": 2,
  "minimum_center_separation_fraction": 0.75
}
```

Legacy directed selection and analytic-target-only extraction remain
available. The option does not alter global geometry support, the REQ
estimator, feature definitions, or coverage edges.

## Frozen pre-iteration state

Iteration `k` uses the complete coverage table saved after iteration `k-1`.
For iteration one, every cell in the configured four-dimensional grid starts
with zero counts. The immutable table contains, for every cell,

- example, independent-run, and independent-condition counts;
- their required counts and remaining deficits;
- the aggregate deficit score; and
- the pre-iteration completion flag.

This snapshot is created once before sample processing. All serial or
`parfor` workers read the same table. Workers never update shared coverage
state while selecting centers, so selection is deterministic and independent
of worker scheduling.

## Candidate classification

Let the odd REQ window width be `W = 2h + 1`. A candidate center `(cx,cz)`
uses exactly the support

```text
x = cx-h : cx+h
z = cz-h : cz+h
```

Candidates are enumerated on the truth grid with the configured pixel step.
The analytic target is inserted first even when it is not on that grid. A
candidate is eligible only when the complete support is inside the domain,
its valid-mask fraction meets the configured threshold, and its actual truth
values map to a valid cell in

```text
(local SWS, frequency, material purity, nominal angular coverage).
```

Material purity is evaluated by `computeMaterialPatchPurity` on the actual
discrete material mask. Local SWS is the truth SWS at the center pixel.
Frequency and nominal angular coverage are condition-level quantities. No
requested label is assigned before this truth evaluation.

## Selection policy

The analytic target is always rank one and has role `analytic_target`. A
target-cell mismatch is recorded and never hidden by an opportunistic patch.
Remaining candidates may receive role `opportunistic_deficit_fill` only when
their truth-evaluated cell was deficient in the frozen pre-iteration state.

Eligible candidates are ordered lexicographically by:

1. remaining independent-run deficit;
2. remaining independent-condition deficit;
3. remaining example deficit;
4. aggregate deficit score;
5. never-observed status;
6. distance to already selected centers; and
7. a deterministic hash of center indices and condition seed.

The default limits are 12 total centers per run, at most two useful centers
per cell per run, and Euclidean center separation of at least `0.75 W` pixels.
The useful per-cell quota accounts for two realizations per condition. The
limits control redundant overlapping patches; they do not create additional
independent simulations.

## Independence semantics

Every selected patch retains the original simulation `run_id` and
`condition_id`. Consequently:

- many centers from one run contribute many examples but one independent run;
- two realizations of one condition contribute two independent runs but one
  independent condition; and
- opportunistic centers never manufacture run or condition independence.

This is enforced by the existing coverage aggregation over unique campaign
identifiers rather than by the center selector.

## Audit metadata

Each selected example records its role, rank, center indices and physical
coordinates, achieved cell key, requested condition cell key, actual discrete
purity, analytic predicted purity when applicable, distance to the bilayer
interface, distance to the nearest selected center, and all pre-iteration
counts and deficits for its achieved cell. Per-run summaries aggregate center
counts and rejection reasons.

`reqml.analysis.auditDeficitAwarePilot` writes per-iteration progress,
center-selection, selected-center, rejection, pre-state,
requested-versus-achieved, and V2/V3/V4 equal-iteration comparison tables.
Predicted-versus-achieved analytic purity is evaluated on the analytic target
only. Opportunistic patches remain in the condition-wide purity range but do
not mask an analytic-target miss.

## Resume behavior

A clean pilot starts with `resume_existing_loop=false`. Once it is complete,
the same campaign can be resumed by changing only that option to `true` and
raising `maximum_iterations`. The final prior coverage report becomes the
next frozen pre-iteration state. Center choice remains reproducible from the
condition seed and configuration. A scientific resume should nevertheless be
approved from convergence and rejection results, not merely from technical
resume capability.
