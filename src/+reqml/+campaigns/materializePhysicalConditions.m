function conditions = materializePhysicalConditions(requests, options)
%MATERIALIZEPHYSICALCONDITIONS Convert abstract requests into physical conditions.
%
% This function is backend independent. It does not produce simulator paths
% or campaign overrides.
%
% Each output condition contains:
%
%   condition_id
%   realization_count
%   seed
%   geometry
%   material
%   wavefield
%   requested_coverage

arguments
    requests (:,1) struct

    options.DomainLxM (1,1) double = 0.05
    options.DomainLzM (1,1) double = 0.05

    options.BackgroundSwsRangeMPerS (1,2) double = [1.5 4.0]

    options.MinimumContrastMPerS (1,1) double = 0.5

    options.InclusionRadiusRangeM (1,2) double = [0.004 0.012]

    options.BilayerOffsetRangeM (1,2) double = [0.015 0.035]

    options.DirectionCounts (1,:) double = [1 16 32]

    options.InPlaneCounts (1,:) double = [1 4 8]

    options.SolidAnglesSr (1,:) double = ...
        [0.01 pi 4*pi]

    options.PlannerSeed (1,1) double = 1
end

validate_options(options);

if isempty(requests)
    conditions = repmat(empty_condition(), 0, 1);
    return
end

conditions = repmat( ...
    empty_condition(), ...
    numel(requests), ...
    1);

for index = 1:numel(requests)
    request = requests(index);

    validate_request(request);

    condition_seed = deterministic_seed( ...
        options.PlannerSeed, ...
        index);

    stream = RandStream( ...
        "Threefry", ...
        Seed=condition_seed);

    target_sws = sample_requested_value( ...
        stream, ...
        request.target_sws_range_m_s, ...
        options.BackgroundSwsRangeMPerS);

    frequency_hz = sample_requested_value( ...
        stream, ...
        request.target_frequency_range_hz, ...
        [200 600]);

    field = materialize_field( ...
        request.field_regime, ...
        options);

    [material, geometry] = materialize_geometry( ...
        stream, ...
        string(request.geometry_family), ...
        target_sws, ...
        frequency_hz, ...
        double(request.purity_range), ...
        options);

    condition = empty_condition();

    condition.condition_id = ...
        string(request.condition_id);

    condition.realization_count = ...
        double(request.realization_count);

    condition.seed = condition_seed;

    condition.geometry = geometry;
    condition.material = material;

    condition.wavefield.frequency_hz = ...
        frequency_hz;

    condition.wavefield.direction_count = ...
        field.direction_count;

    condition.wavefield.in_plane_count = ...
        field.in_plane_count;

    condition.wavefield.solid_angle_sr = ...
        field.solid_angle_sr;

    condition.requested_coverage = struct();

    condition.requested_coverage.purity_bin = ...
        double(request.purity_bin);

    condition.requested_coverage.purity_range = ...
        double(request.purity_range);

    condition.requested_coverage.diffusivity_bin = ...
        double(request.diffusivity_bin);

    condition.requested_coverage.diffusivity_range = ...
        double(request.diffusivity_range);

    condition.requested_coverage.deficit_score = ...
        double(request.deficit_score);

    conditions(index) = condition;
end

end


function [material, geometry] = materialize_geometry( ...
        stream, family, target_sws, frequency_hz, ...
        requested_purity_range, options)

material = struct();
geometry = struct();

material.background_cs_m_s = target_sws;
material.object_cs_m_s = NaN;

geometry.family = family;
geometry.radius_m = NaN;
geometry.center_xz_m = [NaN NaN];
geometry.normal_angle_rad = NaN;
geometry.offset_m = NaN;

switch family
    case "homogeneous"
        return

    case "bilayer"
        object_sws = sample_contrasting_sws( ...
            stream, ...
            target_sws, ...
            options);

        material.object_cs_m_s = object_sws;

        geometry.normal_angle_rad = ...
            2*pi*rand(stream);

        geometry.offset_m = ...
            materialize_bilayer_offset( ...
                stream, ...
                geometry.normal_angle_rad, ...
                target_sws, ...
                frequency_hz, ...
                requested_purity_range, ...
                options);

    case "circular_inclusion"
        object_sws = sample_contrasting_sws( ...
            stream, ...
            target_sws, ...
            options);

        material.object_cs_m_s = object_sws;

        radius_m = sample_uniform( ...
            stream, ...
            options.InclusionRadiusRangeM);

        margin_x = radius_m;
        margin_z = radius_m;

        center_x = sample_uniform( ...
            stream, ...
            [margin_x, options.DomainLxM - margin_x]);

        center_z = sample_uniform( ...
            stream, ...
            [margin_z, options.DomainLzM - margin_z]);

        geometry.radius_m = radius_m;
        geometry.center_xz_m = [center_x center_z];

    otherwise
        error("reqml:UnsupportedPhysicalGeometryFamily", ...
            "Unsupported geometry family '%s'.", ...
            family);
end

end


function offset_m = materialize_bilayer_offset( ...
        stream, normal_angle_rad, target_sws, frequency_hz, ...
        requested_purity_range, options)

domain_center = [
    options.DomainLxM / 2
    options.DomainLzM / 2
    ];

normal = [
    cos(normal_angle_rad)
    sin(normal_angle_rad)
    ];

center_projection_m = dot(normal, domain_center);

purity_range = double(requested_purity_range);

if numel(purity_range) ~= 2 || ...
        any(~isfinite(purity_range))

    purity_midpoint = 0.75;
else
    purity_midpoint = mean(purity_range);
end

purity_midpoint = min(max(purity_midpoint, 0.5), 1.0);

window_length_m = ...
    2 * target_sws / frequency_hz;

% Approximate the interface distance required to obtain the requested
% central-material fraction in a wavelength-scaled local patch.
interface_distance_m = ...
    (purity_midpoint - 0.5) * window_length_m;

side = 1;

if rand(stream) < 0.5
    side = -1;
end

offset_m = ...
    center_projection_m + ...
    side * interface_distance_m;

end


function field = materialize_field(regime, options)

switch string(regime)
    case "directional"
        index = 1;

    case "intermediate"
        index = min(2, numel(options.DirectionCounts));

    case "broad"
        index = numel(options.DirectionCounts);

    otherwise
        error("reqml:UnsupportedPhysicalFieldRegime", ...
            "Unsupported field regime '%s'.", ...
            regime);
end

field = struct();

field.direction_count = ...
    options.DirectionCounts(index);

field.in_plane_count = ...
    options.InPlaneCounts(index);

field.solid_angle_sr = ...
    options.SolidAnglesSr(index);

end


function value = sample_requested_value( ...
        stream, requested_range, fallback_range)

requested_range = double(requested_range);

if numel(requested_range) ~= 2 || ...
        any(~isfinite(requested_range))
    range = fallback_range;
else
    range = requested_range;
end

value = sample_uniform(stream, range);

end


function value = sample_contrasting_sws( ...
        stream, center_sws, options)

allowed = options.BackgroundSwsRangeMPerS;

candidate_ranges = [
    allowed(1), center_sws - options.MinimumContrastMPerS
    center_sws + options.MinimumContrastMPerS, allowed(2)
    ];

valid = candidate_ranges(:,2) > candidate_ranges(:,1);

if ~any(valid)
    error("reqml:CannotMaterializeSwsContrast", ...
        "Could not generate a contrasting material SWS.");
end

candidate_ranges = candidate_ranges(valid, :);

selection = randi( ...
    stream, ...
    size(candidate_ranges, 1));

value = sample_uniform( ...
    stream, ...
    candidate_ranges(selection, :));

end


function value = sample_uniform(stream, range)

range = double(range);

if numel(range) ~= 2 || ...
        any(~isfinite(range)) || ...
        range(2) < range(1)

    error("reqml:InvalidPhysicalSamplingRange", ...
        "Sampling ranges must contain two finite ordered values.");
end

if range(1) == range(2)
    value = range(1);
else
    value = range(1) + ...
        (range(2) - range(1)) * rand(stream);
end

end


function seed = deterministic_seed(planner_seed, ordinal)

seed = mod( ...
    double(planner_seed) * 1000003 + ...
    double(ordinal) * 9176, ...
    2^31 - 1);

seed = max(1, floor(seed));

end


function validate_request(request)

required = [
    "condition_id"
    "realization_count"
    "geometry_family"
    "field_regime"
    "target_sws_range_m_s"
    "target_frequency_range_hz"
    "purity_bin"
    "purity_range"
    "diffusivity_bin"
    "diffusivity_range"
    "deficit_score"
    ];

missing = setdiff( ...
    required, ...
    string(fieldnames(request)));

if ~isempty(missing)
    error("reqml:InvalidPhysicalConditionRequest", ...
        "Condition request is missing field '%s'.", ...
        missing(1));
end

end


function validate_options(options)

validate_range( ...
    options.BackgroundSwsRangeMPerS, ...
    "BackgroundSwsRangeMPerS");

validate_range( ...
    options.InclusionRadiusRangeM, ...
    "InclusionRadiusRangeM");

validate_range( ...
    options.BilayerOffsetRangeM, ...
    "BilayerOffsetRangeM");

if options.DomainLxM <= 0 || options.DomainLzM <= 0
    error("reqml:InvalidPhysicalMaterializerOption", ...
        "Domain dimensions must be positive.");
end

if options.MinimumContrastMPerS <= 0
    error("reqml:InvalidPhysicalMaterializerOption", ...
        "MinimumContrastMPerS must be positive.");
end

if numel(options.DirectionCounts) ~= ...
        numel(options.InPlaneCounts) || ...
        numel(options.DirectionCounts) ~= ...
        numel(options.SolidAnglesSr)

    error("reqml:InvalidPhysicalMaterializerOption", ...
        ["DirectionCounts, InPlaneCounts, and SolidAnglesSr " ...
         "must have equal lengths."]);
end

if any(options.DirectionCounts < 1) || ...
        any(options.DirectionCounts ~= fix(options.DirectionCounts))

    error("reqml:InvalidPhysicalMaterializerOption", ...
        "DirectionCounts must contain positive integers.");
end

if any(options.InPlaneCounts < 0) || ...
        any(options.InPlaneCounts ~= fix(options.InPlaneCounts)) || ...
        any(options.InPlaneCounts > options.DirectionCounts)

    error("reqml:InvalidPhysicalMaterializerOption", ...
        "InPlaneCounts must be valid nonnegative integers.");
end

end


function validate_range(range, name)

if numel(range) ~= 2 || ...
        any(~isfinite(range)) || ...
        range(2) <= range(1)

    error("reqml:InvalidPhysicalMaterializerOption", ...
        "%s must contain two finite increasing values.", ...
        name);
end

end


function condition = empty_condition()

condition = struct();

condition.condition_id = "";
condition.realization_count = 0;
condition.seed = 0;

condition.geometry = struct( ...
    "family", "", ...
    "radius_m", NaN, ...
    "center_xz_m", [NaN NaN], ...
    "normal_angle_rad", NaN, ...
    "offset_m", NaN);

condition.material = struct( ...
    "background_cs_m_s", NaN, ...
    "object_cs_m_s", NaN);

condition.wavefield = struct( ...
    "frequency_hz", NaN, ...
    "direction_count", NaN, ...
    "in_plane_count", NaN, ...
    "solid_angle_sr", NaN);

condition.requested_coverage = struct( ...
    "purity_bin", 0, ...
    "purity_range", [NaN NaN], ...
    "diffusivity_bin", 0, ...
    "diffusivity_range", [NaN NaN], ...
    "deficit_score", NaN);

end
