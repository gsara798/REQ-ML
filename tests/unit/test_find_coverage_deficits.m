function tests = test_find_coverage_deficits
%TEST_FIND_COVERAGE_DEFICITS

tests = functiontests(localfunctions);

end


function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end


function testFindsDeficitsWithoutInternalBinDiversity(testCase)

summary = make_summary();

deficits = ...
    reqml.coverage.findCoverageDeficits( ...
        summary, ...
        MinimumExamples=4, ...
        MinimumIndependentRuns=2, ...
        MinimumIndependentConditions=1);

verifyEqual(testCase, ...
    height(deficits), ...
    2);

verifyEqual(testCase, ...
    deficits.cell_key, ...
    [ ...
        "s01_f02_p01_d01"
        "s01_f01_p01_d01"
    ]);

first = deficits.cell_key == ...
    "s01_f01_p01_d01";

second = deficits.cell_key == ...
    "s01_f02_p01_d01";

verifyEqual(testCase, ...
    deficits.example_deficit(first), ...
    1);

verifyEqual(testCase, ...
    deficits.independent_run_deficit(first), ...
    0);

verifyEqual(testCase, ...
    deficits.example_deficit(second), ...
    4);

verifyEqual(testCase, ...
    deficits.independent_run_deficit(second), ...
    2);

verifyTrue(testCase, ...
    all(deficits.sws_bin_deficit == 0));

verifyTrue(testCase, ...
    all(deficits.frequency_bin_deficit == 0));

end


function testReportsCompleteCoverage(testCase)

summary = make_summary();

summary.example_count(:) = 4;
summary.independent_run_count(:) = 2;
summary.independent_condition_count(:) = 1;

deficits = ...
    reqml.coverage.findCoverageDeficits( ...
        summary, ...
        MinimumExamples=4, ...
        MinimumIndependentRuns=2, ...
        MinimumIndependentConditions=1);

verifyEqual(testCase, ...
    height(deficits), ...
    0);

end


function summary = make_summary()

summary = table();

summary.sws_bin = [1; 1; 2];
summary.frequency_bin = [1; 2; 1];
summary.purity_bin = [1; 1; 1];
summary.diffusivity_bin = [1; 1; 1];

summary.cell_key = [
    "s01_f01_p01_d01"
    "s01_f02_p01_d01"
    "s02_f01_p01_d01"
    ];

summary.sws_label = [
    "[1.5,2)"
    "[1.5,2)"
    "[2,2.5)"
    ];

summary.frequency_label = [
    "[199,250)"
    "[250,350)"
    "[199,250)"
    ];

summary.purity_label = ...
    repmat("[0.5,0.7)", 3, 1);

summary.diffusivity_label = ...
    repmat("[0,0.01)", 3, 1);

summary.example_count = [3; 0; 4];
summary.independent_run_count = [2; 0; 2];
summary.independent_condition_count = [1; 0; 1];

end
