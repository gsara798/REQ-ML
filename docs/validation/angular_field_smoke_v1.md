# Randomized Angular Field End-to-End Validation

## Purpose

This validation confirms that the randomized angular-field policy is propagated through the complete REQ-ML simulation workflow:

1. physical-condition materialization;
2. adaptive batch planning;
3. swsynth campaign export;
4. simulation execution;
5. dataset construction;
6. requested-versus-achieved coverage auditing.

The previously completed `reqml_adaptive_scientific_4d_final` campaign was used only to audit adaptive scheduling and center packing. It predates the randomized angular-field policy and is not treated as the final scientific dataset.

## Validation configuration

Configuration:

`configs/validation/reqml_analytic_bilayer_angular_smoke_v1.json`

Policy:

- axis mode: `seeded_uniform_in_plane`;
- in-plane policy: `fixed_fraction`;
- in-plane fraction: `0.25`;
- conditions: 3;
- realizations per condition: 1.

The cap axis is sampled reproducibly in the observed x-z plane:

\[
\mathbf{a} =
[\cos(\alpha), 0, \sin(\alpha)].
\]

This retains exact compatibility with explicitly generated in-plane directions while removing the historical preferred +x orientation.

## Results

The end-to-end smoke completed successfully.

- conditions: 3;
- completed simulations: 3;
- generated patches: 3;
- requested-cell hits: 3/3;
- requested-cell hit rate: 1.0;
- unique angular axes: 3;
- maximum axis-norm error: 0;
- maximum out-of-plane component: 0;
- in-plane-count agreement: passed;
- angular audit acceptance: passed.

Predicted discrete purity ranged from 0.9351 to 0.9383. Achieved purity ranged from 0.9351 to 0.9383.

## Export audit

The three angular axes were present in both:

- `adaptive_batch_plan.json`;
- `simulation_campaign_bilayer.json`.

Exported axes:

```text
[ 0.8347287359345498, 0, -0.5506613636393138]
[-0.9421104466856082, 0,  0.3353027083783306]
[-0.9507569878298593, 0, -0.3099373325249683]

All exported axes were unit length, remained in the x-z plane, and were mutually distinct.

Conclusion

The randomized angular-field implementation is validated end to end. No simulation-framework modification was required because the existing framework already accepts arbitrary directions.support.axis_xyz overrides and explicit in-plane direction counts.

Future scientific campaigns using this policy must use a new campaign identifier and new output directories. They must not resume or overwrite campaigns generated with the historical fixed-axis policy.
