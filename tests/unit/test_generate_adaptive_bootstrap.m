function tests = test_generate_adaptive_bootstrap
%TEST_GENERATE_ADAPTIVE_BOOTSTRAP

tests = functiontests(localfunctions);

end


function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end


function testGeneratesAuditableBootstrapBatch(testCase)

root = string(testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture).Folder);

output_directory = fullfile( ...
    root, ...
    "bootstrap_iteration");

coverage = make_coverage();
campaign_config = make_campaign_config(root);

result = ...
    reqml.campaigns.generateAdaptiveBootstrap( ...
        coverage, ...
        campaign_config, ...
        OutputDirectory=output_directory, ...
        BatchId="bootstrap_test", ...
        PlannerSeed=42001, ...
        RealizationsPerCondition=2);

verifyEqual(testCase, ...
    result.schema_name, ...
    "reqml_adaptive_bootstrap_result");

verifyEqual(testCase, result.request_count, 75);
verifyEqual(testCase, result.condition_count, 75);
verifyEqual(testCase, result.run_count, 150);

verifyTrue(testCase, ...
    isfile(result.paths.plan));

verifyEqual(testCase, ...
    height(result.paths.simulation_campaigns), ...
    3);

verifyTrue(testCase, ...
    all(isfile( ...
        result.paths.simulation_campaigns.path)));

plan = jsondecode( ...
    fileread(result.paths.plan));

verifyEqual(testCase, ...
    string(plan.schema_name), ...
    "reqml_adaptive_batch_plan");

verifyEqual(testCase, ...
    double(plan.condition_count), ...
    75);

verifyEqual(testCase, ...
    double(plan.run_count), ...
    150);

verifyEqual(testCase, ...
    string(plan.batch_id), ...
    "bootstrap_test");

conditions = plan.physical_conditions;

blocks = zeros(numel(conditions), 3);

for index = 1:numel(conditions)
    requested = ...
        conditions(index).requested_coverage;

    blocks(index, :) = [
        requested.sws_bin
        requested.frequency_bin
        requested.discretization_bin
        ]';

    verifyEqual(testCase, ...
        conditions(index).discretization.dx_m, ...
        requested.grid_spacing_m(1), ...
        AbsTol=1e-15);

    verifyEqual(testCase, ...
        conditions(index).discretization.dz_m, ...
        requested.grid_spacing_m(2), ...
        AbsTol=1e-15);

    verifyTrue(testCase, ...
        isfield(requested, ...
            "sws_range_m_s"));

    verifyTrue(testCase, ...
        isfield(requested, ...
            "frequency_range_hz"));
end

verifyEqual(testCase, ...
    size(unique(blocks, "rows"), 1), ...
    75);

end


function testGenerationIsDeterministic(testCase)

root = string(testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture).Folder);

coverage = make_coverage();
campaign_config = make_campaign_config(root);

a = reqml.campaigns.generateAdaptiveBootstrap( ...
    coverage, ...
    campaign_config, ...
    OutputDirectory=fullfile(root, "a"), ...
    BatchId="bootstrap_test", ...
    PlannerSeed=42001);

b = reqml.campaigns.generateAdaptiveBootstrap( ...
    coverage, ...
    campaign_config, ...
    OutputDirectory=fullfile(root, "b"), ...
    BatchId="bootstrap_test", ...
    PlannerSeed=42001);

verifyEqual(testCase, a.requests, b.requests);

verifyEqual(testCase, ...
    a.physical_conditions, ...
    b.physical_conditions);

plan_a = jsondecode(fileread(a.paths.plan));
plan_b = jsondecode(fileread(b.paths.plan));

verifyEqual(testCase, ...
    plan_a.physical_conditions, ...
    plan_b.physical_conditions);

verifyEqual(testCase, ...
    plan_a.runs, ...
    plan_b.runs);

end


function testRejectsNonemptyOutputDirectory(testCase)

root = string(testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture).Folder);

output_directory = fullfile(root, "existing");
mkdir(output_directory);

file_id = fopen( ...
    fullfile(output_directory, "existing.txt"), ...
    "w");

fprintf(file_id, "existing");
fclose(file_id);

coverage = make_coverage();
campaign_config = make_campaign_config(root);

verifyError(testCase, ...
    @() reqml.campaigns.generateAdaptiveBootstrap( ...
        coverage, ...
        campaign_config, ...
        OutputDirectory=output_directory, ...
        BatchId="bootstrap_test"), ...
    "reqml:AdaptiveBootstrapOutputExists");

end


function coverage = make_coverage()

coverage = struct();

coverage.sws_edges_m_s = ...
    [1.5 2.0 2.5 3.0 3.5 4.0];

coverage.frequency_edges_hz = ...
    [199 250 350 450 550 601];

coverage.purity_edges = ...
    [0.5 0.7 0.9 0.98 1.0];

coverage.nominal_angular_coverage_edges = ...
    [0 0.01 0.05 0.20 0.50 1.0];

coverage.discretization_pairs_m = [
    0.25e-3 0.25e-3
    0.40e-3 0.40e-3
    0.50e-3 0.50e-3
    ];

end


function campaign_config = ...
        make_campaign_config(root)

base_directory = fullfile(root, "base_configs");
mkdir(base_directory);

families = [
    "homogeneous"
    "bilayer"
    "circular_inclusion"
    ];

mapping = struct();

for index = 1:numel(families)
    family = families(index);

    path_value = fullfile( ...
        base_directory, ...
        family + ".json");

    file_id = fopen(path_value, "w");
    fprintf(file_id, "{}");
    fclose(file_id);

    mapping.(family) = path_value;
end

campaign_config = struct();

campaign_config.backend = "swsynth";
campaign_config.campaign_name = "bootstrap_test";

campaign_config.base_config_mapping = mapping;

campaign_config.output = struct( ...
    "directory", ...
    fullfile(root, "simulation_outputs"));

end
