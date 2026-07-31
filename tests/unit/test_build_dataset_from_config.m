function tests = test_build_dataset_from_config
%TEST_BUILD_DATASET_FROM_CONFIG Test config-driven dataset construction.

tests = functiontests(localfunctions);

end

function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end

function testBuildsDatasetFromConfig(testCase)

fixture = create_fixture();
cleanup = onCleanup(@() cleanup_fixture(fixture));

dataset = reqml.datasets.build_dataset_from_config( ...
    fixture.config_file);

verifyEqual(testCase, ...
    dataset.schema_name, ...
    "reqml_campaign_dataset");

verifyEqual(testCase, ...
    dataset.dataset_id, ...
    "config_driven_test_v1");

verifyEqual(testCase, dataset.sample_count, 1);
verifyGreaterThan(testCase, dataset.example_count, 0);
verifyTrue(testCase, all(dataset.examples.target_valid));

verifyTrue(testCase, ...
    all(ismember( ...
        [ ...
        "theory_field_class"
        "q_theory_single_wave_discrete"
        "q_theory_diffuse3d_discrete"
        "q_theory_discrete"
        "q_theory_valid"
        ], ...
        string(dataset.examples.Properties.VariableNames))));

verifyEqual(testCase, ...
    unique(dataset.examples.theory_field_class), ...
    "SingleWave");

verifyTrue(testCase, ...
    all(dataset.examples.q_theory_valid));

verifyFalse(testCase, ...
    isfolder(fixture.output_directory));

verifyTrue(testCase, ...
    isempty(fieldnames(dataset.paths)));

end

function testRejectsMissingConfigFile(testCase)

missing_file = fullfile( ...
    tempdir, ...
    "missing_reqml_dataset_config.json");

verifyError(testCase, ...
    @() reqml.datasets.build_dataset_from_config( ...
        missing_file), ...
    "reqml:MissingDatasetBuildConfig");

end

function testRejectsMissingRequiredConfigField(testCase)

fixture = create_fixture();
cleanup = onCleanup(@() cleanup_fixture(fixture));

config = jsondecode(fileread(fixture.config_file));
config = rmfield(config, "req");

invalid_file = fullfile( ...
    fixture.root, ...
    "invalid_config.json");

write_json(invalid_file, config);

verifyError(testCase, ...
    @() reqml.datasets.build_dataset_from_config( ...
        invalid_file), ...
    "reqml:InvalidDatasetBuildConfig");

end

function fixture = create_fixture()

fixture.root = string(tempname);
mkdir(fixture.root);

repository_root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

dataset_id = "config_driven_test_v1";

fixture.output_directory = fullfile( ...
    repository_root, ...
    "outputs", ...
    "datasets", ...
    dataset_id);

if isfolder(fixture.output_directory)
    rmdir(fixture.output_directory, "s");
end

sample_file = fullfile( ...
    fixture.root, ...
    "wavefield_sample.mat");

wavefield_sample = make_wavefield_sample(); %#ok<NASGU>
save(sample_file, "wavefield_sample");

campaign_csv = fullfile( ...
    fixture.root, ...
    "campaign_runs.csv");

write_campaign_csv( ...
    campaign_csv, ...
    sample_file);

config = struct();
config.schema_name = ...
    "reqml_dataset_build_config";
config.schema_version = "1.0";
config.dataset_id = dataset_id;
config.campaign_runs_csv = campaign_csv;
config.require_backend = "swsynth";
config.max_samples = 1;

config.req = struct();
config.req.M = 2;
config.req.cs_guess_m_s = 3.0;
config.req.gamma = 1.0;
config.req.pad_factor = 1;
config.req.smooth_sigma_2d = 1.0;

config.extraction = struct();
config.extraction.minimum_placements_per_axis = 1;
config.extraction.step_x = 8;
config.extraction.step_z = 8;
config.extraction.store_req_curves = false;
config.extraction.use_window_parfor = false;

config.execution = struct();
config.execution.start_parallel_pool = false;
config.execution.save_outputs = false;

config.theory_class_mapping = struct( ...
    "direction_count", ...
    {1}, ...
    "field_class", ...
    {"SingleWave"});

fixture.config_file = fullfile( ...
    fixture.root, ...
    "dataset_config.json");

write_json(fixture.config_file, config);

end

function sample = make_wavefield_sample()

Nz = 41;
Nx = 41;

dx = 0.5e-3;
dz = 0.5e-3;
frequency_hz = 500;
cs_m_s = 3.0;

x_m = (0:(Nx - 1)) * dx;
z_m = (0:(Nz - 1)) * dz;

k = 2*pi*frequency_hz / cs_m_s;

wavefield = exp(1i * k * x_m);
wavefield = repmat(wavefield, Nz, 1);

sample = struct();

sample.schema_name = "wavefield_sample";
sample.schema_version = "1.0";

sample.generator = struct();
sample.generator.name = "swsynth";
sample.generator.backend = "swsynth";

sample.coordinates = struct();
sample.coordinates.x_m = x_m;
sample.coordinates.z_m = z_m;
sample.coordinates.dx_m = dx;
sample.coordinates.dz_m = dz;
sample.coordinates.array_order = "zx";

sample.wavefield = struct();
sample.wavefield.data_zx = wavefield;
sample.wavefield.frequency_hz = frequency_hz;
sample.wavefield.component = "axial";
sample.wavefield.quantity = "displacement";
sample.wavefield.units = "arbitrary_displacement";

sample.truth = struct();
sample.truth.cs_map_zx = ...
    cs_m_s * ones(Nz, Nx);
sample.truth.k_map_zx = ...
    (2*pi*frequency_hz/cs_m_s) * ones(Nz, Nx);
sample.truth.material_id_zx = ...
    ones(Nz, Nx, "uint16");
sample.truth.valid_mask_zx = ...
    true(Nz, Nx);

sample.propagation = struct();
sample.propagation.model = "plane_wave";
sample.propagation.source_dimension = 3;
sample.propagation.direction_space = ...
    "three_dimensional";
sample.propagation.direction_count = 1;
sample.propagation.direction_sampling_method = ...
    "fibonacci";
sample.propagation.angular_support = struct( ...
    "type", "full_sphere");
sample.propagation.require_in_plane = true;

sample.sources = struct.empty;

sample.validation = struct();
sample.validation.valid = true;
sample.validation.analysis_ready = true;

sample.provenance = struct();
sample.provenance.run_id = "fixture_run";
sample.provenance.campaign_id = ...
    "fixture_campaign";
sample.provenance.source_path = "";
sample.provenance.created_utc = "";

end

function write_campaign_csv(csv_file, sample_file)

ordinal = 1;
run_id = "run_000001";
backend = "swsynth";
hash_sha256 = "fixture_hash";
status = "completed";
outcome_status = "completed_valid";
scenario = "config_driven_fixture";
seed = 3101;
frequency_hz = 500;
background_cs_m_s = 3.0;
direction_count = 1;
valid = 1;
run_directory = fileparts(sample_file);
resolved_config_path = "";
wavefield_sample_path = string(sample_file);
summary_path = "";
validation_report_path = "";

runs = table( ...
    ordinal, ...
    run_id, ...
    backend, ...
    hash_sha256, ...
    status, ...
    outcome_status, ...
    scenario, ...
    seed, ...
    frequency_hz, ...
    background_cs_m_s, ...
    direction_count, ...
    valid, ...
    run_directory, ...
    resolved_config_path, ...
    wavefield_sample_path, ...
    summary_path, ...
    validation_report_path);

writetable(runs, csv_file, Delimiter=",");

end

function write_json(file_path, value)

text = jsonencode(value, PrettyPrint=true);

file_id = fopen(file_path, "w");

if file_id < 0
    error("reqml:TestFixtureWriteFailed", ...
        "Could not create JSON fixture: %s", ...
        file_path);
end

cleanup = onCleanup(@() fclose(file_id));

fprintf(file_id, "%s\n", text);

clear cleanup

end

function cleanup_fixture(fixture)

if isfolder(fixture.output_directory)
    rmdir(fixture.output_directory, "s");
end

if isfolder(fixture.root)
    rmdir(fixture.root, "s");
end

end
