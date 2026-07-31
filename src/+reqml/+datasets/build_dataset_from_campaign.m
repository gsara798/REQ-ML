function dataset = build_dataset_from_campaign( ...
    campaign_runs_csv, feat_cfg, options)
%BUILD_DATASET_FROM_CAMPAIGN Build one traceable REQ-ML dataset.
%
% Each accepted campaign run contributes one wavefield sample. Each sample is
% converted into local patch examples using extract_examples_from_sample.
%
% The supervised target is:
%
%   q_target_from_center_truth =
%       Ecum_patch(2*pi*f / cs_true(center pixel))

arguments
    campaign_runs_csv {mustBeTextScalar}
    feat_cfg (1,1) struct

    options.DatasetId (1,1) string = "dataset"
    options.MaxSamples (1,1) double = Inf
    options.RequireBackend (1,1) string = ""
    options.CsGuessMPerS (1,1) double = 3.0
    options.WindowWavelengths (1,1) double = 2.0
    options.MinimumPlacementsPerAxis (1,1) double = 5
    options.StepX (1,1) double = NaN
    options.StepZ (1,1) double = NaN
    options.StoreReqCurves (1,1) logical = false
    options.UseWindowParfor (1,1) logical = false
    options.OutputDirectory (1,1) string = ""
    options.SaveOutputs (1,1) logical = true
    options.TheoryClassMapping (:,1) struct = struct.empty

    options.Loader (1,1) function_handle = ...
        @reqml.io.load_wavefield_sample

    options.ReadinessEvaluator (1,1) function_handle = ...
        @reqml.readiness.assess_req_readiness

    options.Extractor (1,1) function_handle = ...
        @reqml.datasets.extract_examples_from_sample
end

inventory = reqml.datasets.load_campaign_samples( ...
    campaign_runs_csv, ...
    MaxSamples=options.MaxSamples, ...
    RequireBackend=options.RequireBackend);

sample_count = inventory.sample_count;

example_tables = cell(sample_count, 1);
summary_records = repmat( ...
    empty_summary_record(), ...
    sample_count, ...
    1);

for sample_index = 1:sample_count
    run = inventory.samples(sample_index, :);

    data = options.Loader( ...
        run.wavefield_sample_path);

    readiness = options.ReadinessEvaluator( ...
        data, ...
        CsGuessMPerS=options.CsGuessMPerS, ...
        WindowWavelengths=options.WindowWavelengths, ...
        MinimumPlacementsPerAxis= ...
            options.MinimumPlacementsPerAxis);

    if ~readiness.valid
        error("reqml:CampaignSampleNotReqReady", ...
            "Campaign run '%s' is not REQ-ready: %s", ...
            run.run_id, ...
            readiness.summary);
    end

    extraction = options.Extractor( ...
        data, ...
        feat_cfg, ...
        DatasetId=options.DatasetId, ...
        SampleId=run.run_id, ...
        StepX=options.StepX, ...
        StepZ=options.StepZ, ...
        StoreReqCurves=options.StoreReqCurves, ...
        UseWindowParfor=options.UseWindowParfor);

    examples = attach_campaign_metadata( ...
        extraction.examples, ...
        run);

    if ~isempty(options.TheoryClassMapping)
        examples = ...
            reqml.datasets.attach_theory_baseline( ...
                examples, ...
                run, ...
                feat_cfg, ...
                options.TheoryClassMapping);
    end

    example_tables{sample_index} = examples;

    summary_records(sample_index) = ...
        make_summary_record( ...
            run, ...
            readiness, ...
            extraction.sample_summary);
end

examples = vertcat(example_tables{:});
sample_summaries = struct2table(summary_records);

if numel(unique(examples.example_id)) ~= height(examples)
    error("reqml:DuplicateCampaignExampleId", ...
        "Combined campaign dataset contains duplicate example IDs.");
end

if ~all(examples.target_valid)
    error("reqml:InvalidCenterTruthTargets", ...
        "Combined campaign dataset contains invalid center-truth targets.");
end

dataset = struct();
dataset.schema_name = "reqml_campaign_dataset";
dataset.schema_version = "1.0";
dataset.dataset_id = options.DatasetId;
dataset.campaign_runs_csv = string(campaign_runs_csv);
dataset.sample_count = sample_count;
dataset.example_count = height(examples);
dataset.inventory = inventory;
dataset.sample_summaries = sample_summaries;
dataset.examples = examples;
dataset.feature_config = feat_cfg;
dataset.build_config = make_build_config(options);

dataset.summary = ...
    reqml.datasets.summarize_dataset(dataset);

dataset.manifest = make_manifest(dataset);

if options.SaveOutputs
    output_directory = resolve_output_directory( ...
        options.OutputDirectory, ...
        options.DatasetId);

    dataset.paths = save_dataset_outputs( ...
        dataset, ...
        output_directory);
else
    dataset.paths = struct();
end

end

function examples = attach_campaign_metadata(examples, run)
%ATTACH_CAMPAIGN_METADATA Propagate scientific run metadata to every patch.

n = height(examples);

source_names = [
    "ordinal"
    "design_id"
    "run_id"
    "hash_sha256"
    "backend"
    "scenario"
    "seed"
    "frequency_hz"
    "background_cs_m_s"
    "medium_object_count"
    "primary_object_type"
    "primary_object_cs_m_s"
    "primary_object_radius_m"
    "primary_object_center_x_m"
    "primary_object_center_z_m"
    "primary_object_normal_angle_rad"
    "primary_object_offset_m"
    "geometry_family"
    "direction_count"
    "retained_direction_count"
    "direction_support_type"
    "solid_angle_sr"
    "requested_in_plane_count"
    "retained_in_plane_count"
    "retained_in_plane_fraction"
    "angular_entropy"
    "angular_effective_bins"
    "radial_entropy"
    "radial_effective_bins"
    "propagation_model"
    "wavefield_sample_path"
    ];

target_names = [
    "campaign_ordinal"
    "campaign_design_id"
    "campaign_run_id"
    "campaign_hash_sha256"
    "campaign_backend"
    "campaign_scenario"
    "campaign_seed"
    "campaign_frequency_hz"
    "campaign_background_cs_m_s"
    "campaign_medium_object_count"
    "campaign_primary_object_type"
    "campaign_primary_object_cs_m_s"
    "campaign_primary_object_radius_m"
    "campaign_primary_object_center_x_m"
    "campaign_primary_object_center_z_m"
    "campaign_primary_object_normal_angle_rad"
    "campaign_primary_object_offset_m"
    "campaign_geometry_family"
    "campaign_direction_count"
    "campaign_retained_direction_count"
    "campaign_direction_support_type"
    "campaign_solid_angle_sr"
    "campaign_requested_in_plane_count"
    "campaign_retained_in_plane_count"
    "campaign_retained_in_plane_fraction"
    "campaign_angular_entropy"
    "campaign_angular_effective_bins"
    "campaign_radial_entropy"
    "campaign_radial_effective_bins"
    "campaign_propagation_model"
    "campaign_sample_file"
    ];

available = string(run.Properties.VariableNames);
attached_names = strings(0, 1);

for index = 1:numel(source_names)
    source_name = source_names(index);
    target_name = target_names(index);

    if ~ismember(source_name, available)
        continue
    end

    value = run.(source_name);

    if height(run) ~= 1
        error("reqml:InvalidCampaignMetadataRow", ...
            "Campaign metadata attachment requires exactly one run.");
    end

    examples.(target_name) = repeat_metadata_value( ...
        value, ...
        n, ...
        source_name);

    attached_names(end + 1, 1) = target_name; %#ok<AGROW>
end

if ~isempty(attached_names)
    examples = movevars( ...
        examples, ...
        attached_names, ...
        "After", ...
        "example_id");
end

end


function repeated = repeat_metadata_value(value, n, source_name)

if iscell(value)
    if numel(value) ~= 1
        error("reqml:InvalidCampaignMetadataValue", ...
            "Campaign metadata '%s' must be scalar.", ...
            source_name);
    end

    value = value{1};
end

if isstring(value) || ischar(value)
    repeated = repmat(string(value), n, 1);
    return
end

if iscategorical(value)
    repeated = repmat(string(value), n, 1);
    return
end

if isnumeric(value) || islogical(value)
    if ~isscalar(value)
        error("reqml:InvalidCampaignMetadataValue", ...
            "Campaign metadata '%s' must be scalar.", ...
            source_name);
    end

    repeated = repmat(value, n, 1);
    return
end

error("reqml:UnsupportedCampaignMetadataType", ...
    "Campaign metadata '%s' has an unsupported type.", ...
    source_name);

end


function record = make_summary_record( ...
        run, readiness, sample_summary)

record = empty_summary_record();

record.ordinal = double(run.ordinal);
record.run_id = string(run.run_id);
record.hash_sha256 = string(run.hash_sha256);
record.backend = string(run.backend);
record.scenario = string(run.scenario);
record.seed = double(run.seed);
record.frequency_hz = double(run.frequency_hz);
record.background_cs_m_s = ...
    double(run.background_cs_m_s);
record.direction_count = ...
    double(run.direction_count);
record.wavefield_sample_path = ...
    string(run.wavefield_sample_path);

record.req_ready = logical(readiness.valid);
record.req_window_points_x = ...
    double(readiness.window_points_x);
record.req_window_points_z = ...
    double(readiness.window_points_z);
record.req_placements_x = ...
    double(readiness.placements_x);
record.req_placements_z = ...
    double(readiness.placements_z);

record.example_count = ...
    double(sample_summary.example_count);
record.valid_example_count = ...
    double(sample_summary.valid_example_count);
record.minimum_material_purity = ...
    double(sample_summary.minimum_material_purity);
record.median_material_purity = ...
    double(sample_summary.median_material_purity);

end

function record = empty_summary_record()

record = struct();
record.ordinal = NaN;
record.run_id = "";
record.hash_sha256 = "";
record.backend = "";
record.scenario = "";
record.seed = NaN;
record.frequency_hz = NaN;
record.background_cs_m_s = NaN;
record.direction_count = NaN;
record.wavefield_sample_path = "";
record.req_ready = false;
record.req_window_points_x = NaN;
record.req_window_points_z = NaN;
record.req_placements_x = NaN;
record.req_placements_z = NaN;
record.example_count = NaN;
record.valid_example_count = NaN;
record.minimum_material_purity = NaN;
record.median_material_purity = NaN;

end

function config = make_build_config(options)

config = struct();
config.dataset_id = options.DatasetId;
config.max_samples = options.MaxSamples;
config.require_backend = options.RequireBackend;
config.cs_guess_m_s = options.CsGuessMPerS;
config.window_wavelengths = ...
    options.WindowWavelengths;
config.minimum_placements_per_axis = ...
    options.MinimumPlacementsPerAxis;
config.step_x = options.StepX;
config.step_z = options.StepZ;
config.store_req_curves = ...
    options.StoreReqCurves;
config.use_window_parfor = ...
    options.UseWindowParfor;
config.theory_class_mapping = ...
    options.TheoryClassMapping;
config.target_definition = ...
    "center_pixel_truth";

end

function manifest = make_manifest(dataset)

manifest = struct();
manifest.schema_name = ...
    "reqml_campaign_dataset_manifest";
manifest.schema_version = "1.0";
manifest.dataset_id = dataset.dataset_id;
manifest.campaign_runs_csv = ...
    dataset.campaign_runs_csv;
manifest.sample_count = dataset.sample_count;
manifest.example_count = dataset.example_count;
manifest.target_column = ...
    "q_target_from_center_truth";
manifest.target_definition = ...
    "center_pixel_truth";
manifest.feature_config = ...
    dataset.feature_config;
manifest.build_config = ...
    dataset.build_config;
manifest.created = string(datetime( ...
    "now", ...
    "Format", ...
    "yyyy-MM-dd HH:mm:ss Z"));

end

function output_directory = resolve_output_directory( ...
        requested_directory, dataset_id)

if strlength(requested_directory) > 0
    output_directory = requested_directory;
else
    root = fileparts(fileparts(fileparts( ...
        mfilename("fullpath"))));

    output_directory = fullfile( ...
        root, ...
        "outputs", ...
        "datasets", ...
        dataset_id);
end

output_directory = string(output_directory);

if isfolder(output_directory)
    error("reqml:DatasetOutputExists", ...
        "Dataset output directory already exists: %s", ...
        output_directory);
end

[created, message] = mkdir(output_directory);

if ~created
    error("reqml:DatasetOutputCreateFailed", ...
        "Could not create dataset output directory '%s': %s", ...
        output_directory, ...
        message);
end

end

function paths = save_dataset_outputs( ...
        dataset, output_directory)

examples = dataset.examples; %#ok<NASGU>
sample_summaries = dataset.sample_summaries;

examples_path = fullfile( ...
    output_directory, ...
    "examples.mat");

sample_summaries_path = fullfile( ...
    output_directory, ...
    "sample_summaries.csv");

samples_path = fullfile( ...
    output_directory, ...
    "samples.csv");

variable_registry_path = fullfile( ...
    output_directory, ...
    "variable_registry.csv");

dataset_summary_path = fullfile( ...
    output_directory, ...
    "dataset_summary.json");

manifest_path = fullfile( ...
    output_directory, ...
    "dataset_manifest.json");

save(examples_path, "examples", "-v7.3");

writetable( ...
    sample_summaries, ...
    sample_summaries_path, ...
    Delimiter=",");

writetable( ...
    dataset.inventory.samples, ...
    samples_path, ...
    Delimiter=",");

writetable( ...
    dataset.summary.variable_registry, ...
    variable_registry_path, ...
    Delimiter=",");

summary_for_json = ...
    make_summary_json_serializable( ...
        dataset.summary);

write_json( ...
    dataset_summary_path, ...
    summary_for_json);

write_json(manifest_path, dataset.manifest);

paths = struct();
paths.output_directory = output_directory;
paths.examples = string(examples_path);
paths.sample_summaries = ...
    string(sample_summaries_path);
paths.samples = string(samples_path);
paths.variable_registry = ...
    string(variable_registry_path);
paths.dataset_summary = ...
    string(dataset_summary_path);
paths.manifest = string(manifest_path);

end

function value = make_summary_json_serializable(summary)

value = summary;

table_fields = [
    "variable_registry"
    "role_counts"
    "source_counts"
    "feature_group_counts"
    "examples_per_run"
    "by_background_cs"
    "by_frequency"
    "by_direction_count"
    ];

for field_index = 1:numel(table_fields)
    field_name = table_fields(field_index);

    if isfield(value, field_name) && ...
            istable(value.(field_name))
        value.(field_name) = ...
            table2struct( ...
                value.(field_name));
    end
end

end

function write_json(path_value, value)

file_id = fopen(path_value, "w");

if file_id < 0
    error("reqml:DatasetManifestWriteFailed", ...
        "Could not create dataset manifest: %s", ...
        path_value);
end

cleanup = onCleanup(@() fclose(file_id));

fprintf(file_id, "%s", ...
    jsonencode(value, PrettyPrint=true));

clear cleanup

end
