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
    all(isfile( ...
        result.paths.simulation_campaigns.path)));

verifyEqual(testCase, ...
    sum(result.paths.simulation_campaigns.run_count), ...
    4);

all_design_ids = strings(0, 1);

for index = 1:height( ...
        result.paths.simulation_campaigns)

    campaign = jsondecode(fileread( ...
        result.paths.simulation_campaigns.path(index)));

    verifyEqual(testCase, ...
        string(campaign.schema_version), ...
        "1.2");

    all_design_ids = [
        all_design_ids
        string({campaign.runs.design_id})'
        ]; %#ok<AGROW>
end

verifyTrue(testCase, ...
    all(startsWith( ...
        all_design_ids, ...
        "batch_002_")));

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
    BatchId="reproducible_batch", ...
    PlannerSeed=777);

b = reqml.campaigns.planNextAdaptiveBatch( ...
    coverage_report, ...
    campaign_config, ...
    OutputDirectory=output_b, ...
    BatchId="reproducible_batch", ...
    PlannerSeed=777);

verifyEqual(testCase, ...
    a.physical_conditions, ...
    b.physical_conditions);

verifyEqual(testCase, ...
    a.paths.simulation_campaigns.geometry_family, ...
    b.paths.simulation_campaigns.geometry_family);

verifyEqual(testCase, ...
    a.paths.simulation_campaigns.base_config, ...
    b.paths.simulation_campaigns.base_config);

verifyEqual(testCase, ...
    a.paths.simulation_campaigns.run_count, ...
    b.paths.simulation_campaigns.run_count);

for index = 1:height( ...
        a.paths.simulation_campaigns)

    campaign_a = jsondecode(fileread( ...
        a.paths.simulation_campaigns.path(index)));

    campaign_b = jsondecode(fileread( ...
        b.paths.simulation_campaigns.path(index)));

    verifyEqual(testCase, ...
        campaign_a.runs, ...
        campaign_b.runs);
end

clear cleanup_a cleanup_b

end


function testDifferentBatchIdsProduceDisjointConditionIds(testCase)

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
    BatchId="iteration_001_next", ...
    PlannerSeed=1001, ...
    MaximumConditions=2);

b = reqml.campaigns.planNextAdaptiveBatch( ...
    coverage_report, ...
    campaign_config, ...
    OutputDirectory=output_b, ...
    BatchId="iteration_002_next", ...
    PlannerSeed=2001, ...
    MaximumConditions=2);

ids_a = string({a.physical_conditions.condition_id})';
ids_b = string({b.physical_conditions.condition_id})';

verifyEmpty(testCase, intersect(ids_a, ids_b));

verifyTrue(testCase, ...
    all(startsWith(ids_a, "iteration_001_next_")));

verifyTrue(testCase, ...
    all(startsWith(ids_b, "iteration_002_next_")));

clear cleanup_a cleanup_b

end


function report = make_coverage_report()

deficits = table();

deficits.sws_bin = [2; 3];
deficits.frequency_bin = [2; 3];

deficits.purity_bin = [1; 3];
deficits.diffusivity_bin = [1; 3];

deficits.purity_label = ...
    ["[0.5,0.7)"; "[0.9,1]"];

deficits.diffusivity_label = ...
    ["[0,0.4)"; "[0.7,1]"];

deficits.example_deficit = [400; 200];
deficits.independent_run_deficit = [4; 2];

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

assigned = table();

assigned.coverage_purity_bin = [1; 1; 3];
assigned.coverage_diffusivity_bin = [1; 1; 3];
assigned.coverage_valid = true(3, 1);

assigned.campaign_geometry_family = [
    "bilayer"
    "bilayer"
    "bilayer"
    ];

assigned.campaign_run_id = [
    "historical_run_1"
    "historical_run_2"
    "historical_run_3"
    ];

report.assigned_examples = assigned;

end


function config = make_campaign_config()

root = "configs/swsynth/scientific/" + ...
    "reqml_eikonal_training_v1/";

config = struct();
config.backend = "swsynth";
config.campaign_name = ...
    "reqml_adaptive_next_batch";

config.base_config_mapping = struct( ...
    "homogeneous", root + "homogeneous_base.json", ...
    "bilayer", root + "bilayer_base.json", ...
    "circular_inclusion", ...
        root + "circular_inclusion_base.json");

end


function cleanup_directory(directory)

if isfolder(directory)
    rmdir(directory, "s");
end

end
