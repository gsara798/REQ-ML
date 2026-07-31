function tests = test_center_truth_quantile_target
%TEST_CENTER_TRUTH_QUANTILE_TARGET Test local center-pixel q targets.

tests = functiontests(localfunctions);

end

function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end

function testEvaluatesQuantileAtTargetWavenumber(testCase)

mapping = struct();
mapping.k_cent = [0; 100; 200; 300];
mapping.Ecum = [0; 0.2; 0.7; 1.0];

q = reqml.quantile. ...
    evaluate_quantile_at_wavenumber( ...
        mapping, ...
        150);

verifyEqual(testCase, q, 0.45, AbsTol=1e-12);

end

function testUsesCenterPixelTruthForEachPatch(testCase)

data = make_loaded_sample();
feat_cfg = struct("win_size", 3, "M", 2);

dataset = reqml.datasets.extract_examples_from_sample( ...
    data, ...
    feat_cfg, ...
    SampleId="heterogeneous_center_target", ...
    Estimator=@fake_estimator);

examples = dataset.examples;

expected_cs = [2; 4];
expected_k = 2*pi*data.frequency_hz ./ expected_cs;
expected_q = expected_k / 2000;

verifyEqual(testCase, ...
    examples.target_cs_center_m_s, ...
    expected_cs);

verifyEqual(testCase, ...
    examples.target_k_center_rad_m, ...
    expected_k, ...
    AbsTol=1e-12);

verifyEqual(testCase, ...
    examples.q_target_from_center_truth, ...
    expected_q, ...
    AbsTol=1e-12);

verifyTrue(testCase, all(examples.target_valid));

verifyEqual(testCase, ...
    examples.target_definition, ...
    repmat("center_pixel_truth", 2, 1));

verifyNotEqual(testCase, ...
    examples.q_target_from_center_truth(1), ...
    examples.q_target_from_center_truth(2));

end

function testPurityDoesNotChangeTargetDefinition(testCase)

data = make_loaded_sample();
feat_cfg = struct("win_size", 3, "M", 2);

dataset = reqml.datasets.extract_examples_from_sample( ...
    data, ...
    feat_cfg, ...
    SampleId="mixed_center_target", ...
    Estimator=@fake_mixed_estimator);

example = dataset.examples(1, :);

verifyLessThan(testCase, ...
    example.truth_material_purity, ...
    1);

verifyEqual(testCase, ...
    example.target_cs_center_m_s, ...
    data.truth.cs_m_s_zx(3, 4));

verifyEqual(testCase, ...
    example.target_k_center_rad_m, ...
    2*pi*data.frequency_hz / ...
        data.truth.cs_m_s_zx(3, 4), ...
    AbsTol=1e-12);

verifyTrue(testCase, example.target_valid);

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
rows.q_local_req = [0.5; 0.5];

rows.req_mapping = {
    linear_mapping()
    linear_mapping()
    };

out = struct();
out.feature_table = rows;
out.half_win = 1;
out.win_size = 3;

end

function out = fake_mixed_estimator(~, ~, ~, varargin) %#ok<INUSD>

rows = table();
rows.cx = 4;
rows.cz = 3;
rows.q_local_req = 0.5;
rows.req_mapping = {linear_mapping()};

out = struct();
out.feature_table = rows;
out.half_win = 1;
out.win_size = 3;

end

function mapping = linear_mapping()

mapping = struct();
mapping.k_cent = [0; 2000];
mapping.Ecum = [0; 1];

end
