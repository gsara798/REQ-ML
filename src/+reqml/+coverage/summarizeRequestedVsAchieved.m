function summary = summarizeRequestedVsAchieved( ...
    assigned_examples, adaptive_batch_plan)
%SUMMARIZEREQUESTEDVSACHIEVED Compare planned and measured patch coverage.
%
% Inputs
% ------
% assigned_examples:
%   Patch table after reqml.coverage.assignCoverageBins, containing:
%     campaign_condition_id
%     coverage_valid
%     coverage_purity_bin
%     coverage_diffusivity_bin
%     truth_material_purity
%     campaign_angular_entropy
%
% adaptive_batch_plan:
%   Either:
%     - path to adaptive_batch_plan.json, or
%     - decoded scalar plan struct.
%
% Output
% ------
% One table row per planned physical condition.

arguments
    assigned_examples table
    adaptive_batch_plan
end

plan = resolve_plan(adaptive_batch_plan);
validate_examples(assigned_examples);

if ~isfield(plan, "physical_conditions")
    error("reqml:InvalidAdaptiveBatchPlan", ...
        "Adaptive batch plan is missing physical_conditions.");
end

conditions = plan.physical_conditions;

if isempty(conditions)
    summary = empty_summary_table();
    return
end

condition_count = numel(conditions);

condition_id = strings(condition_count, 1);
geometry_family = strings(condition_count, 1);

requested_purity_bin = zeros(condition_count, 1);
requested_diffusivity_bin = zeros(condition_count, 1);

requested_purity_lower = NaN(condition_count, 1);
requested_purity_upper = NaN(condition_count, 1);
requested_diffusivity_lower = NaN(condition_count, 1);
requested_diffusivity_upper = NaN(condition_count, 1);

frequency_hz = NaN(condition_count, 1);
background_cs_m_s = NaN(condition_count, 1);
object_cs_m_s = NaN(condition_count, 1);
direction_count = NaN(condition_count, 1);
in_plane_count = NaN(condition_count, 1);
solid_angle_sr = NaN(condition_count, 1);

patch_count = zeros(condition_count, 1);
valid_patch_count = zeros(condition_count, 1);
requested_cell_patch_count = zeros(condition_count, 1);
requested_cell_hit = false(condition_count, 1);

achieved_purity_bins = strings(condition_count, 1);
achieved_diffusivity_bins = strings(condition_count, 1);
achieved_cells = strings(condition_count, 1);

dominant_purity_bin = zeros(condition_count, 1);
dominant_diffusivity_bin = zeros(condition_count, 1);
dominant_cell_fraction = NaN(condition_count, 1);

purity_min = NaN(condition_count, 1);
purity_median = NaN(condition_count, 1);
purity_max = NaN(condition_count, 1);

diffusivity_min = NaN(condition_count, 1);
diffusivity_median = NaN(condition_count, 1);
diffusivity_max = NaN(condition_count, 1);

example_condition_ids = ...
    string(assigned_examples.campaign_condition_id);

for index = 1:condition_count
    condition = conditions(index);

    condition_id(index) = string(condition.condition_id);
    geometry_family(index) = string(condition.geometry.family);

    requested = condition.requested_coverage;

    requested_purity_bin(index) = ...
        double(requested.purity_bin);

    requested_diffusivity_bin(index) = ...
        double(requested.diffusivity_bin);

    purity_range = double(requested.purity_range);
    diffusivity_range = double(requested.diffusivity_range);

    requested_purity_lower(index) = purity_range(1);
    requested_purity_upper(index) = purity_range(2);

    requested_diffusivity_lower(index) = diffusivity_range(1);
    requested_diffusivity_upper(index) = diffusivity_range(2);

    frequency_hz(index) = ...
        double(condition.wavefield.frequency_hz);

    background_cs_m_s(index) = ...
        resolve_optional_scalar( ...
            condition.material.background_cs_m_s);

    object_cs_m_s(index) = ...
        resolve_optional_scalar( ...
            condition.material.object_cs_m_s);

    direction_count(index) = ...
        double(condition.wavefield.direction_count);

    in_plane_count(index) = ...
        double(condition.wavefield.in_plane_count);

    solid_angle_sr(index) = ...
        double(condition.wavefield.solid_angle_sr);

    condition_mask = ...
        example_condition_ids == condition_id(index);

    patch_count(index) = nnz(condition_mask);

    if patch_count(index) == 0
        continue
    end

    valid_mask = condition_mask & ...
        logical(assigned_examples.coverage_valid);

    valid_patch_count(index) = nnz(valid_mask);

    if valid_patch_count(index) == 0
        continue
    end

    purity_bins = double( ...
        assigned_examples.coverage_purity_bin(valid_mask));

    diffusivity_bins = double( ...
        assigned_examples.coverage_diffusivity_bin(valid_mask));

    requested_mask = ...
        purity_bins == requested_purity_bin(index) & ...
        diffusivity_bins == requested_diffusivity_bin(index);

    requested_cell_patch_count(index) = ...
        nnz(requested_mask);

    requested_cell_hit(index) = ...
        requested_cell_patch_count(index) > 0;

    achieved_purity_bins(index) = ...
        join_numeric_values(unique(purity_bins));

    achieved_diffusivity_bins(index) = ...
        join_numeric_values(unique(diffusivity_bins));

    achieved_cells(index) = ...
        join_coverage_cells(purity_bins, diffusivity_bins);

    [dominant_purity_bin(index), ...
     dominant_diffusivity_bin(index), ...
     dominant_cell_fraction(index)] = ...
        dominant_cell(purity_bins, diffusivity_bins);

    purity_values = double( ...
        assigned_examples.truth_material_purity(valid_mask));

    diffusivity_values = double( ...
        assigned_examples.campaign_angular_entropy(valid_mask));

    purity_min(index) = min(purity_values);
    purity_median(index) = median(purity_values);
    purity_max(index) = max(purity_values);

    diffusivity_min(index) = min(diffusivity_values);
    diffusivity_median(index) = median(diffusivity_values);
    diffusivity_max(index) = max(diffusivity_values);
end

summary = table( ...
    condition_id, ...
    geometry_family, ...
    requested_purity_bin, ...
    requested_diffusivity_bin, ...
    requested_purity_lower, ...
    requested_purity_upper, ...
    requested_diffusivity_lower, ...
    requested_diffusivity_upper, ...
    frequency_hz, ...
    background_cs_m_s, ...
    object_cs_m_s, ...
    direction_count, ...
    in_plane_count, ...
    solid_angle_sr, ...
    patch_count, ...
    valid_patch_count, ...
    requested_cell_patch_count, ...
    requested_cell_hit, ...
    achieved_purity_bins, ...
    achieved_diffusivity_bins, ...
    achieved_cells, ...
    dominant_purity_bin, ...
    dominant_diffusivity_bin, ...
    dominant_cell_fraction, ...
    purity_min, ...
    purity_median, ...
    purity_max, ...
    diffusivity_min, ...
    diffusivity_median, ...
    diffusivity_max);

end


function plan = resolve_plan(value)

if ischar(value) || isstring(value)
    path_value = string(value);

    if ~isscalar(path_value) || ~isfile(path_value)
        error("reqml:AdaptiveBatchPlanNotFound", ...
            "Adaptive batch plan was not found: %s", ...
            path_value);
    end

    plan = jsondecode(fileread(path_value));
elseif isstruct(value) && isscalar(value)
    plan = value;
else
    error("reqml:InvalidAdaptiveBatchPlan", ...
        "Adaptive batch plan must be a path or scalar struct.");
end

end


function validate_examples(examples)

required = [
    "campaign_condition_id"
    "coverage_valid"
    "coverage_purity_bin"
    "coverage_diffusivity_bin"
    "truth_material_purity"
    "campaign_angular_entropy"
    ];

available = string(examples.Properties.VariableNames);

missing = setdiff(required, available);

if ~isempty(missing)
    error("reqml:MissingRequestedVsAchievedVariable", ...
        "Assigned examples are missing variable '%s'.", ...
        missing(1));
end

end


function text = join_numeric_values(values)

values = sort(unique(double(values(:))));
text = strjoin(string(values), ",");

end


function text = join_coverage_cells(purity_bins, diffusivity_bins)

pairs = unique( ...
    [double(purity_bins(:)), double(diffusivity_bins(:))], ...
    "rows");

labels = strings(size(pairs, 1), 1);

for index = 1:size(pairs, 1)
    labels(index) = sprintf( ...
        "p%02d_d%02d", ...
        pairs(index, 1), ...
        pairs(index, 2));
end

text = strjoin(labels, ",");

end


function [purity_bin, diffusivity_bin, fraction] = ...
        dominant_cell(purity_bins, diffusivity_bins)

pairs = [double(purity_bins(:)), double(diffusivity_bins(:))];

[unique_pairs, ~, groups] = unique(pairs, "rows");
counts = accumarray(groups, 1);

[maximum_count, index] = max(counts);

purity_bin = unique_pairs(index, 1);
diffusivity_bin = unique_pairs(index, 2);
fraction = maximum_count / size(pairs, 1);

end


function value = resolve_optional_scalar(candidate)

if isempty(candidate)
    value = NaN;
    return
end

candidate = double(candidate(:));
candidate = candidate(isfinite(candidate));

if isempty(candidate)
    value = NaN;
    return
end

candidate = unique(candidate);

if numel(candidate) ~= 1
    error("reqml:InconsistentRequestedConditionMetadata", ...
        ["Expected optional condition metadata to contain " ...
         "at most one finite scalar value."]);
end

value = candidate;

end


function summary = empty_summary_table()

summary = table( ...
    strings(0,1), ...
    strings(0,1), ...
    zeros(0,1), ...
    zeros(0,1), ...
    'VariableNames', { ...
        'condition_id', ...
        'geometry_family', ...
        'requested_purity_bin', ...
        'requested_diffusivity_bin'});

end
