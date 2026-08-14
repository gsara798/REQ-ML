# Controlled source-polarization benchmark

This analysis compares the frozen SOURCE-Z control with a SOURCE-X finite-contact excitation while every other simulation setting remains fixed. Both cases are observed through `Uz`; `Ux` is retained as a diagnostic control. The simulation domain is wider than the common 38 mm x 35.8625 mm analysis FOV, and the source contact remains outside that FOV.

Run from MATLAB with:

```matlab
addpath("src");
run_benchmark("configs/benchmarks/experimental_bilayer_400hz_source_polarization.json");
```

The runner consumes the six already completed simulation results. It does not simulate or train. It checkpoints after each condition, and refuses to overwrite a completed result set.

## AIA display convention

AIA remains evaluated on its native `StepPixels=2` regular grid. Figures reconstruct that grid and use `imagesc`, exactly as for REQ maps. No interpolation, smoothing, duplicated pixels, or metric changes are applied. The earlier point-like appearance was caused by scatter rendering, not by a different physical map definition.

## Spectral conventions

Regions are fixed by truth coordinates before estimation. Radial curves reuse the REQ feature spectrum. A “prominent peak” is a local maximum after a three-bin moving mean whose height is at least 20% of the curve maximum; this simple deterministic diagnostic is not used by any estimator.

Experimental paths in the config are optional, external, and read-only. The generated registry keeps RAW and donut inputs separate. The clean simulated benchmark does not depend on them.

## Frozen training-domain audit

The Q0 v2 training fields were projected-3D Eikonal direction ensembles. Each direction used a reproducibly sampled transverse polarization, while the stored estimator field was the scalar axial component `Uz`. Polarization vectors were retained as provenance, but vector `Ux/Uz` wavefields were not stored. Consequently, the training set did not contain a fixed finite contact driven in X and observed only through Uz. This absence is a candidate domain-shift mechanism; it is not, by itself, evidence that it causes an experimental error.

## Optional experimental comparison

The configuration records user-provided Feb27 sample paths and the runner writes a read-only availability/preprocessing registry. The homogeneous established products are donut-filtered; the bilayer registry keeps RAW and donut samples distinct. Normalized-shape comparison is intentionally secondary and is not used to tune the simulated source, domain, or estimators.
