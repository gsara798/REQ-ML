function paths = writeAdaptiveBatch( ...
    physical_conditions, campaign_config, options)
%WRITEADAPTIVEBATCH Write an auditable adaptive simulation batch.
%
% One swsynth campaign is written per resolved base configuration because
% simulation-campaign schema 1.2 supports one base_config per campaign.

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

output_directory = string(options.OutputDirectory);

if ~isfolder(output_directory)
    [created, message] = mkdir(output_directory);

    if ~created
        error("reqml:AdaptiveBatchDirectoryCreateFailed", ...
            "Could not create output directory '%s': %s", ...
            output_directory, message);
    end
end

all_runs = cell(numel(physical_conditions), 1);
base_configs = strings(numel(physical_conditions), 1);
families = strings(numel(physical_conditions), 1);

for condition_index = 1:numel(physical_conditions)
    condition = physical_conditions(condition_index);

    families(condition_index) = ...
        string(condition.geometry.family);

    base_configs(condition_index) = ...
        reqml.campaigns.resolveSwsynthBaseConfig( ...
            families(condition_index), ...
            campaign_config.base_config_mapping);

    all_runs{condition_index} = ...
        reqml.campaigns.physicalConditionToSwsynthRuns( ...
            condition);
end

runs = vertcat(all_runs{:});
validate_unique_design_ids(runs);

plan = struct();

plan.schema_name = "reqml_adaptive_batch_plan";
plan.schema_version = "1.2";
plan.batch_id = options.BatchId;
plan.planner_seed = options.PlannerSeed;

plan.parent_coverage_report_hash = ...
    options.ParentCoverageReportHash;

plan.condition_count = numel(physical_conditions);
plan.run_count = numel(runs);

plan.physical_conditions = physical_conditions;
plan.condition_base_configs = base_configs;
plan.runs = runs;

plan_path = fullfile( ...
    output_directory, ...
    "adaptive_batch_plan.json");

write_json(plan_path, plan);

unique_base_configs = unique(base_configs, "stable");
campaign_paths = strings(numel(unique_base_configs), 1);
campaign_families = strings(numel(unique_base_configs), 1);
campaign_run_counts = zeros(numel(unique_base_configs), 1);

for group_index = 1:numel(unique_base_configs)
    base_config = unique_base_configs(group_index);

    condition_mask = base_configs == base_config;
    group_families = unique(families(condition_mask));

    if numel(group_families) ~= 1
        error("reqml:AmbiguousSwsynthBaseConfigMapping", ...
            ["Multiple geometry families resolve to the same base config. " ...
             "Each adaptive campaign group must represent one family."]);
    end

    family = group_families(1);
    condition_indices = find(condition_mask);

    group_runs_cell = all_runs(condition_indices);
    group_runs = vertcat(group_runs_cell{:});

    campaign = make_campaign( ...
        group_runs, ...
        family, ...
        base_config, ...
        campaign_config);

    campaign_path = fullfile( ...
        output_directory, ...
        "simulation_campaign_" + family + ".json");

    write_json(campaign_path, campaign);

    campaign_paths(group_index) = ...
        string(campaign_path);

    campaign_families(group_index) = family;
    campaign_run_counts(group_index) = ...
        numel(group_runs);
end

paths = struct();
paths.plan = string(plan_path);

paths.simulation_campaigns = table( ...
    campaign_families(:), ...
    unique_base_configs(:), ...
    campaign_run_counts(:), ...
    campaign_paths(:), ...
    'VariableNames', { ...
        'geometry_family', ...
        'base_config', ...
        'run_count', ...
        'path'});

end


function campaign = make_campaign( ...
        runs, family, base_config, campaign_config)

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
campaign.backend = "swsynth";

campaign.campaign_name = sprintf( ...
    "%s_%s", ...
    string(campaign_config.campaign_name), ...
    family);

campaign.base_config = base_config;
campaign.runs = simulation_runs;

if isfield(campaign_config, "output")
    campaign.output = campaign_config.output;
end

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
    "base_config_mapping"
    ];

missing = setdiff( ...
    required, ...
    string(fieldnames(config)));

if ~isempty(missing)
    error("reqml:InvalidAdaptiveCampaignConfig", ...
        "Campaign configuration is missing field '%s'.", ...
        missing(1));
end

if lower(string(config.backend)) ~= "swsynth"
    error("reqml:UnsupportedAdaptiveCampaignBackend", ...
        "writeAdaptiveBatch currently supports only swsynth.");
end

if strlength(string(config.campaign_name)) == 0
    error("reqml:InvalidAdaptiveCampaignConfig", ...
        "campaign_name must be non-empty.");
end

if ~isstruct(config.base_config_mapping) || ...
        ~isscalar(config.base_config_mapping)

    error("reqml:InvalidAdaptiveCampaignConfig", ...
        "base_config_mapping must be a scalar struct.");
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
