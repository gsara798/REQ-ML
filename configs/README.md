# Active configurations

This directory contains only configurations for the rebuilt reproducible
REQ-ML pipeline.

Historical configurations are preserved under:

```text
archive/legacy_v1/configs
```

New configuration files should be added only when they are consumed by active
package code and produce traceable outputs.

Validation and controlled scientific smoke configurations live under
`configs/validation`. They are not part of the adaptive training campaign.
The analytic bilayer smoke configuration is consumed by
`reqml.campaigns.runAnalyticBilayerSmokeTest`; the local geometry equivalence
configuration records the homogeneous, limiting-bilayer, and large-inclusion
controls used for separate scientific validation.

The V4 hybrid pilot configuration is
`adaptive/reqml_adaptive_scientific_4d_v4_analytic_bilayer_deficit_centers_pilot.json`.
It keeps the exact analytic target and enables truth-evaluated, deficit-aware
centers through `center_selection.mode`. Its outputs are isolated from V2 and
V3. See `docs/methodology/deficit_aware_bilayer_centers.md` for the selection
contract and `docs/methodology/analytic_bilayer_v4_deficit_center_pilot.md`
for the ten-iteration result.

The production configuration is
`adaptive/reqml_adaptive_scientific_4d_final.json`. It combines the guaranteed
analytic target with relationship-aware center separation, packing-aware
target placement, conditional domain expansion, and residual-deficit run
scheduling. Its first execution is limited to 15 iterations and uses a fresh
campaign identity and output paths. See
`docs/methodology/final_adaptive_dataset_generation.md` for the algorithm,
preflight evidence, and resume criteria.
