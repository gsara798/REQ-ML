function summary = summarize_dataset(dataset_or_examples, options)
%SUMMARIZE_DATASET Audit one REQ-ML example table before training.
%
% Variable roles come exclusively from:
%
%   reqml.schema.dataset_variable_registry

arguments
    dataset_or_examples
    options.ConstantTolerance (1,1) double = 0
    options.MinimumFiniteFraction (1,1) double = 0.99
end

[examples, dataset_id] = resolve_examples(dataset_or_examples);

if isempty(examples)
    error("reqml:EmptyDataset", ...
        "Dataset example table is empty.");
end

registry = reqml.schema.dataset_variable_registry(examples);
numeric_registry = registry(registry.numeric, :);

variable_summary = build_variable_summary( ...
    examples, ...
    numeric_registry, ...
    options.ConstantTolerance);

registry = outerjoin( ...
    registry, ...
    variable_summary, ...
    Keys="variable_name", ...
    MergeKeys=true, ...
    Type="left");

registry = sortrows(registry, "variable_name");

candidate_mask = ...
    registry.trainable & ...
    registry.numeric & ...
    ~registry.is_constant & ...
    registry.finite_fraction >= ...
        options.MinimumFiniteFraction;

summary = struct();
summary.schema_name = "reqml_dataset_summary";
summary.schema_version = "1.1";
summary.dataset_id = dataset_id;
summary.example_count = height(examples);
summary.variable_count = width(examples);
summary.numeric_variable_count = sum(registry.numeric);
summary.variable_registry = registry;

summary.candidate_features = ...
    registry.variable_name(candidate_mask);

summary.constant_numeric_variables = ...
    registry.variable_name( ...
        registry.numeric & registry.is_constant);

summary.low_finite_fraction_variables = ...
    registry.variable_name( ...
        registry.numeric & ...
        registry.finite_fraction < ...
            options.MinimumFiniteFraction);

summary.unregistered_variables = ...
    registry.variable_name( ...
        registry.role == "unregistered");

summary.role_counts = grouped_registry_count( ...
    registry, ...
    "role");

summary.source_counts = grouped_registry_count( ...
    registry, ...
    "source");

summary.feature_group_counts = ...
    grouped_feature_count(registry);

summary.sample_count = count_unique_if_present( ...
    examples, ...
    "sample_id");

summary.run_count = count_unique_if_present( ...
    examples, ...
    "campaign_run_id");

summary.target = summarize_target(examples);

summary.examples_per_run = ...
    grouped_count(examples, "campaign_run_id");

summary.by_background_cs = ...
    grouped_count(examples, ...
        "campaign_background_cs_m_s");

summary.by_frequency = ...
    grouped_count(examples, ...
        "campaign_frequency_hz");

summary.by_direction_count = ...
    grouped_count(examples, ...
        "campaign_direction_count");

summary.created = string(datetime( ...
    "now", ...
    "Format", ...
    "yyyy-MM-dd HH:mm:ss Z"));

end

function [examples, dataset_id] = resolve_examples(value)

if istable(value)
    examples = value;
    dataset_id = "";
    return
end

if isstruct(value) && ...
        isscalar(value) && ...
        isfield(value, "examples") && ...
        istable(value.examples)

    examples = value.examples;

    if isfield(value, "dataset_id")
        dataset_id = string(value.dataset_id);
    else
        dataset_id = "";
    end

    return
end

error("reqml:InvalidDatasetSummaryInput", ...
    "Input must be an example table or a dataset struct with examples.");

end

function summary_table = build_variable_summary( ...
        examples, numeric_registry, constant_tolerance)

n = height(numeric_registry);

variable_name = numeric_registry.variable_name;
finite_count = zeros(n, 1);
finite_fraction = zeros(n, 1);
unique_finite_count = zeros(n, 1);
minimum = nan(n, 1);
maximum = nan(n, 1);
mean_value = nan(n, 1);
standard_deviation = nan(n, 1);
is_constant = false(n, 1);

for index = 1:n
    name = variable_name(index);
    values = double(examples.(name));
    values = values(:);

    finite_mask = isfinite(values);
    finite_values = values(finite_mask);

    finite_count(index) = nnz(finite_mask);
    finite_fraction(index) = ...
        finite_count(index) / numel(values);

    if isempty(finite_values)
        continue
    end

    unique_finite_count(index) = ...
        numel(unique(finite_values));

    minimum(index) = min(finite_values);
    maximum(index) = max(finite_values);
    mean_value(index) = mean(finite_values);
    standard_deviation(index) = std(finite_values);

    is_constant(index) = ...
        (maximum(index) - minimum(index)) <= ...
        constant_tolerance;
end

summary_table = table( ...
    variable_name, ...
    finite_count, ...
    finite_fraction, ...
    unique_finite_count, ...
    minimum, ...
    maximum, ...
    mean_value, ...
    standard_deviation, ...
    is_constant);

end

function counts = grouped_registry_count(registry, name)

values = registry.(name);

[group_id, group_value] = findgroups(values);
variable_count = splitapply(@numel, values, group_id);

counts = table( ...
    group_value, ...
    variable_count, ...
    VariableNames=[name, "variable_count"]);

counts = sortrows(counts, name);

end

function counts = grouped_feature_count(registry)

features = registry(registry.role == "feature", :);

if isempty(features)
    counts = table();
    return
end

[group_id, group_value] = findgroups(features.group);
variable_count = splitapply( ...
    @numel, ...
    features.group, ...
    group_id);

counts = table( ...
    group_value, ...
    variable_count, ...
    VariableNames=["group", "variable_count"]);

counts = sortrows(counts, "group");

end

function target = summarize_target(examples)

target = struct();
target.column = "q_target_from_center_truth";
target.present = ismember( ...
    target.column, ...
    string(examples.Properties.VariableNames));

target.valid_count = 0;
target.minimum = NaN;
target.maximum = NaN;
target.mean = NaN;
target.standard_deviation = NaN;

if ~target.present
    return
end

values = double( ...
    examples.q_target_from_center_truth);

valid = isfinite(values);

if ismember( ...
        "target_valid", ...
        string(examples.Properties.VariableNames))
    valid = valid & logical(examples.target_valid);
end

target.valid_count = nnz(valid);

if target.valid_count == 0
    return
end

values = values(valid);

target.minimum = min(values);
target.maximum = max(values);
target.mean = mean(values);
target.standard_deviation = std(values);

end

function count = count_unique_if_present(examples, name)

if ~ismember( ...
        name, ...
        string(examples.Properties.VariableNames))
    count = 0;
    return
end

count = numel(unique(examples.(name)));

end

function counts = grouped_count(examples, name)

if ~ismember( ...
        name, ...
        string(examples.Properties.VariableNames))
    counts = table();
    return
end

values = examples.(name);

[group_id, group_value] = findgroups(values);
example_count = splitapply(@numel, values, group_id);

counts = table( ...
    group_value, ...
    example_count, ...
    VariableNames=[name, "example_count"]);

counts = sortrows(counts, name);

end
