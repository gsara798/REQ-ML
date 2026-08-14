# SOURCE-X axial contact-position diagnostic

This controlled extension reuses the completed near-interface SOURCE-X bilayer result and runs Q0 only. The two new simulations change only the finite contact center z position. Homogeneous SOURCE-X references are reused from the completed source-polarization analysis.

```matlab
addpath("analysis/benchmarks/experimental_bilayer_400hz_source_zposition");
result = run_benchmark;
```

The runner refuses to overwrite an existing output directory. It uses the frozen Q0 model with `M=2` and `StepPixels=1`. AIA, theory-discrete, training, 3D, attenuation, noise and readout modeling are intentionally excluded.

Distance and purity labels come directly from `reqml.benchmarks.experimentalBilayer.buildPatchTable`, preserving the prior benchmark’s exact window convention and bins. Regions are the same truth-fixed soft-far, soft-near, stiff-near and stiff-far coordinates.
