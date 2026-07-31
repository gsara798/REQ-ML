function tests = test_write_adaptive_batch
%TEST_WRITE_ADAPTIVE_BATCH Test adaptive batch artifacts.

tests = functiontests(localfunctions);

end


function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end


function testWritesPlanAndCompatibleCampaign(testCase)

output_directory = string(tempname);
cleanup = onCleanup(@() cleanup_directory( ...
    output_directory));

condition = struct();
condition.condition_id = "cond_000001";
condition.realization_count = 2;
condition.overrides = struct( ...
    "path", "wavefield.frequency_hz", ...
    "value", 400);

campaign_config = struct();
campaign_config.backend = "swsynth";
campaign_config.campaign_name = ...
    "reqml_adaptive_batch_001";
campaign_config.base_config = ...
    "configs/swsynth/base.json";

paths = reqml.campaigns.writeAdaptiveBatch( ...
    condition, ...
    campaign_config, ...
    OutputDirectory=output_directory, ...
    BatchId="batch_001", ...
    PlannerSeed=17001, ...
    ParentCoverageReportHash="coverage_hash");

verifyTrue(testCase, isfile(paths.plan));
verifyTrue(testCase, ...
    isfile(paths.simulation_campaign));

plan = jsondecode(fileread(paths.plan));
campaign = jsondecode(fileread( ...
    paths.simulation_campaign));

verifyEqual(testCase, ...
    string(plan.schema_name), ...
    "reqml_adaptive_batch_plan");

verifyEqual(testCase, plan.condition_count, 1);
verifyEqual(testCase, plan.run_count, 2);

verifyEqual(testCase, ...
    string(plan.runs(1).condition_id), ...
    "cond_000001");

verifyEqual(testCase, ...
    plan.runs(2).realization_id, ...
    2);

verifyEqual(testCase, ...
    string(campaign.schema_version), ...
    "1.2");

verifyEqual(testCase, ...
    string(campaign.runs(1).design_id), ...
    "cond_000001_r001");

verifyFalse(testCase, ...
    isfield(campaign.runs, "condition_id"));

clear cleanup

end


function cleanup_directory(directory)

if isfolder(directory)
    rmdir(directory, "s");
end

end
