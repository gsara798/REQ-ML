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
