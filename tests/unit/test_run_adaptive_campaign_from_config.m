function tests = test_run_adaptive_campaign_from_config
%TEST_RUN_ADAPTIVE_CAMPAIGN_FROM_CONFIG Test JSON campaign runner.

tests = functiontests(localfunctions);

end


function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end


function testLoadsAndTranslatesConfig(testCase)

root = string(tempname);
mkdir(root);

cleanup = onCleanup(@() cleanup_root(root));

previous_csv = fullfile(root, "previous.csv");
initial_batch = fullfile(root, "initial_batch");
framework_root = fullfile(root, "framework");
simulation_output = fullfile(root, "simulation_output");

mkdir(initial_batch);
mkdir(framework_root);
mkdir(simulation_output);

writetable( ...
    table([1;2], VariableNames="ordinal"), ...
    previous_csv);

base_directory = fullfile(root, "base_configs");
mkdir(base_directory);

families = [
    "homogeneous"
    "bilayer"
    "circular_inclusion"
    ];

for family = families'
    write_text( ...
        fullfile(base_directory, family + ".json"), ...
        "{}");
end

config = make_config( ...
    previous_csv, ...
    initial_batch, ...
    framework_root, ...
    simulation_output, ...
    base_directory);

config_file = fullfile(root, "config.json");

write_text( ...
    config_file, ...
    jsonencode(config, PrettyPrint=true));

result = ...
    reqml.campaigns.runAdaptiveCampaignFromConfig( ...
        config_file, ...
        RunLoopFunction=@fake_loop);

verifyEqual(testCase, ...
    result.campaign_id, ...
    "json_test");

verifyEqual(testCase, ...
    result.maximum_iterations, ...
    4);

verifyEqual(testCase, ...
    result.minimum_examples, ...
    25);

verifyEqual(testCase, ...
    result.diffusivity_edges, ...
    [0 0.1 0.5 1]);

verifyTrue(testCase, ...
    result.resume_existing_loop);

verifyEqual(testCase, ...
    string(result.campaign_config.backend), ...
    "swsynth");

verifyEqual(testCase, ...
    string(result.config_file), ...
    string(config_file));

clear cleanup

end


function result = fake_loop( ...
        previous_csv, initial_batch, ...
        feat_cfg, campaign_config, ...
        framework_root, options) %#ok<INUSD>

arguments
    previous_csv
    initial_batch
    feat_cfg
    campaign_config
    framework_root

    options.OutputRoot
    options.CampaignId
    options.MaximumIterations
    options.PlannerSeed

    options.PurityEdges
    options.DiffusivityEdges
    options.SwsEdges
    options.FrequencyEdges

    options.MinimumExamples
    options.MinimumIndependentRuns
    options.MinimumSwsBins
    options.MinimumFrequencyBins
    options.MinimumIndependentConditions
    options.MinimumGeometrySeeds

    options.MaximumConditions
    options.RealizationsPerCondition

    options.Resume
    options.ContinueOnError
    options.ResumeExistingLoop
end

result = struct();

result.campaign_id = string(options.CampaignId);

result.maximum_iterations = ...
    options.MaximumIterations;

result.minimum_examples = ...
    options.MinimumExamples;

result.diffusivity_edges = ...
    options.DiffusivityEdges;

result.resume_existing_loop = ...
    options.ResumeExistingLoop;

result.campaign_config = ...
    campaign_config;

end


function config = make_config( ...
        previous_csv, initial_batch, ...
        framework_root, simulation_output, ...
        base_directory)

config = struct();

config.schema_name = ...
    "reqml_adaptive_campaign_config";

config.schema_version = "1.0";
config.campaign_id = "json_test";

config.paths = struct( ...
    "previous_campaign_csv", previous_csv, ...
    "initial_batch_directory", initial_batch, ...
    "output_root", fullfile( ...
        fileparts(previous_csv), "loop_output"), ...
    "simulation_framework_root", framework_root);

config.simulation = struct();

config.simulation.backend = "swsynth";

config.simulation.output_directory = ...
    simulation_output;

config.simulation.base_config_mapping = struct( ...
    "homogeneous", ...
        fullfile(base_directory, "homogeneous.json"), ...
    "bilayer", ...
        fullfile(base_directory, "bilayer.json"), ...
    "circular_inclusion", ...
        fullfile(base_directory, ...
            "circular_inclusion.json"));

config.coverage = struct( ...
    "purity_edges", ...
        [0.5 0.7 0.9 1.0], ...
    "nominal_angular_coverage_edges", ...
        [0 0.1 0.5 1.0], ...
    "sws_edges_m_s", ...
        [1.5 2.5 4.0], ...
    "frequency_edges_hz", ...
        [199 400 601]);

config.requirements = struct( ...
    "minimum_examples", 25, ...
    "minimum_independent_runs", 2, ...
    "minimum_independent_conditions", 2, ...
    "minimum_sws_bins", 2, ...
    "minimum_frequency_bins", 2, ...
    "minimum_geometry_seeds", 0);

config.planning = struct( ...
    "maximum_conditions", 8, ...
    "realizations_per_condition", 2);

config.execution = struct( ...
    "maximum_iterations", 4, ...
    "planner_seed", 40001, ...
    "resume_runs", true, ...
    "continue_on_error", false, ...
    "resume_existing_loop", true);

end


function write_text(path_value, content)

file_id = fopen(path_value, "w");
assert(file_id >= 0);

cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id, "%s", content);
clear cleanup

end


function cleanup_root(root)

if isfolder(root)
    rmdir(root, "s");
end

end
