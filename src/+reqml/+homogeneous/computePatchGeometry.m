function geometry = computePatchGeometry( ...
        frequency_hz, dx_m, dz_m, options)
%COMPUTEPATCHGEOMETRY Resolve exact REQ window, stride, and domain size.

arguments
    frequency_hz (1,1) double {mustBePositive}
    dx_m (1,1) double {mustBePositive}
    dz_m (1,1) double {mustBePositive}
    options.M (1,1) double {mustBePositive} = 2
    options.CsGuessMPerS (1,1) double {mustBePositive} = 3
    options.MinimumStridePixels (1,1) double {mustBeInteger,mustBePositive} = 4
    options.StrideWindowFraction (1,1) double {mustBePositive} = 0.5
    options.MinimumPlacementsPerAxis (1,1) double ...
        {mustBeInteger,mustBePositive} = 10
end

feat_cfg=reqml.config.default_feature_config( ...
    "M",options.M,"cs_guess",options.CsGuessMPerS);
physical_cfg=struct("f0",frequency_hz,"cs_bg",options.CsGuessMPerS, ...
    "dx",dx_m,"dz",dz_m);
[~,resolved]=reqml.config.default_req_config(physical_cfg,feat_cfg);
win=double(resolved.win_size);
stride=max(double(options.MinimumStridePixels), ...
    ceil(options.StrideWindowFraction*win));
placements=double(options.MinimumPlacementsPerAxis);
nx=win+(placements-1)*stride;
nz=win+(placements-1)*stride;

geometry=struct();
geometry.patch_width_px=win;
geometry.patch_height_px=win;
geometry.stride_x_px=stride;
geometry.stride_z_px=stride;
geometry.domain_points_x=nx;
geometry.domain_points_z=nz;
geometry.domain_x_m=(nx-1)*dx_m;
geometry.domain_z_m=(nz-1)*dz_m;
geometry.available_patch_count=placements^2;
geometry.minimum_placements_per_axis=placements;
geometry.linear_overlap_fraction=max(0,(win-stride)/win);
geometry.M=double(options.M);
geometry.cs_guess_m_s=double(options.CsGuessMPerS);
end
