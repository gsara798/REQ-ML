function tests = test_freeze_grouped_training_split
%TEST_FREEZE_GROUPED_TRAINING_SPLIT Test frozen split persistence.

tests = functiontests(localfunctions);

end

function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end

function testFreezesExampleAssignments(testCase)

examples = make_examples();

output_directory = string(tempname);
mkdir(output_directory);
cleanup = onCleanup(@() remove_directory(output_directory));

result = reqml.splits.freeze_grouped_training_split( ...
    examples, ...
    output_directory, ...
    DatasetPath="fixture/examples.mat", ...
    SplitSeed=4101, ...
    FoldSeed=5101, ...
    FoldCount=5);

verifyTrue(testCase, result.split_integrity.valid);
verifyTrue(testCase, result.fold_integrity.valid);

verifyTrue(testCase, isfile( ...
    result.paths.example_assignments_csv));

verifyTrue(testCase, isfile( ...
    result.paths.manifest_json));

loaded = load( ...
    result.paths.example_assignments_mat, ...
    "assignment");

assignment = loaded.assignment;

verifyEqual(testCase, height(assignment), height(examples));
verifyEqual(testCase, ...
    numel(unique(assignment.example_id)), ...
    height(examples));

verifyEqual(testCase, ...
    unique(assignment.cv_fold( ...
        assignment.partition ~= "train")), ...
    0);

verifyEqual(testCase, ...
    unique(assignment.cv_fold( ...
        assignment.partition == "train")), ...
    (1:5)');

end

function testRejectsDuplicateExampleIds(testCase)

examples = make_examples();
examples.example_id(2) = examples.example_id(1);

output_directory = string(tempname);
mkdir(output_directory);
cleanup = onCleanup(@() remove_directory(output_directory));

verifyError(testCase, ...
    @() reqml.splits.freeze_grouped_training_split( ...
        examples, ...
        output_directory), ...
    "reqml:DuplicateTrainingExampleId");

end


function remove_directory(path)

if isfolder(path)
    rmdir(path, "s");
end

end

function examples = make_examples()

condition_count = 20;
runs_per_condition = 2;
examples_per_run = 3;

n = condition_count * runs_per_condition * examples_per_run;

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

        for example_index = 1:examples_per_run
            row = row + 1;

            example_id(row) = compose( ...
                "%s_example_%02d", ...
                run_id, ...
                example_index);

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
