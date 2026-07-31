function tests = test_plan_next_adaptive_batch
%TEST_PLAN_NEXT_ADAPTIVE_BATCH Test complete adaptive planning.

tests = functiontests(localfunctions);

end


function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end


function testPlansAndWritesNextBatch(testCase)

coverage_report = make_coverage_report();

output_directory = string(tempname);

cleanup = onCleanup(@() cleanup_directory( ...
    output_directory));

campaign_config = make_campaign_config();

result = reqml.campaigns.planNextAdaptiveBatch( ...
    coverage_report, ...
    campaign_config, ...
    OutputDirectory=output_directory, ...
    BatchId="batch_002", ...
    PlannerSeed=19001, ...
    MaximumConditions=2, ...
    RealizationsPerCondition=2, ...
    ParentCoverageReportHash="coverage_hash");

verifyTrue(testCase, result.batch_required);
verifyFalse(testCase, result.coverage_complete);

verifyEqual(testCase, result.request_count, 2);
verifyEqual(testCase, result.condition_count, 2);
verifyEqual(testCase, result.run_count, 4);

verifyTrue(testCase, isfile(result.paths.plan));

verifyTrue(testCase, ...
    isfile(result.paths.simulation_campaign));

campaign = jsondecode(fileread( ...
    result.paths.simulation_campaign));

verifyEqual(testCase, numel(campaign.runs), 4);

verifyEqual(testCase, ...
    string(campaign.schema_version), ...
    "1.2");

verifyTrue(testCase, ...
    all(startsWith( ...
        string({campaign.runs.design_id})', ...
        "adaptive_")));

clear cleanup

end


function testReturnsNoBatchWhenCoverageIsComplete(testCase)

coverage_report = make_coverage_report();

coverage_report.deficits = ...
    coverage_report.deficits([], :);

campaign_config = make_campaign_config();

result = reqml.campaigns.planNextAdaptiveBatch( ...
    coverage_report, ...
    campaign_config, ...
    OutputDirectory=string(tempname), ...
    BatchId="batch_complete", ...
    PlannerSeed=1);

verifyFalse(testCase, result.batch_required);
verifyTrue(testCase, result.coverage_complete);

verifyEqual(testCase, result.request_count, 0);
verifyEqual(testCase, result.run_count, 0);

verifyFalse(testCase, isfield(result.paths, "plan"));

end


function testPlanningIsReproducible(testCase)

coverage_report = make_coverage_report();
campaign_config = make_campaign_config();

output_a = string(tempname);
output_b = string(tempname);

cleanup_a = onCleanup(@() cleanup_directory(output_a));
cleanup_b = onCleanup(@() cleanup_directory(output_b));

a = reqml.campaigns.planNextAdaptiveBatch( ...
    coverage_report, ...
    campaign_config, ...
    OutputDirectory=output_a, ...
    BatchId="batch_a", ...
    PlannerSeed=777);

b = reqml.campaigns.planNextAdaptiveBatch( ...
    coverage_report, ...
    campaign_config, ...
    OutputDirectory=output_b, ...
    BatchId="batch_b", ...
    PlannerSeed=777);

verifyEqual(testCase, ...
    a.physical_conditions, ...
    b.physical_conditions);

campaign_a = jsondecode(fileread( ...
    a.paths.simulation_campaign));

campaign_b = jsondecode(fileread( ...
    b.paths.simulation_campaign));

verifyEqual(testCase, ...
    campaign_a.runs, ...
    campaign_b.runs);

clear cleanup_a cleanup_b

end


function report = make_coverage_report()

deficits = table();

deficits.purity_bin = [1; 3];
deficits.diffusivity_bin = [1; 3];

deficits.purity_label = ...
    ["[0.5,0.7)"; "[0.9,1]"];

deficits.diffusivity_label = ...
    ["[0,0.4)"; "[0.7,1]"];

deficits.example_deficit = [400; 200];
deficits.independent_run_deficit = [4; 2];
deficits.sws_bin_deficit = [2; 1];
deficits.frequency_bin_deficit = [2; 1];

deficits.independent_condition_deficit = ...
    [3; 1];

deficits.geometry_seed_deficit = [0; 0];
deficits.deficit_score = [3.2; 1.4];

report = struct();
report.deficits = deficits;

report.config = struct();

report.config.purity_edges = ...
    [0.5 0.7 0.9 1.0];

report.config.diffusivity_edges = ...
    [0 0.4 0.7 1.0];

report.config.sws_edges = ...
    [1.5 2.5 3.5 4.1];

report.config.frequency_edges = ...
    [199 350 450 601];

end


function config = make_campaign_config()

config = struct();
config.backend = "swsynth";

config.campaign_name = ...
    "reqml_adaptive_next_batch";

config.base_config = ...
    "configs/swsynth/scientific/" + ...
    "reqml_eikonal_training_v1/" + ...
    "circular_inclusion_base.json";

end


function cleanup_directory(directory)

if isfolder(directory)
    rmdir(directory, "s");
end

end
