function tests = test_complete_coverage_grid
%TEST_COMPLETE_COVERAGE_GRID

tests = functiontests(localfunctions);

end


function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end


function testCompletesFiveDimensionalGrid(testCase)

summary = table();

summary.sws_bin = [1; 2];
summary.frequency_bin = [1; 2];
summary.purity_bin = [1; 2];
summary.diffusivity_bin = [1; 2];
summary.discretization_bin = [1; 3];

summary.cell_key = [
    "s01_f01_p01_d01_g01"
    "s02_f02_p02_d02_g03"
    ];

summary.sws_label = [
    "[1.5,2)"
    "[2,2.5]"
    ];

summary.frequency_label = [
    "[199,250)"
    "[250,350]"
    ];

summary.purity_label = [
    "[0.5,0.7)"
    "[0.7,1]"
    ];

summary.diffusivity_label = [
    "[0,0.5)"
    "[0.5,1]"
    ];

summary.discretization_label = [
    "dx=0.00025,dz=0.00025"
    "dx=0.0005,dz=0.0005"
    ];

summary.example_count = [7; 11];
summary.independent_run_count = [3; 4];
summary.independent_condition_count = [2; 3];

complete = reqml.coverage.completeCoverageGrid( ...
    summary, ...
    [1.5 2.0 2.5], ...
    [199 250 350], ...
    [0.5 0.7 1.0], ...
    [0 0.5 1.0], ...
    [ ...
        0.25e-3 0.25e-3
        0.40e-3 0.40e-3
        0.50e-3 0.50e-3]);

verifyEqual(testCase, ...
    height(complete), ...
    48);

verifyEqual(testCase, ...
    numel(unique(complete.cell_key)), ...
    48);

first_mask = ...
    complete.cell_key == ...
        "s01_f01_p01_d01_g01";

last_mask = ...
    complete.cell_key == ...
        "s02_f02_p02_d02_g03";

verifyEqual(testCase, ...
    complete.example_count(first_mask), ...
    7);

verifyEqual(testCase, ...
    complete.independent_run_count(first_mask), ...
    3);

verifyEqual(testCase, ...
    complete.independent_condition_count(first_mask), ...
    2);

verifyEqual(testCase, ...
    complete.example_count(last_mask), ...
    11);

verifyEqual(testCase, ...
    complete.independent_run_count(last_mask), ...
    4);

verifyEqual(testCase, ...
    complete.independent_condition_count(last_mask), ...
    3);

unobserved = ...
    ~first_mask & ...
    ~last_mask;

verifyTrue(testCase, ...
    all(complete.example_count(unobserved) == 0));

verifyTrue(testCase, ...
    all(complete.independent_run_count(unobserved) == 0));

verifyTrue(testCase, ...
    all( ...
        complete. ...
            independent_condition_count(unobserved) == 0));

end


function testCompletesEmptyObservedSummary(testCase)

summary = table();

summary.sws_bin = zeros(0,1);
summary.frequency_bin = zeros(0,1);
summary.purity_bin = zeros(0,1);
summary.diffusivity_bin = zeros(0,1);
summary.discretization_bin = zeros(0,1);

summary.cell_key = strings(0,1);
summary.sws_label = strings(0,1);
summary.frequency_label = strings(0,1);
summary.purity_label = strings(0,1);
summary.diffusivity_label = strings(0,1);
summary.discretization_label = strings(0,1);

summary.example_count = zeros(0,1);
summary.independent_run_count = zeros(0,1);

complete = reqml.coverage.completeCoverageGrid( ...
    summary, ...
    [1.5 2.0 2.5], ...
    [199 250 350], ...
    [0.5 0.7 1.0], ...
    [0 0.5 1.0], ...
    [ ...
        0.25e-3 0.25e-3
        0.40e-3 0.40e-3
        0.50e-3 0.50e-3]);

verifyEqual(testCase, ...
    height(complete), ...
    48);

verifyTrue(testCase, ...
    all(complete.example_count == 0));

verifyTrue(testCase, ...
    all(complete.independent_run_count == 0));

end


function testProducesFifteenHundredScientificCells(testCase)

summary = table();

summary.sws_bin = zeros(0,1);
summary.frequency_bin = zeros(0,1);
summary.purity_bin = zeros(0,1);
summary.diffusivity_bin = zeros(0,1);
summary.discretization_bin = zeros(0,1);

summary.cell_key = strings(0,1);
summary.sws_label = strings(0,1);
summary.frequency_label = strings(0,1);
summary.purity_label = strings(0,1);
summary.diffusivity_label = strings(0,1);
summary.discretization_label = strings(0,1);

summary.example_count = zeros(0,1);
summary.independent_run_count = zeros(0,1);

complete = reqml.coverage.completeCoverageGrid( ...
    summary, ...
    [1.5 2.0 2.5 3.0 3.5 4.0], ...
    [199 250 350 450 550 601], ...
    [0.5 0.7 0.9 0.98 1.0], ...
    [0 0.01 0.05 0.20 0.50 1.0], ...
    [ ...
        0.25e-3 0.25e-3
        0.40e-3 0.40e-3
        0.50e-3 0.50e-3]);

verifyEqual(testCase, ...
    height(complete), ...
    1500);

verifyEqual(testCase, ...
    numel(unique(complete.cell_key)), ...
    1500);

end
