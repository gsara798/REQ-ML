function inventory = load_campaign_samples( ...
    campaign_runs_csv, options)
%LOAD_CAMPAIGN_SAMPLES Load and validate reusable campaign sample metadata.
%
% This function performs inventory construction only. It does not load
% wavefield_sample.mat contents or run REQ.

arguments
    campaign_runs_csv {mustBeTextScalar}
    options.MaxSamples (1,1) double = Inf
    options.RequireBackend (1,1) string = ""
    options.RequireAllPaths (1,1) logical = true
end

campaign_runs_csv = string(campaign_runs_csv);

if ~isfile(campaign_runs_csv)
    error("reqml:CampaignRunsCsvNotFound", ...
        "Campaign CSV was not found: %s", campaign_runs_csv);
end

validate_max_samples(options.MaxSamples);

opts = detectImportOptions( ...
    campaign_runs_csv, ...
    Delimiter=",", ...
    TextType="string");

runs = readtable(campaign_runs_csv, opts);

required_columns = [
    "ordinal"
    "run_id"
    "backend"
    "hash_sha256"
    "status"
    "outcome_status"
    "scenario"
    "seed"
    "frequency_hz"
    "background_cs_m_s"
    "direction_count"
    "valid"
    "run_directory"
    "resolved_config_path"
    "wavefield_sample_path"
    "summary_path"
    "validation_report_path"
    ];

require_columns(runs, required_columns);
runs = normalize_text_columns(runs);

selected = ...
    (runs.status == "completed" | runs.status == "skipped_completed") & ...
    runs.outcome_status == "completed_valid" & ...
    double(runs.valid) == 1;

if strlength(options.RequireBackend) > 0
    selected = selected & runs.backend == options.RequireBackend;
end

rejected = runs(~selected, :);
samples = sortrows(runs(selected, :), "ordinal");

if isempty(samples)
    error("reqml:NoUsableCampaignSamples", ...
        "Campaign CSV contains no usable completed-valid samples.");
end

if isfinite(options.MaxSamples)
    samples = samples(1:min(height(samples), options.MaxSamples), :);
end

assert_unique(samples.run_id, ...
    "reqml:DuplicateCampaignRunId", "run_id");
assert_unique(samples.hash_sha256, ...
    "reqml:DuplicateCampaignRunHash", "hash_sha256");
assert_unique(samples.wavefield_sample_path, ...
    "reqml:DuplicateCampaignSamplePath", "wavefield_sample_path");

exists_flag = false(height(samples), 1);
for index = 1:height(samples)
    exists_flag(index) = isfile(samples.wavefield_sample_path(index));
end
samples.wavefield_sample_exists = exists_flag;

if options.RequireAllPaths && ~all(exists_flag)
    first_missing = find(~exists_flag, 1, "first");
    error("reqml:CampaignSampleFileMissing", ...
        "Wavefield sample file does not exist: %s", ...
        samples.wavefield_sample_path(first_missing));
end

inventory = struct();
inventory.schema_name = "reqml_campaign_sample_inventory";
inventory.schema_version = "1.0";
inventory.campaign_runs_csv = campaign_runs_csv;
inventory.sample_count = height(samples);
inventory.rejected_count = height(rejected);
inventory.samples = samples;
inventory.rejected = rejected;

inventory.summary = struct();
inventory.summary.backends = unique(samples.backend);
inventory.summary.scenarios = unique(samples.scenario);
inventory.summary.frequencies_hz = unique(double(samples.frequency_hz));
inventory.summary.background_cs_m_s = ...
    unique(double(samples.background_cs_m_s));
inventory.summary.direction_counts = ...
    unique(double(samples.direction_count));
inventory.summary.seeds = unique(double(samples.seed));
inventory.summary.all_sample_files_exist = all(exists_flag);

end

function require_columns(table_value, required_columns)

actual = string(table_value.Properties.VariableNames);
missing = setdiff(required_columns, actual);

if ~isempty(missing)
    error("reqml:InvalidCampaignRunsCsv", ...
        "Campaign CSV is missing required column '%s'.", missing(1));
end

end

function table_value = normalize_text_columns(table_value)

text_columns = [
    "run_id"
    "backend"
    "hash_sha256"
    "status"
    "outcome_status"
    "scenario"
    "run_directory"
    "resolved_config_path"
    "wavefield_sample_path"
    "summary_path"
    "validation_report_path"
    ];

for name = text_columns.'
    table_value.(name) = string(table_value.(name));
end

end

function assert_unique(values, error_id, value_name)

if numel(unique(values)) ~= numel(values)
    error(error_id, ...
        "Campaign inventory contains duplicate %s values.", value_name);
end

end

function validate_max_samples(value)

if ~(isinf(value) || ...
        (isscalar(value) && isfinite(value) && ...
         value >= 1 && value == fix(value)))
    error("reqml:InvalidCampaignSampleLimit", ...
        "MaxSamples must be a positive integer or Inf.");
end

end
