function tests = test_summarize_coverage
%TEST_SUMMARIZE_COVERAGE

tests = functiontests(localfunctions);

end


function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end


function testGroupsByFullFourDimensionalCell(testCase)

assigned = make_assigned_examples();

summary = reqml.coverage.summarizeCoverage( ...
    assigned, ...
    RunVariable="campaign_run_id", ...
    ConditionVariable="campaign_condition_id");

verifyEqual(testCase, height(summary), 3);

verifyEqual(testCase, ...
    summary.cell_key, ...
    [ ...
        "s01_f01_p01_d01"
        "s01_f02_p01_d01"
        "s02_f01_p01_d01"
    ]);

verifyEqual(testCase, ...
    summary.example_count, ...
    [2; 1; 2]);

verifyEqual(testCase, ...
    summary.independent_run_count, ...
    [2; 1; 2]);

verifyEqual(testCase, ...
    summary.independent_condition_count, ...
    [1; 1; 2]);

verifyEqual(testCase, ...
    summary.sws_label, ...
    [ ...
        "[1.5,2)"
        "[1.5,2)"
        "[2,2.5)"
    ]);

verifyEqual(testCase, ...
    summary.frequency_label, ...
    [ ...
        "[199,250)"
        "[250,350)"
        "[199,250)"
    ]);

end


function testIgnoresInvalidRows(testCase)

assigned = make_assigned_examples();

assigned.coverage_valid(1) = false;

summary = reqml.coverage.summarizeCoverage( ...
    assigned, ...
    RunVariable="campaign_run_id");

verifyEqual(testCase, ...
    sum(summary.example_count), ...
    4);

verifyFalse(testCase, ...
    any(summary.example_count == 0));

end


function testReturnsTypedEmptySummary(testCase)

assigned = make_assigned_examples();
assigned.coverage_valid(:) = false;

summary = reqml.coverage.summarizeCoverage( ...
    assigned);

verifyEqual(testCase, height(summary), 0);

verifyEqual(testCase, ...
    string(summary.Properties.VariableNames), ...
    [ ...
        "sws_bin"
        "frequency_bin"
        "purity_bin"
        "diffusivity_bin"
        "cell_key"
        "sws_label"
        "frequency_label"
        "purity_label"
        "diffusivity_label"
        "example_count"
        "independent_run_count"
    ]');

end


function assigned = make_assigned_examples()

assigned = table();

assigned.coverage_sws_bin = ...
    [1; 1; 1; 2; 2];

assigned.coverage_frequency_bin = ...
    [1; 1; 2; 1; 1];

assigned.coverage_purity_bin = ...
    [1; 1; 1; 1; 1];

assigned.coverage_diffusivity_bin = ...
    [1; 1; 1; 1; 1];

assigned.coverage_sws_label = [
    "[1.5,2)"
    "[1.5,2)"
    "[1.5,2)"
    "[2,2.5)"
    "[2,2.5)"
    ];

assigned.coverage_frequency_label = [
    "[199,250)"
    "[199,250)"
    "[250,350)"
    "[199,250)"
    "[199,250)"
    ];

assigned.coverage_purity_label = ...
    repmat("[0.5,0.7)", 5, 1);

assigned.coverage_diffusivity_label = ...
    repmat("[0,0.01)", 5, 1);

assigned.coverage_valid = true(5,1);

assigned.campaign_run_id = [
    "run_1"
    "run_2"
    "run_3"
    "run_4"
    "run_5"
    ];

assigned.campaign_condition_id = [
    "condition_a"
    "condition_a"
    "condition_b"
    "condition_c"
    "condition_d"
    ];

end
