function result = load_frozen_training_split( ...
    examples, assignment_path)
%LOAD_FROZEN_TRAINING_SPLIT Restore a frozen split by unique example_id.
%
% Row order in examples may differ from the order used when the split was
% frozen. Assignments are therefore matched strictly by example_id.

arguments
    examples table
    assignment_path (1,1) string
end

if ~ismember( ...
        "example_id", ...
        string(examples.Properties.VariableNames))
    error("reqml:MissingTrainingExampleId", ...
        "Examples table does not contain example_id.");
end

if ~isfile(assignment_path)
    error("reqml:FrozenSplitNotFound", ...
        "Frozen split assignment file was not found: %s", ...
        assignment_path);
end

loaded = load(assignment_path, "assignment");

if ~isfield(loaded, "assignment") || ...
        ~istable(loaded.assignment)
    error("reqml:InvalidFrozenSplitFile", ...
        "Frozen split file does not contain assignment table.");
end

assignment = loaded.assignment;

required = [
    "example_id"
    "campaign_condition_id"
    "campaign_run_id"
    "partition"
    "cv_fold"
    ];

missing = setdiff( ...
    required, ...
    string(assignment.Properties.VariableNames));

if ~isempty(missing)
    error("reqml:InvalidFrozenSplitAssignment", ...
        "Frozen assignment is missing variables: %s", ...
        strjoin(missing, ", "));
end

example_id = string(examples.example_id);
frozen_example_id = string(assignment.example_id);

if numel(unique(example_id)) ~= numel(example_id)
    error("reqml:DuplicateTrainingExampleId", ...
        "Current examples contain duplicate example_id values.");
end

if numel(unique(frozen_example_id)) ~= numel(frozen_example_id)
    error("reqml:DuplicateFrozenExampleId", ...
        "Frozen split contains duplicate example_id values.");
end

[row_found, assignment_index] = ...
    ismember(example_id, frozen_example_id);

if any(~row_found)
    error("reqml:ExampleMissingFromFrozenSplit", ...
        "%d current examples are absent from the frozen split.", ...
        nnz(~row_found));
end

if height(assignment) ~= height(examples)
    error("reqml:FrozenSplitDatasetMismatch", ...
        ["Frozen split contains %d assignments, but the current " ...
         "dataset contains %d examples."], ...
        height(assignment), height(examples));
end

ordered = assignment(assignment_index, :);

if ~isequal(string(ordered.example_id), example_id)
    error("reqml:FrozenSplitAlignmentFailure", ...
        "Could not align frozen split by example_id.");
end

current_condition = string(examples.campaign_condition_id);
current_run = string(examples.campaign_run_id);

if any(string(ordered.campaign_condition_id) ~= current_condition)
    error("reqml:FrozenConditionMismatch", ...
        "At least one example changed campaign_condition_id.");
end

if any(string(ordered.campaign_run_id) ~= current_run)
    error("reqml:FrozenRunMismatch", ...
        "At least one example changed campaign_run_id.");
end

partition = string(ordered.partition);
cv_fold = double(ordered.cv_fold);

split = struct();
split.schema_name = "reqml_loaded_frozen_training_split";
split.schema_version = "1.0";

split.condition_id = current_condition;
split.partition = partition;

split.train_mask = partition == "train";
split.validation_mask = partition == "validation";
split.test_mask = partition == "test";

folds = struct();
folds.schema_name = "reqml_loaded_frozen_training_folds";
folds.schema_version = "1.0";

folds.cv_fold = cv_fold;
folds.fold_count = max(cv_fold);
folds.condition_column = "campaign_condition_id";

result = struct();
result.schema_name = "reqml_loaded_frozen_training_assignment";
result.schema_version = "1.0";

result.assignment = ordered;
result.split = split;
result.folds = folds;

end
