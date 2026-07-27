# Stage C2: Projected Diffuse 3D Probe

Stage C2 tests whether Fibonacci-shell projected 3D diffuse fields produce a more isotropic x-z spectrum than the previous Stage C diffuse-like layouts. It uses no noise, no correction, and no estimability mask.

The runner uses the `eikonal3D_projected` phase model. In homogeneous media this is evaluated with the exact analytic 3D travel time; in heterogeneous media it uses the extruded 3D Eikonal solver. Representative predicted maps are intentionally blank outside valid REQ windows rather than extrapolated.

Outputs are written to `outputs/eikonal_validation/stage_c2_projected_diffuse3d_probe`.
