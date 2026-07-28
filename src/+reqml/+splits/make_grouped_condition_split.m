function split = make_grouped_condition_split(examples, options)
%MAKE_GROUPED_CONDITION_SPLIT Deterministic condition-grouped holdout split.
%
% Conditions are defined by:
%   campaign_background_cs_m_s
%   campaign_frequency_hz
%   campaign_direction_count
%
% All patches and all seeds belonging to one physical condition remain in the
% same split.

arguments
    examples table

    options.Seed (1,1) double = 4101
    options.TrainFraction (1,1) double = 0.70
    options.ValidationFraction (1,1) double = 0.15
    options.TestFraction (1,1) double = 0.15
end

required = [
    "campaign_run_id"
    "campaign_background_cs_m_s"
    "campaign_frequency_hz"
    "campaign_direction_count"
    ];

missing = setdiff( ...
    required, ...
    string(examples.Properties.VariableNames));

if ~isempty(missing)
    error("reqml:MissingSplitVariable", ...
        "Dataset is missing split variables: %s", ...
        strjoin(missing, ", "));
end

fractions = [
    options.TrainFraction
    options.ValidationFraction
    options.TestFraction
    ];

if any(fractions <= 0) || ...
        abs(sum(fractions) - 1) > 1e-12
    error("reqml:InvalidSplitFractions", ...
        "Train, validation, and test fractions must be positive and sum to 1.");
end

condition_id = compose( ...
    "cs_%0.6g__f_%0.6g__N_%0.6g", ...
    examples.campaign_background_cs_m_s, ...
    examples.campaign_frequency_hz, ...
    examples.campaign_direction_count);

[condition_group, unique_condition_id] = ...
    findgroups(condition_id);

condition_count = numel(unique_condition_id);

if condition_count < 3
    error("reqml:InsufficientSplitConditions", ...
        "At least three unique physical conditions are required.");
end

previous_rng = rng;
cleanup = onCleanup(@() rng(previous_rng));

rng(options.Seed, "twister");
order = randperm(condition_count);

train_count = floor( ...
    options.TrainFraction * condition_count);

validation_count = floor( ...
    options.ValidationFraction * condition_count);

test_count = ...
    condition_count - ...
    train_count - ...
    validation_count;

if min([train_count, validation_count, test_count]) < 1
    error("reqml:EmptySplitPartition", ...
        "Resolved split contains an empty partition.");
end

condition_partition = strings(condition_count, 1);

condition_partition(order( ...
    1:train_count)) = "train";

validation_start = train_count + 1;
validation_end = train_count + validation_count;

condition_partition(order( ...
    validation_start:validation_end)) = ...
    "validation";

condition_partition(order( ...
    validation_end + 1:end)) = "test";

partition = condition_partition(condition_group);

split = struct();
split.schema_name = "reqml_grouped_condition_split";
split.schema_version = "1.0";
split.seed = options.Seed;
split.train_fraction_requested = options.TrainFraction;
split.validation_fraction_requested = ...
    options.ValidationFraction;
split.test_fraction_requested = options.TestFraction;

split.condition_id = condition_id;
split.partition = partition;
split.train_mask = partition == "train";
split.validation_mask = partition == "validation";
split.test_mask = partition == "test";

condition_table = table();
condition_table.condition_id = unique_condition_id;

condition_table.background_cs_m_s = ...
    splitapply( ...
        @(values) values(1), ...
        examples.campaign_background_cs_m_s, ...
        condition_group);

condition_table.frequency_hz = ...
    splitapply( ...
        @(values) values(1), ...
        examples.campaign_frequency_hz, ...
        condition_group);

condition_table.direction_count = ...
    splitapply( ...
        @(values) values(1), ...
        examples.campaign_direction_count, ...
        condition_group);

condition_table.partition = condition_partition;

split.conditions = sortrows( ...
    condition_table, ...
    [
        "partition"
        "background_cs_m_s"
        "frequency_hz"
        "direction_count"
    ]);

split.summary = summarize_split( ...
    examples, ...
    split);

clear cleanup

end

function summary = summarize_split(examples, split)

partitions = [
    "train"
    "validation"
    "test"
    ];

partition = strings(3, 1);
condition_count = zeros(3, 1);
run_count = zeros(3, 1);
example_count = zeros(3, 1);

for index = 1:3
    name = partitions(index);
    mask = split.partition == name;

    partition(index) = name;
    condition_count(index) = ...
        numel(unique(split.condition_id(mask)));

    run_count(index) = ...
        numel(unique( ...
            examples.campaign_run_id(mask)));

    example_count(index) = nnz(mask);
end

summary = table( ...
    partition, ...
    condition_count, ...
    run_count, ...
    example_count);

end
