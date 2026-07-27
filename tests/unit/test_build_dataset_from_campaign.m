function tests = test_build_dataset_from_campaign
%TEST_BUILD_DATASET_FROM_CAMPAIGN Test multi-sample dataset assembly.

tests = functiontests(localfunctions);

end

function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end

function testBuildsCombinedTraceableDataset(testCase)

fixture = create_campaign_fixture();
cleanup = onCleanup(@() cleanup_fixture(fixture));

feat_cfg = struct("win_size", 3, "M", 2);

dataset = reqml.datasets.build_dataset_from_campaign( ...
    fixture.csv_file, ...
    feat_cfg, ...
    DatasetId="combined_test_v1", ...
    MaxSamples=2, ...
    SaveOutputs=false, ...
    Loader=@fake_loader, ...
    ReadinessEvaluator=@fake_readiness, ...
    Extractor=@fake_extractor);

verifyEqual(testCase, ...
    dataset.schema_name, ...
    "reqml_campaign_dataset");

verifyEqual(testCase, dataset.sample_count, 2);
verifyEqual(testCase, dataset.example_count, 4);
verifyEqual(testCase, height(dataset.sample_summaries), 2);

verifyEqual(testCase, ...
    dataset.examples.campaign_run_id, ...
    ["run_000001"; "run_000001"; ...
     "run_000002"; "run_000002"]);

verifyEqual(testCase, ...
    dataset.examples.campaign_direction_count, ...
    [1; 1; 8; 8]);

verifyEqual(testCase, ...
    numel(unique(dataset.examples.example_id)), ...
    4);

verifyTrue(testCase, ...
    all(dataset.examples.target_valid));

verifyEqual(testCase, ...
    dataset.manifest.target_column, ...
    "q_target_from_center_truth");

clear cleanup

end

function testSavesDatasetArtifacts(testCase)

fixture = create_campaign_fixture();
cleanup_fixture_guard = ...
    onCleanup(@() cleanup_fixture(fixture));

output_directory = string(tempname);
cleanup_output = onCleanup(@() ...
    cleanup_directory(output_directory));

feat_cfg = struct("win_size", 3, "M", 2);

dataset = reqml.datasets.build_dataset_from_campaign( ...
    fixture.csv_file, ...
    feat_cfg, ...
    DatasetId="saved_test_v1", ...
    MaxSamples=1, ...
    OutputDirectory=output_directory, ...
    SaveOutputs=true, ...
    Loader=@fake_loader, ...
    ReadinessEvaluator=@fake_readiness, ...
    Extractor=@fake_extractor);

verifyTrue(testCase, isfile(dataset.paths.examples));
verifyTrue(testCase, isfile(dataset.paths.samples));
verifyTrue(testCase, ...
    isfile(dataset.paths.sample_summaries));
verifyTrue(testCase, isfile(dataset.paths.manifest));

loaded = load(dataset.paths.examples, "examples");

verifyEqual(testCase, ...
    height(loaded.examples), ...
    dataset.example_count);

clear cleanup_output
clear cleanup_fixture_guard

end

function data = fake_loader(sample_file)

data = struct();
data.sample_file = string(sample_file);
data.wavefield_zx = complex(ones(7, 7), 0.1);
data.dx_m = 0.5e-3;
data.dz_m = 0.5e-3;
data.frequency_hz = 500;

data.truth = struct();
data.truth.cs_m_s_zx = 2 * ones(7, 7);
data.truth.material_id_zx = ones(7, 7, "uint16");
data.truth.valid_mask_zx = true(7, 7);

end

function report = fake_readiness(~, varargin) %#ok<INUSD>

report = struct();
report.valid = true;
report.summary = "ready";
report.window_points_x = 3;
report.window_points_z = 3;
report.placements_x = 5;
report.placements_z = 5;

end

function extraction = fake_extractor( ...
    data, ~, options)

arguments
    data (1,1) struct
    ~
    options.DatasetId (1,1) string
    options.SampleId (1,1) string
    options.StepX (1,1) double = NaN
    options.StepZ (1,1) double = NaN
    options.StoreReqCurves (1,1) logical = false
    options.UseWindowParfor (1,1) logical = false
end

examples = table();
examples.dataset_id = ...
    repmat(options.DatasetId, 2, 1);
examples.sample_id = ...
    repmat(options.SampleId, 2, 1);
examples.example_id = [
    options.SampleId + "__z00003_x00003"
    options.SampleId + "__z00003_x00005"
    ];
examples.cx = [3; 5];
examples.cz = [3; 3];
examples.q_target_from_center_truth = [0.7; 0.8];
examples.target_valid = [true; true];
examples.target_definition = ...
    repmat("center_pixel_truth", 2, 1);
examples.mock_feature = [1.1; 1.2];

extraction = struct();
extraction.examples = examples;

extraction.sample_summary = struct();
extraction.sample_summary.example_count = 2;
extraction.sample_summary.valid_example_count = 2;
extraction.sample_summary.minimum_material_purity = 1;
extraction.sample_summary.median_material_purity = 1;

end

function fixture = create_campaign_fixture()

fixture.root = string(tempname);
mkdir(fixture.root);

sample_files = strings(2, 1);

for index = 1:2
    sample_files(index) = fullfile( ...
        fixture.root, ...
        sprintf("sample_%d.mat", index));

    placeholder = index; %#ok<NASGU>
    save(sample_files(index), "placeholder");
end

ordinal = [1; 2];
run_id = ["run_000001"; "run_000002"];
backend = ["swsynth"; "swsynth"];
hash_sha256 = ["hash_1"; "hash_2"];
status = ["completed"; "skipped_completed"];
outcome_status = ["completed_valid"; "completed_valid"];
scenario = ["scenario"; "scenario"];
seed = [3101; 3102];
frequency_hz = [300; 400];
background_cs_m_s = [2; 2.5];
direction_count = [1; 8];
valid = [1; 1];
run_directory = repmat(fixture.root, 2, 1);
resolved_config_path = repmat("", 2, 1);
wavefield_sample_path = sample_files;
summary_path = repmat("", 2, 1);
validation_report_path = repmat("", 2, 1);

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

fixture.csv_file = fullfile( ...
    fixture.root, ...
    "campaign_runs.csv");

writetable(runs, fixture.csv_file, Delimiter=",");

end

function cleanup_fixture(fixture)

if isfolder(fixture.root)
    rmdir(fixture.root, "s");
end

end

function cleanup_directory(directory)

if isfolder(directory)
    rmdir(directory, "s");
end

end
