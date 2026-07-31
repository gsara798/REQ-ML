function tests = test_expand_condition_realizations
%TEST_EXPAND_CONDITION_REALIZATIONS Test adaptive run expansion.

tests = functiontests(localfunctions);

end


function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end


function testExpandsConditionsDeterministically(testCase)

conditions = make_conditions();

runs = reqml.campaigns.expandConditionRealizations( ...
    conditions);

verifyEqual(testCase, numel(runs), 3);

verifyEqual(testCase, ...
    string({runs.condition_id})', ...
    ["cond_000001"; "cond_000001"; "cond_000002"]);

verifyEqual(testCase, ...
    [runs.realization_id]', ...
    [1; 2; 1]);

verifyEqual(testCase, ...
    string({runs.design_id})', ...
    ["cond_000001_r001"; ...
     "cond_000001_r002"; ...
     "cond_000002_r001"]);

verifyEqual(testCase, ...
    runs(1).overrides(1).value, ...
    300);

verifyEqual(testCase, ...
    runs(3).overrides(1).value, ...
    500);

end


function testRejectsDuplicateConditions(testCase)

conditions = make_conditions();
conditions(2).condition_id = "cond_000001";

verifyError(testCase, ...
    @() reqml.campaigns.expandConditionRealizations( ...
        conditions), ...
    "reqml:DuplicateAdaptiveConditionId");

end


function conditions = make_conditions()

conditions = repmat(struct( ...
    "condition_id", "", ...
    "realization_count", 1, ...
    "overrides", struct([])), ...
    2, 1);

conditions(1).condition_id = "cond_000001";
conditions(1).realization_count = 2;
conditions(1).overrides = struct( ...
    "path", "wavefield.frequency_hz", ...
    "value", 300);

conditions(2).condition_id = "cond_000002";
conditions(2).realization_count = 1;
conditions(2).overrides = struct( ...
    "path", "wavefield.frequency_hz", ...
    "value", 500);

end
