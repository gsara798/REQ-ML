function result = executeAdaptiveBatch( ...
    batch_directory, simulation_framework_root, options)
%EXECUTEADAPTIVEBATCH Execute all simulation campaigns in an adaptive batch.
%
% Workflow:
%
%   adaptive batch directory
%       -> discover simulation_campaign_*.json
%       -> temporarily add simulation framework src
%       -> run simcampaigns.runCampaignSet
%       -> verify campaign success
%       -> return generated campaign_runs.csv files

arguments
    batch_directory {mustBeTextScalar}
    simulation_framework_root {mustBeTextScalar}

    options.Resume (1,1) logical = true
    options.ContinueOnError (1,1) logical = false
end

batch_directory = string(batch_directory);
simulation_framework_root = ...
    string(simulation_framework_root);

validate_directories( ...
    batch_directory, ...
    simulation_framework_root);

campaign_files = discover_campaign_files( ...
    batch_directory);

framework_src = fullfile( ...
    simulation_framework_root, ...
    "src");

path_entries = string( ...
    strsplit(path, pathsep));

added_framework_path = ...
    ~any(path_entries == framework_src);

if added_framework_path
    addpath(framework_src);
    rehash;
end

cleanup = onCleanup(@() restore_path( ...
    framework_src, ...
    added_framework_path));

try
    execution = simcampaigns.runCampaignSet( ...
        campaign_files, ...
        Resume=options.Resume, ...
        ContinueOnError=options.ContinueOnError);
catch exception
    error("reqml:AdaptiveBatchExecutionFailed", ...
        "Adaptive batch execution failed: %s", ...
        exception.message);
end

validate_execution_result( ...
    execution, ...
    numel(campaign_files));

campaign_csv_files = extract_campaign_csv_files( ...
    execution);

result = struct();

result.schema_name = ...
    "reqml_adaptive_batch_execution";

result.schema_version = "1.0";

result.batch_directory = batch_directory;

result.simulation_framework_root = ...
    simulation_framework_root;

result.campaign_count = ...
    double(execution.campaign_count);

result.run_count = ...
    double(execution.run_count);

result.completed_count = ...
    double(execution.completed_count);

result.skipped_count = ...
    double(execution.skipped_count);

result.failed_count = ...
    double(execution.failed_count);

result.success = logical(execution.success);

result.campaign_files = campaign_files;

result.campaign_csv_files = ...
    campaign_csv_files;

result.execution = execution;

clear cleanup

end


function validate_directories( ...
        batch_directory, simulation_framework_root)

if ~isfolder(batch_directory)
    error("reqml:AdaptiveBatchDirectoryNotFound", ...
        "Adaptive batch directory was not found: %s", ...
        batch_directory);
end

framework_src = fullfile( ...
    simulation_framework_root, ...
    "src");

if ~isfolder(framework_src)
    error("reqml:SimulationFrameworkSourceNotFound", ...
        "Simulation framework source directory was not found: %s", ...
        framework_src);
end

end


function campaign_files = discover_campaign_files( ...
        batch_directory)

files = dir(fullfile( ...
    batch_directory, ...
    "simulation_campaign_*.json"));

if isempty(files)
    error("reqml:NoAdaptiveSimulationCampaigns", ...
        "No simulation_campaign_*.json files were found in: %s", ...
        batch_directory);
end

campaign_files = strings(numel(files), 1);

for index = 1:numel(files)
    campaign_files(index) = fullfile( ...
        files(index).folder, ...
        files(index).name);
end

campaign_files = sort(campaign_files);

end


function validate_execution_result( ...
        execution, expected_campaign_count)

required = [
    "campaign_count"
    "run_count"
    "completed_count"
    "skipped_count"
    "failed_count"
    "success"
    "campaigns"
    ];

missing = setdiff( ...
    required, ...
    string(fieldnames(execution)));

if ~isempty(missing)
    error("reqml:InvalidAdaptiveBatchExecutionResult", ...
        "Campaign-set result is missing field '%s'.", ...
        missing(1));
end

if execution.campaign_count ~= ...
        expected_campaign_count

    error("reqml:AdaptiveBatchCampaignCountMismatch", ...
        ["Campaign runner reported %d campaigns; " ...
         "expected %d."], ...
        execution.campaign_count, ...
        expected_campaign_count);
end

if ~execution.success || ...
        execution.failed_count ~= 0

    error("reqml:AdaptiveBatchSimulationFailure", ...
        ["Adaptive batch execution was unsuccessful: " ...
         "%d failed runs."], ...
        execution.failed_count);
end

if execution.completed_count + ...
        execution.skipped_count ~= ...
        execution.run_count

    error("reqml:AdaptiveBatchRunAccountingMismatch", ...
        ["Completed and skipped runs do not account " ...
         "for all requested runs."]);
end

end


function csv_files = extract_campaign_csv_files(execution)

campaigns = execution.campaigns;

if isempty(campaigns)
    error("reqml:EmptyAdaptiveCampaignExecutionList", ...
        "Campaign runner returned no campaign records.");
end

if ~isfield(campaigns, "campaign_runs_csv")
    error("reqml:MissingAdaptiveCampaignCsvPath", ...
        ["Campaign execution records do not contain " ...
         "campaign_runs_csv."]);
end

csv_files = string( ...
    {campaigns.campaign_runs_csv})';

if any(strlength(csv_files) == 0)
    error("reqml:MissingAdaptiveCampaignCsvPath", ...
        "At least one campaign_runs_csv path is empty.");
end

for index = 1:numel(csv_files)
    if ~isfile(csv_files(index))
        error("reqml:AdaptiveCampaignCsvNotFound", ...
            "Executed campaign CSV was not found: %s", ...
            csv_files(index));
    end
end

csv_files = sort(csv_files);

end


function restore_path(framework_src, added_framework_path)

if added_framework_path
    rmpath(framework_src);
    rehash;
end

end
