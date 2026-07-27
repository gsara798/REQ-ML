function tests = test_extract_examples_from_sample
%TEST_EXTRACT_EXAMPLES_FROM_SAMPLE Test dataset-layer orchestration.

tests = functiontests(localfunctions);

end

function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end

function testBuildsTraceableExamplesWithTruth(testCase)

data = make_loaded_sample();
feat_cfg = struct("win_size", 3, "M", 2);

dataset = reqml.datasets.extract_examples_from_sample( ...
    data, ...
    feat_cfg, ...
    DatasetId="heterogeneous_v1", ...
    SampleId="sample_0001", ...
    Estimator=@fake_estimator);

verifyEqual(testCase, dataset.schema_name, ...
    "reqml_dataset_examples");
verifyEqual(testCase, dataset.schema_version, "1.0");
verifyEqual(testCase, dataset.dataset_id, "heterogeneous_v1");
verifyEqual(testCase, dataset.sample_id, "sample_0001");
verifyEqual(testCase, height(dataset.examples), 2);

verifyEqual(testCase, ...
    dataset.examples.example_id, ...
    ["sample_0001__z00003_x00003"; ...
     "sample_0001__z00003_x00006"]);

verifyEqual(testCase, ...
    dataset.examples.truth_cs_center_m_s, ...
    [2; 4]);

verifyEqual(testCase, ...
    dataset.examples.truth_material_id_center, ...
    [1; 2]);

verifyEqual(testCase, ...
    dataset.examples.truth_material_purity, ...
    [1; 1], ...
    AbsTol=1e-12);

verifyEqual(testCase, ...
    dataset.sample_summary.example_count, ...
    2);

end

function testDetectsMixedMaterialWindow(testCase)

data = make_loaded_sample();
feat_cfg = struct("win_size", 3, "M", 2);

dataset = reqml.datasets.extract_examples_from_sample( ...
    data, ...
    feat_cfg, ...
    SampleId="sample_mixed", ...
    Estimator=@fake_mixed_estimator);

verifyLessThan(testCase, ...
    dataset.examples.truth_material_purity(1), ...
    1);

verifyGreaterThan(testCase, ...
    dataset.examples.truth_cs_std_m_s(1), ...
    0);

end

function data = make_loaded_sample()

Nz = 7;
Nx = 7;

cs = 2 * ones(Nz, Nx);
cs(:, 5:end) = 4;

material = ones(Nz, Nx, "uint16");
material(:, 5:end) = 2;

data = struct();
data.wavefield_zx = complex(ones(Nz, Nx), 0.25);
data.dx_m = 0.5e-3;
data.dz_m = 0.5e-3;
data.frequency_hz = 500;

data.generator = struct();
data.generator.backend = "swsynth";

data.truth = struct();
data.truth.cs_m_s_zx = cs;
data.truth.material_id_zx = material;
data.truth.valid_mask_zx = true(Nz, Nx);

end

function out = fake_estimator(~, ~, ~, varargin) %#ok<INUSD>

rows = table();
rows.cx = [3; 6];
rows.cz = [3; 3];
rows.q_local_req = [0.70; 0.80];
rows.mock_feature = [1.2; 1.4];

out = struct();
out.feature_table = rows;
out.half_win = 1;
out.win_size = 3;

end

function out = fake_mixed_estimator(~, ~, ~, varargin) %#ok<INUSD>

rows = table();
rows.cx = 4;
rows.cz = 3;
rows.q_local_req = 0.75;

out = struct();
out.feature_table = rows;
out.half_win = 1;
out.win_size = 3;

end
