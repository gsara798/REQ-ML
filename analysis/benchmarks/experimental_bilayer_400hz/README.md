# Controlled experimental-bilayer estimator benchmark

Purpose: determine whether experimental bilayer bias is explained by local
window mixing, physical interface effects, adaptive-Q prediction, or estimator
assumptions using three clean 400 Hz k-Wave fields with exact truth. This is
not a training workflow and makes no claim that REQ-ML, theory-discrete REQ, or
AIA is intrinsically superior.

The runner consumes H_SOFT (1.74 m/s), H_STIFF (3.05 m/s), and a horizontal
bilayer with its exact interface at z=19 mm. Primary preprocessing is raw,
REQ-ML uses the frozen Q0 model with M=2 and step 1, and AIA uses its original
rectangular window/correlation/RSWE fit with M=2, step 2, 180 rotations, no
implicit decimation, and no smoothing. Comparisons use the intersection of
valid estimator centers.

No experimental fixed-q value was traceable with sufficient provenance. The
benchmark therefore reports the repository's prespecified `theory_discrete`
REQ mode and labels it explicitly; it does not relabel it as fixed-q.

Distance bins are 0–1, 1–3, 3–5, 5–8, and >8 mm. Window purity is computed
from the exact truth material mask over each estimator's actual odd window.
Generated outputs are intentionally ignored by Git.

If estimator tables are complete but figure export was interrupted, or only
the deterministic figures need refreshing, call `run_benchmark([], true)`.
This reloads the saved benchmark MAT and input samples without recomputing any
estimator.

## Completed clean benchmark

The completed analysis is written to
`outputs/benchmarks/experimental_bilayer_400hz_v1`. On the intersection of
valid estimator centers, frozen Q0 achieved 1.40% and 2.83% MAPE in the soft
and stiff homogeneous controls. In the bilayer it achieved 1.96% on the soft
side and 14.88% on the stiff side when all distances were pooled. The stiff
side error fell from 39.46% within 1 mm of the interface to 2.28% beyond 8 mm;
at exact window purity 1 its MAPE was 2.61%. This supports a finite-window and
interface-interaction explanation rather than an intrinsic homogeneous Q0
failure, while not separating those two mechanisms completely near the
interface.

Source-faithful AIA and theory-discrete REQ were already biased in the
homogeneous controls (9.04%/13.48% and 16.27%/24.44% MAPE for soft/stiff,
respectively). They are therefore comparison estimators here, not reference
truth. No fixed experimental q was guessed or tuned.
