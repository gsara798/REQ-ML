function tests = test_grouped_condition_split
%TEST_GROUPED_CONDITION_SPLIT Test deterministic condition isolation.

tests = functiontests(localfunctions);

end

function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end

function testKeepsConditionsAndRunsIsolated(testCase)

examples = make_examples();

split = reqml.splits.make_grouped_condition_split( ...
    examples, ...
    Seed=4101, ...
    TrainFraction=0.5, ...
    ValidationFraction=0.25, ...
    TestFraction=0.25);

report = reqml.splits.validate_split_integrity( ...
    examples, ...
    split);

verifyTrue(testCase, report.valid);
verifyFalse(testCase, report.run_overlap);
verifyFalse(testCase, report.condition_overlap);

verifyEqual(testCase, ...
    height(split.summary), ...
    3);

verifyEqual(testCase, ...
    sum(split.summary.condition_count), ...
    8);

verifyEqual(testCase, ...
    sum(split.summary.run_count), ...
    16);

verifyEqual(testCase, ...
    sum(split.summary.example_count), ...
    height(examples));

end

function testRejectsMasksInconsistentWithPartition(testCase)

examples = make_examples();

split = reqml.splits.make_grouped_condition_split( ...
    examples, ...
    Seed=4101, ...
    TrainFraction=0.5, ...
    ValidationFraction=0.25, ...
    TestFraction=0.25);

row_index = find(split.train_mask, 1, "first");

split.train_mask(row_index) = false;
split.validation_mask(row_index) = true;

report = reqml.splits.validate_split_integrity( ...
    examples, ...
    split);

verifyTrue(testCase, report.complete_assignment);
verifyFalse(testCase, ...
    report.mask_partition_consistent);
verifyFalse(testCase, report.valid);

end

function testIsDeterministic(testCase)

examples = make_examples();

a = reqml.splits.make_grouped_condition_split( ...
    examples, ...
    Seed=4101, ...
    TrainFraction=0.5, ...
    ValidationFraction=0.25, ...
    TestFraction=0.25);

b = reqml.splits.make_grouped_condition_split( ...
    examples, ...
    Seed=4101, ...
    TrainFraction=0.5, ...
    ValidationFraction=0.25, ...
    TestFraction=0.25);

verifyEqual(testCase, ...
    a.partition, ...
    b.partition);

verifyEqual(testCase, ...
    a.conditions, ...
    b.conditions);

end

function examples = make_examples()

rows = {};

row_index = 0;

for cs = [2, 3]
    for frequency = [300, 500]
        for direction_count = [1, 8]
            for seed = [1, 2]
                run_id = compose( ...
                    "run_cs_%g_f_%g_N_%g_seed_%g", ...
                    cs, ...
                    frequency, ...
                    direction_count, ...
                    seed);

                for patch = 1:3
                    row_index = row_index + 1;

                    rows{row_index, 1} = run_id; %#ok<AGROW>
                    rows{row_index, 2} = cs; %#ok<AGROW>
                    rows{row_index, 3} = frequency; %#ok<AGROW>
                    rows{row_index, 4} = direction_count; %#ok<AGROW>
                    rows{row_index, 5} = seed; %#ok<AGROW>
                    rows{row_index, 6} = patch; %#ok<AGROW>
                end
            end
        end
    end
end

examples = cell2table( ...
    rows, ...
    VariableNames=[
        "campaign_run_id"
        "campaign_background_cs_m_s"
        "campaign_frequency_hz"
        "campaign_direction_count"
        "campaign_seed"
        "patch_index"
    ]);

examples.campaign_run_id = ...
    string(examples.campaign_run_id);

end
