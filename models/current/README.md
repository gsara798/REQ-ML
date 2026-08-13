# Current REQ Q0 model

- Public name: **REQ Q0 model**
- Expected file: `model_bundle.mat`
- Internal provenance experiment: `homogeneous_cartesian_q0_v2`
- Internal model identifier: `homogeneous_cartesian_q0_bagged_v2_final_frozen`
- Supported `M`: 2 and 3
- Deployment `cs_guess`: 3 m/s
- Training SWS range: 1–4 m/s
- Training frequency range: 200–600 Hz
- Angular support: seven controlled regimes from near-directional caps to
  full-sphere diffuse support
- Freeze commit: `3397f185b27315e06f9bd8b798b091510caadb40`

Validation was approximately 2.16% MAPE in-domain, 3.04% for alternating-SWS
interpolation, 2.83% for alternating-angular interpolation, about 2% on
external homogeneous Eikonal cases, and about 3% on external homogeneous
k-Wave cases. M=3 was generally more stable than M=2.

Known limitations include mixed-material/interface patches, the limited scope
of external validation, and spatially localized k-Wave hotspot/outlier
structures. These hotspots did not dominate global homogeneous estimates.
The model is research software and is not intended for clinical decisions.
