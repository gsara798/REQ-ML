function result = evaluateBilayerPatchPurity( ...
    patch_size_pixels, patch_center_indices_xz, ...
    grid_spacing_m, interface_position_m, options)
%EVALUATEBILAYERPATCHPURITY Evaluate a discrete bilayer patch mask.
%
% Pixel indices are one-based [x,z]. When DomainSizeM is supplied, physical
% coordinates use the simulator's exact linspace(0,L,N) convention. The
% legacy fallback is x=(ix-1)*dx and z=(iz-1)*dz. The swsynth bilayer object
% occupies the strict positive side n dot [x,z] - interface_position_m > 0;
% material ID zero occupies the nonpositive side.

arguments
    patch_size_pixels (1,2) double {mustBeInteger, mustBePositive}
    patch_center_indices_xz (1,2) double {mustBeInteger, mustBePositive}
    grid_spacing_m (1,2) double {mustBePositive}
    interface_position_m (1,1) double {mustBeFinite}

    options.InterfaceOrientation (1,1) string = "x"
    options.DominantMaterialSide (1,1) string = "negative"
    options.DomainSizeM (1,2) double = [NaN NaN]
end

orientation = normalize_orientation(options.InterfaceOrientation);
dominant_side = normalize_dominant_side(options.DominantMaterialSide);

if any(mod(patch_size_pixels, 2) == 0)
    error("reqml:UnsupportedEvenPatchSupport", ...
        "REQ extraction uses a center pixel with symmetric inclusive " + ...
        "support, so analytic bilayer placement requires odd patch sizes.");
end

half_size = floor(patch_size_pixels / 2);
x_indices = (patch_center_indices_xz(1) - half_size(1)): ...
    (patch_center_indices_xz(1) + half_size(1));
z_indices = (patch_center_indices_xz(2) - half_size(2)): ...
    (patch_center_indices_xz(2) + half_size(2));

if all(isfinite(options.DomainSizeM))
    domain_size_pixels = round(options.DomainSizeM ./ grid_spacing_m) + 1;
    reconstructed_domain_m = ...
        (domain_size_pixels - 1) .* grid_spacing_m;

    if any(abs(reconstructed_domain_m - options.DomainSizeM) > ...
            64 * eps(max(options.DomainSizeM, grid_spacing_m)))
        error("reqml:UnsupportedBilayerCoordinateConvention", ...
            "Domain dimensions must be integer multiples of grid spacing.");
    end

    if max(x_indices) > domain_size_pixels(1) || ...
            max(z_indices) > domain_size_pixels(2)
        error("reqml:InvalidAnalyticBilayerPatchSupport", ...
            "Patch indices exceed the supplied domain dimensions.");
    end

    domain_x_m = linspace(0, options.DomainSizeM(1), domain_size_pixels(1));
    domain_z_m = linspace(0, options.DomainSizeM(2), domain_size_pixels(2));
    x_m = domain_x_m(x_indices);
    z_m = domain_z_m(z_indices);
else
    x_m = (x_indices - 1) * grid_spacing_m(1);
    z_m = (z_indices - 1) * grid_spacing_m(2);
end
[X, Z] = meshgrid(x_m, z_m);

switch orientation
    case "x"
        signed_distance_m = X - interface_position_m;
        normal_xz = [1 0];
        normal_angle_rad = 0;
    case "z"
        signed_distance_m = Z - interface_position_m;
        normal_xz = [0 1];
        normal_angle_rad = pi / 2;
end

material_patch = uint16(signed_distance_m > 0);

[purity, dominant_material_id] = ...
    reqml.datasets.computeMaterialPatchPurity( ...
        material_patch, true(size(material_patch)));

if dominant_side == "negative"
    requested_side_fraction = mean(material_patch == 0, "all");
    requested_side_material_id = 0;
else
    requested_side_fraction = mean(material_patch == 1, "all");
    requested_side_material_id = 1;
end

result = struct();
result.purity = purity;
result.dominant_material_id = dominant_material_id;
result.requested_side_fraction = requested_side_fraction;
result.requested_side_material_id = requested_side_material_id;
result.requested_side_is_dominant = ...
    requested_side_fraction >= 0.5;
result.material_patch = material_patch;
result.patch_x_indices = x_indices;
result.patch_z_indices = z_indices;
result.patch_x_m = x_m;
result.patch_z_m = z_m;
result.interface_orientation = orientation;
result.normal_xz = normal_xz;
result.normal_angle_rad = normal_angle_rad;
result.interface_position_m = interface_position_m;
result.dominant_material_side = dominant_side;

end


function orientation = normalize_orientation(value)

orientation = lower(strtrim(string(value)));

if ~ismember(orientation, ["x", "z"])
    error("reqml:UnsupportedBilayerCoordinateConvention", ...
        "InterfaceOrientation must be 'x' or 'z'.");
end

end


function side = normalize_dominant_side(value)

side = lower(strtrim(string(value)));

if ~ismember(side, ["negative", "positive"])
    error("reqml:InvalidBilayerDominantMaterialSide", ...
        "DominantMaterialSide must be 'negative' or 'positive'.");
end

end
