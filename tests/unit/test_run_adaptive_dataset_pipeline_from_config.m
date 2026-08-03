function tests = test_run_adaptive_dataset_pipeline_from_config

tests = functiontests(localfunctions);

end


function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end


function testPreparesBalancedDatasetAfterCompleteCampaign(testCase)

root = string(tempname);
mkdir(root);

cleanup = onCleanup(@() cleanup_root(root));

config_file = fullfile(root, "config.json");
training_output = fullfile(root, "training");

config = struct();

config.coverage = struct( ...
    "purity_edges", [0.5 0.7 1.0], ...
    "nominal_angular_coverage_edges", [0 0.5 1.0], ...
    "sws_edges_m_s", [1.5 3.0 4.0], ...
    "frequency_edges_hz", [199 400 601]);

write_text( ...
    config_file, ...
    jsonencode(config));

result = ...
    reqml.campaigns.runAdaptiveDatasetPipelineFromConfig( ...
        config_file, ...
        TrainingOutputDirectory=training_output, ...
        MaximumConditionsPerCell=5, ...
        MaximumRunsPerConditionPerCell=2, ...
        MaximumPatchesPerRunPerCell=3, ...
        TrainingRandomSeed=71, ...
        RunCampaignFunction=@fake_campaign, ...
        BalanceFunction=@fake_balance);

verifyEqual(testCase, ...
    result.campaign.coverage_complete, ...
    true);

verifyEqual(testCase, ...
    result.training_balance.selected_example_count, ...
    4);

verifyEqual(testCase, ...
    result.paths.balanced_examples_file, ...
    string(fullfile(training_output, "balanced.mat")));

clear cleanup

end


function campaign = fake_campaign(~)

root = string(tempname);
mkdir(root);

dataset_directory = fullfile(root, "dataset");
mkdir(dataset_directory);

examples = table( ...
    [1; 2; 3; 4], ...
    VariableNames="ordinal"); %#ok<NASGU>

save(fullfile(dataset_directory, "examples.mat"), ...
    "examples");

campaign = struct();

campaign.coverage_complete = true;
campaign.final_deficient_cell_count = 0;
campaign.final_iteration_directory = root;

end


function result = fake_balance( ...
        examples, options) %#ok<INUSD>

arguments
    examples table

    options.PurityEdges
    options.NominalAngularCoverageEdges
    options.SwsEdges
    options.FrequencyEdges

    options.MaximumConditionsPerCell
    options.MaximumRunsPerConditionPerCell
    options.MaximumPatchesPerRunPerCell
    options.RandomSeed
    options.OutputDirectory
    options.SaveOutputs
end

mkdir(options.OutputDirectory);

balanced_path = fullfile( ...
    options.OutputDirectory, ...
    "balanced.mat");

summary_path = fullfile( ...
    options.OutputDirectory, ...
    "summary.csv");

save(balanced_path, "examples");
writetable(table(4, VariableNames="count"), summary_path);

result = struct();

result.selected_example_count = 4;

result.paths = struct( ...
    "examples_mat", string(balanced_path), ...
    "summary_csv", string(summary_path));

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
