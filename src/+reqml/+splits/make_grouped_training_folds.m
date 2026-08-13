function folds = make_grouped_training_folds( ...
    examples, split, options)
%MAKE_GROUPED_TRAINING_FOLDS Create deterministic grouped folds within train.
%
% Every condition remains entirely within one cross-validation fold.
% Validation and test examples receive fold 0.

arguments
    examples table
    split (1,1) struct

    options.ConditionColumn (1,1) string = ...
        "campaign_condition_id"

    options.FoldCount (1,1) double = 5
    options.Seed (1,1) double = 5101
end

condition_column = string(options.ConditionColumn);
fold_count = round(double(options.FoldCount));

if fold_count < 2
    error("reqml:InvalidTrainingFoldCount", ...
        "FoldCount must be at least 2.");
end

available = string(examples.Properties.VariableNames);

if ~ismember(condition_column, available)
    error("reqml:MissingFoldConditionVariable", ...
        "Dataset is missing condition column '%s'.", ...
        condition_column);
end

required_split_fields = [
    "partition"
    "train_mask"
    ];

for field_name = required_split_fields.'
    if ~isfield(split, field_name)
        error("reqml:InvalidSplit", ...
            "Split is missing field '%s'.", field_name);
    end
end

if numel(split.partition) ~= height(examples)
    error("reqml:SplitSizeMismatch", ...
        "Split row count does not match example count.");
end

condition_id = string( ...
    examples.(char(condition_column)));

train_condition_id = unique( ...
    condition_id(split.train_mask), ...
    "stable");

condition_count = numel(train_condition_id);

if condition_count < fold_count
    error("reqml:InsufficientTrainingConditionsForFolds", ...
        ["Training contains %d conditions, but %d folds " ...
         "were requested."], ...
        condition_count, fold_count);
end

previous_rng = rng;
cleanup = onCleanup(@() rng(previous_rng));

rng(options.Seed, "twister");
order = randperm(condition_count);

condition_fold = zeros(condition_count, 1);

for order_index = 1:condition_count
    condition_index = order(order_index);

    condition_fold(condition_index) = ...
        mod(order_index - 1, fold_count) + 1;
end

cv_fold = zeros(height(examples), 1);

for condition_index = 1:condition_count
    mask = ...
        split.train_mask & ...
        condition_id == train_condition_id(condition_index);

    cv_fold(mask) = condition_fold(condition_index);
end

if any(cv_fold(~split.train_mask) ~= 0)
    error("reqml:NonTrainingFoldAssignment", ...
        "Validation or test rows received a training fold.");
end

if any(cv_fold(split.train_mask) < 1)
    error("reqml:MissingTrainingFoldAssignment", ...
        "At least one training example has no fold.");
end

folds = struct();
folds.schema_name = "reqml_grouped_training_folds";
folds.schema_version = "1.0";

folds.seed = double(options.Seed);
folds.fold_count = fold_count;
folds.condition_column = condition_column;

folds.cv_fold = cv_fold;

folds.conditions = table( ...
    train_condition_id, ...
    condition_fold, ...
    VariableNames=[ ...
        "condition_id", ...
        "cv_fold"]);

fold_names = (1:fold_count)';
condition_counts = zeros(fold_count, 1);
run_counts = zeros(fold_count, 1);
example_counts = zeros(fold_count, 1);

for fold_index = 1:fold_count
    mask = cv_fold == fold_index;

    condition_counts(fold_index) = numel(unique( ...
        condition_id(mask)));

    run_counts(fold_index) = numel(unique(string( ...
        examples.campaign_run_id(mask))));

    example_counts(fold_index) = nnz(mask);
end

folds.summary = table( ...
    fold_names, ...
    condition_counts, ...
    run_counts, ...
    example_counts, ...
    VariableNames=[ ...
        "cv_fold", ...
        "condition_count", ...
        "run_count", ...
        "example_count"]);

clear cleanup

end
