function placement = computeBilayerInterfacePlacement( ...
    requested_purity_range, patch_size_pixels, ...
    grid_spacing_m, selected_patch_center_indices_xz, ...
    domain_size_m, options)
%COMPUTEBILAYERINTERFACEPLACEMENT Place a grid-aligned bilayer interface.
%
% The continuous initial estimate is d=(p-0.5)*Lwin. Every legal integer
% interface position is then evaluated using the exact discrete patch mask
% and REQ-ML modal material fraction. Intervals are half-open except for a
% final upper edge of one, matching MATLAB discretize: [lower,1]. Any
% candidate with purity one requires the interface to lie at least one grid
% interval outside the patch support. A degenerate range [1,1] explicitly
% requests that limiting bilayer case.

arguments
    requested_purity_range (1,2) double
    patch_size_pixels (1,2) double {mustBeInteger, mustBePositive}
    grid_spacing_m (1,2) double {mustBePositive}
    selected_patch_center_indices_xz (1,2) double ...
        {mustBeInteger, mustBePositive}
    domain_size_m (1,2) double {mustBePositive}

    options.InterfaceOrientation (1,1) string = "x"
    options.DominantMaterialSide (1,1) string = "negative"
    options.MinimumDomainMarginPixels (1,1) double ...
        {mustBeInteger, mustBeNonnegative} = 0
end

validate_requested_range(requested_purity_range);

if any(mod(patch_size_pixels, 2) == 0)
    error("reqml:UnsupportedEvenPatchSupport", ...
        "REQ extraction uses a center pixel with symmetric inclusive " + ...
        "support, so analytic bilayer placement requires odd patch sizes.");
end

orientation = lower(strtrim(options.InterfaceOrientation));
dominant_side = lower(strtrim(options.DominantMaterialSide));

if ~ismember(orientation, ["x", "z"])
    error("reqml:UnsupportedBilayerCoordinateConvention", ...
        "InterfaceOrientation must be 'x' or 'z'.");
end

if ~ismember(dominant_side, ["negative", "positive"])
    error("reqml:InvalidBilayerDominantMaterialSide", ...
        "DominantMaterialSide must be 'negative' or 'positive'.");
end

domain_size_pixels = round(domain_size_m ./ grid_spacing_m) + 1;
reconstructed_domain_m = ...
    (domain_size_pixels - 1) .* grid_spacing_m;

if any(abs(reconstructed_domain_m - domain_size_m) > ...
        64 * eps(max(domain_size_m, grid_spacing_m)))
    error("reqml:UnsupportedBilayerCoordinateConvention", ...
        "Domain dimensions must be integer multiples of grid spacing.");
end

half_size = floor(patch_size_pixels / 2);
patch_min_indices = selected_patch_center_indices_xz - half_size;
patch_max_indices = selected_patch_center_indices_xz + half_size;
margin = options.MinimumDomainMarginPixels;

if any(patch_min_indices < 1 + margin) || ...
        any(patch_max_indices > domain_size_pixels - margin)
    error("reqml:AnalyticBilayerInsufficientDomainMargin", ...
        "The complete REQ patch does not fit inside the domain with " + ...
        "MinimumDomainMarginPixels=%d.", margin);
end

if orientation == "x"
    axis_index = 1;
else
    axis_index = 2;
end

axis_spacing_m = grid_spacing_m(axis_index);
center_axis_index = selected_patch_center_indices_xz(axis_index);
patch_min_axis_index = patch_min_indices(axis_index);
patch_max_axis_index = patch_max_indices(axis_index);
domain_axis_count = domain_size_pixels(axis_index);

target_purity = mean(requested_purity_range);
exact_purity_one = all(requested_purity_range == 1);

if exact_purity_one
    target_purity = 1;

    if dominant_side == "negative"
        candidate_indices = (patch_max_axis_index + 1): ...
            (domain_axis_count - margin);
    else
        candidate_indices = (1 + margin): ...
            (patch_min_axis_index - 1);
    end

    if isempty(candidate_indices)
        error("reqml:AnalyticBilayerInsufficientDomainMargin", ...
            "Purity 1 requires a legal grid-aligned interface outside " + ...
            "the patch support on the requested dominant side.");
    end
else
    candidate_indices = (1 + margin):(domain_axis_count - margin);
end

if dominant_side == "negative"
    interface_outside_dominant_patch = ...
        candidate_indices > patch_max_axis_index;
else
    interface_outside_dominant_patch = ...
        candidate_indices < patch_min_axis_index;
end

% swsynth constructs coordinates with linspace(0,L,N). Use that exact
% floating-point convention because a grid-aligned strict interface can
% otherwise classify its boundary pixel differently from (index-1)*dx.
axis_coordinates_m = linspace( ...
    0, domain_size_m(axis_index), domain_axis_count);
candidate_positions_m = axis_coordinates_m(candidate_indices);
candidate_purity = NaN(size(candidate_indices));
candidate_side_fraction = NaN(size(candidate_indices));

for index = 1:numel(candidate_indices)
    evaluated = reqml.campaigns.evaluateBilayerPatchPurity( ...
        patch_size_pixels, ...
        selected_patch_center_indices_xz, ...
        grid_spacing_m, ...
        candidate_positions_m(index), ...
        InterfaceOrientation=orientation, ...
        DominantMaterialSide=dominant_side, ...
        DomainSizeM=domain_size_m);

    candidate_purity(index) = evaluated.purity;
    candidate_side_fraction(index) = ...
        evaluated.requested_side_fraction;
end

if exact_purity_one
    feasible = candidate_purity == 1 & ...
        candidate_side_fraction == 1 & ...
        interface_outside_dominant_patch;
else
    upper_edge_match = ...
        candidate_purity < requested_purity_range(2);

    if requested_purity_range(2) == 1
        upper_edge_match = upper_edge_match | ...
            (candidate_purity == 1 & ...
             interface_outside_dominant_patch);
    end

    feasible = ...
        candidate_purity >= requested_purity_range(1) & ...
        upper_edge_match & ...
        candidate_side_fraction >= 0.5;
end

if ~any(feasible)
    closing_bracket = ")";
    if requested_purity_range(2) == 1
        closing_bracket = "]";
    end

    error("reqml:AnalyticBilayerNoDiscreteOffset", ...
        "No legal grid-aligned bilayer interface produces purity in " + ...
        "[%g,%g%s for the requested patch support.", ...
        requested_purity_range(1), requested_purity_range(2), ...
        closing_bracket);
end

window_length_m = ...
    patch_size_pixels(axis_index) * axis_spacing_m;
continuous_distance_m = ...
    (target_purity - 0.5) * window_length_m;

if dominant_side == "negative"
    continuous_signed_offset_m = continuous_distance_m;
else
    continuous_signed_offset_m = -continuous_distance_m;
end

center_position_m = axis_coordinates_m(center_axis_index);
continuous_position_m = ...
    center_position_m + continuous_signed_offset_m;
rounded_position_index = ...
    round(continuous_position_m / axis_spacing_m) + 1;

feasible_indices = find(feasible);
score = [ ...
    abs(candidate_purity(feasible) - target_purity).', ...
    abs(candidate_indices(feasible).' - rounded_position_index), ...
    candidate_indices(feasible).' ...
    ];
[~, order] = sortrows(score, [1 2 3]);
selected_candidate = feasible_indices(order(1));

interface_grid_index = candidate_indices(selected_candidate);
interface_position_m = candidate_positions_m(selected_candidate);

evaluated = reqml.campaigns.evaluateBilayerPatchPurity( ...
    patch_size_pixels, ...
    selected_patch_center_indices_xz, ...
    grid_spacing_m, ...
    interface_position_m, ...
    InterfaceOrientation=orientation, ...
    DominantMaterialSide=dominant_side, ...
    DomainSizeM=domain_size_m);

interface_offset_pixels = ...
    interface_grid_index - center_axis_index;
interface_offset_m = ...
    interface_position_m - center_position_m;

placement = struct();
placement.feasible = true;
placement.geometry_control_mode = "analytic_bilayer";
placement.requested_purity_range = requested_purity_range;
placement.target_purity = target_purity;
placement.achieved_discrete_purity = evaluated.purity;
placement.predicted_discrete_purity = evaluated.purity;
placement.interface_offset_pixels = interface_offset_pixels;
placement.interface_offset_m = interface_offset_m;
placement.interface_position_m = interface_position_m;
placement.interface_grid_index = interface_grid_index;
placement.interface_orientation = orientation;
placement.normal_angle_rad = evaluated.normal_angle_rad;
placement.dominant_material_side = dominant_side;
placement.selected_patch_center_indices_xz = ...
    selected_patch_center_indices_xz;
x_coordinates_m = linspace( ...
    0, domain_size_m(1), domain_size_pixels(1));
z_coordinates_m = linspace( ...
    0, domain_size_m(2), domain_size_pixels(2));
placement.selected_patch_center_m = [ ...
    x_coordinates_m(selected_patch_center_indices_xz(1)), ...
    z_coordinates_m(selected_patch_center_indices_xz(2))];
placement.patch_size_pixels = patch_size_pixels;
placement.patch_min_indices_xz = patch_min_indices;
placement.patch_max_indices_xz = patch_max_indices;
placement.grid_spacing_m = grid_spacing_m;
placement.domain_size_m = domain_size_m;
placement.domain_size_pixels = domain_size_pixels;

placement.diagnostics = struct();
placement.diagnostics.continuous_window_length_m = ...
    window_length_m;
placement.diagnostics.continuous_interface_distance_m = ...
    continuous_distance_m;
placement.diagnostics.continuous_interface_position_m = ...
    continuous_position_m;
placement.diagnostics.analytically_rounded_grid_index = ...
    rounded_position_index;
placement.diagnostics.candidate_count = numel(candidate_indices);
placement.diagnostics.feasible_candidate_count = nnz(feasible);
placement.diagnostics.minimum_domain_margin_pixels = margin;
placement.diagnostics.patch_support_is_inside_domain = true;
placement.diagnostics.interface_is_outside_patch_support = ...
    interface_grid_index < patch_min_axis_index || ...
    interface_grid_index > patch_max_axis_index;
placement.diagnostics.requested_upper_edge_is_inclusive = ...
    requested_purity_range(2) == 1;
placement.diagnostics.coordinate_convention = ...
    "one_based_indices; coordinate_m=linspace(0,L,N); positive_side_is_strict";

end


function validate_requested_range(range)

if any(~isfinite(range)) || ...
        range(1) < 0.5 || ...
        range(2) > 1 || ...
        range(2) < range(1) || ...
        (range(1) == range(2) && range(1) ~= 1)
    error("reqml:InvalidAnalyticBilayerPurityRange", ...
        "requested_purity_range must be an ordered range within " + ...
        "[0.5,1], with a degenerate range allowed only for [1,1].");
end

end
