function tests = test_load_frozen_training_split
%TEST_LOAD_FROZEN_TRAINING_SPLIT Test example-ID split restoration.

tests = functiontests(localfunctions);

end

function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end

function testRestoresAssignmentsAfterRowReordering(testCase)

examples = make_examples();

split = reqml.splits.make_grouped_condition_split( ...
    examples, ...
    GroupColumns="campaign_condition_id", ...
    Seed=4101, ...
    TrainFraction=0.6, ...
    ValidationFraction=0.2, ...
    TestFraction=0.2);

folds = reqml.splits.make_grouped_training_folds( ...
    examples, ...
    split, ...
    FoldCount=3, ...
    Seed=5101);

directory = string(tempname);
mkdir(directory);
cleanup = onCleanup(@() remove_directory(directory));

paths = reqml.splits.save_training_split_manifest( ...
    examples, split, folds, directory);

order = randperm(height(examples));
reordered = examples(order, :);

loaded = reqml.splits.load_frozen_training_split( ...
    reordered, ...
    paths.example_assignments_mat);

verifyEqual(testCase, ...
    string(loaded.assignment.example_id), ...
    string(reordered.example_id));

verifyEqual(testCase, ...
    loaded.split.partition, ...
    split.partition(order));

verifyEqual(testCase, ...
    loaded.folds.cv_fold, ...
    folds.cv_fold(order));

end

function testRejectsChangedConditionIdentity(testCase)

examples = make_examples();

split = reqml.splits.make_grouped_condition_split( ...
    examples, ...
    GroupColumns="campaign_condition_id", ...
    Seed=4101, ...
    TrainFraction=0.6, ...
    ValidationFraction=0.2, ...
    TestFraction=0.2);

folds = reqml.splits.make_grouped_training_folds( ...
    examples, split, FoldCount=3);

directory = string(tempname);
mkdir(directory);
cleanup = onCleanup(@() remove_directory(directory));

paths = reqml.splits.save_training_split_manifest( ...
    examples, split, folds, directory);

examples.campaign_condition_id(1) = "changed_condition";

verifyError(testCase, ...
    @() reqml.splits.load_frozen_training_split( ...
        examples, paths.example_assignments_mat), ...
    "reqml:FrozenConditionMismatch");

end

function examples = make_examples()

condition_count = 15;
runs_per_condition = 2;
rows_per_run = 2;
n = condition_count * runs_per_condition * rows_per_run;

example_id = strings(n, 1);
campaign_condition_id = strings(n, 1);
campaign_run_id = strings(n, 1);

row = 0;

for condition_index = 1:condition_count
    condition_id = compose( ...
        "condition_%03d", condition_index);

    for run_index = 1:runs_per_condition
        run_id = compose( ...
            "%s_run_%02d", condition_id, run_index);

        for example_index = 1:rows_per_run
            row = row + 1;

            example_id(row) = compose( ...
                "%s_example_%02d", run_id, example_index);

            campaign_condition_id(row) = condition_id;
            campaign_run_id(row) = run_id;
        end
    end
end

examples = table( ...
    example_id, ...
    campaign_condition_id, ...
    campaign_run_id);

end

function remove_directory(path)

if isfolder(path)
    rmdir(path, "s");
end

end
