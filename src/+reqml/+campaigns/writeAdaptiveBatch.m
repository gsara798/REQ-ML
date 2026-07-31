function paths = writeAdaptiveBatch( ...
    physical_conditions, campaign_config, options)
%WRITEADAPTIVEBATCH Write an auditable adaptive simulation batch.
%
% Inputs:
%
%   physical_conditions
%       Backend-neutral physical conditions produced by
%       materializePhysicalConditions.
%
%   campaign_config
%       Backend-specific campaign header information.
%
% Outputs:
%
%   adaptive_batch_plan.json
%   simulation_campaign.json
%
% The adaptive plan preserves physical conditions, condition IDs, and
% realization IDs. The simulation campaign is compatible with simulation
% campaign schema 1.2.

arguments
    physical_conditions (:,1) struct
    campaign_config (1,1) struct

    options.OutputDirectory {mustBeTextScalar}
    options.BatchId (1,1) string
    options.PlannerSeed (1,1) double
    options.ParentCoverageReportHash (1,1) string = ""
end

validate_campaign_config(campaign_config);
validate_options(options);

if isempty(physical_conditions)
    error("reqml:EmptyAdaptivePhysicalConditions", ...
        "At least one physical condition is required.");
end

all_runs = cell(numel(physical_conditions), 1);

for condition_index = 1:numel(physical_conditions)
    all_runs{condition_index} = ...
        reqml.campaigns.physicalConditionToSwsynthRuns( ...
            physical_conditions(condition_index));
end

runs = vertcat(all_runs{:});

validate_unique_design_ids(runs);

output_directory = string(options.OutputDirectory);

if ~isfolder(output_directory)
    [created, message] = mkdir(output_directory);

    if ~created
        error("reqml:AdaptiveBatchDirectoryCreateFailed", ...
            "Could not create output directory '%s': %s", ...
            output_directory, message);
    end
end

plan = struct();

plan.schema_name = "reqml_adaptive_batch_plan";
plan.schema_version = "1.1";
plan.batch_id = options.BatchId;
plan.planner_seed = options.PlannerSeed;

plan.parent_coverage_report_hash = ...
    options.ParentCoverageReportHash;

plan.condition_count = ...
    numel(physical_conditions);

plan.run_count = ...
    numel(runs);

plan.physical_conditions = ...
    physical_conditions;

plan.runs = runs;

simulation_runs = repmat(struct( ...
    "design_id", "", ...
    "overrides", struct([])), ...
    numel(runs), ...
    1);

for index = 1:numel(runs)
    simulation_runs(index).design_id = ...
        runs(index).design_id;

    simulation_runs(index).overrides = ...
        runs(index).overrides;
end

campaign = struct();

campaign.schema_version = "1.2";
campaign.backend = ...
    lower(string(campaign_config.backend));

campaign.campaign_name = ...
    string(campaign_config.campaign_name);

campaign.base_config = ...
    string(campaign_config.base_config);

campaign.runs = simulation_runs;

if isfield(campaign_config, "output")
    campaign.output = campaign_config.output;
end

plan_path = fullfile( ...
    output_directory, ...
    "adaptive_batch_plan.json");

campaign_path = fullfile( ...
    output_directory, ...
    "simulation_campaign.json");

write_json(plan_path, plan);
write_json(campaign_path, campaign);

paths = struct();
paths.plan = string(plan_path);
paths.simulation_campaign = string(campaign_path);

end


function validate_unique_design_ids(runs)

design_ids = string({runs.design_id})';

if numel(unique(design_ids)) ~= numel(design_ids)
    error("reqml:DuplicateAdaptiveDesignId", ...
        "Adaptive batch design IDs must be unique.");
end

end


function validate_campaign_config(config)

required = [
    "backend"
    "campaign_name"
    "base_config"
    ];

missing = setdiff( ...
    required, ...
    string(fieldnames(config)));

if ~isempty(missing)
    error("reqml:InvalidAdaptiveCampaignConfig", ...
        "Campaign configuration is missing field '%s'.", ...
        missing(1));
end

for name = required.'
    value = string(config.(name));

    if ~isscalar(value) || strlength(value) == 0
        error("reqml:InvalidAdaptiveCampaignConfig", ...
            "Campaign configuration field '%s' must be non-empty.", ...
            name);
    end
end

if lower(string(config.backend)) ~= "swsynth"
    error("reqml:UnsupportedAdaptiveCampaignBackend", ...
        "writeAdaptiveBatch currently supports only the swsynth backend.");
end

end


function validate_options(options)

if strlength(options.BatchId) == 0
    error("reqml:InvalidAdaptiveBatchId", ...
        "BatchId must be non-empty.");
end

if ~isfinite(options.PlannerSeed) || ...
        options.PlannerSeed < 0 || ...
        options.PlannerSeed ~= fix(options.PlannerSeed)

    error("reqml:InvalidAdaptivePlannerSeed", ...
        "PlannerSeed must be a nonnegative integer.");
end

end


function write_json(path_value, value)

temporary_path = string(path_value) + ".tmp";

delete_if_present(temporary_path);

file_id = fopen(temporary_path, "w");

if file_id < 0
    error("reqml:AdaptiveBatchWriteFailed", ...
        "Could not create file '%s'.", ...
        temporary_path);
end

cleanup = onCleanup(@() fclose(file_id));

fprintf(file_id, "%s", ...
    jsonencode(value, PrettyPrint=true));

clear cleanup

[moved, message] = movefile( ...
    temporary_path, ...
    path_value, ...
    "f");

if ~moved
    delete_if_present(temporary_path);

    error("reqml:AdaptiveBatchWriteFailed", ...
        "Could not publish file '%s': %s", ...
        path_value, message);
end

end


function delete_if_present(path_value)

if isfile(path_value)
    delete(path_value);
end

end
