function tests = test_public_prediction_api
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(fullfile(root, "src"));
testCase.TestData.root = root;
end

function testM2MatchesValidatedDeploymentPath(testCase)
verify_equivalence(testCase, 2);
end

function testM3MatchesValidatedDeploymentPath(testCase)
verify_equivalence(testCase, 3);
end

function testResultContract(testCase)
[sample_file, model_file] = fixture_files(testCase);
result = reqml.predictSWS(sample_file, Model=model_file, M=2, StepPixels=12);
verifyTrue(testCase, all(isfield(result, ...
    ["cs_map" "q_map" "valid_mask" "x_mm" "z_mm" "metadata"])));
verifyEqual(testCase, result.metadata.M, 2);
verifyEqual(testCase, result.metadata.cs_guess_m_s, 3);
verifyEqual(testCase, result.metadata.frequency_hz, 400);
verifyEqual(testCase, result.metadata.model_identifier, "test_q0_model");
verifySize(testCase, result.valid_mask, size(result.cs_map));
verifySize(testCase, result.q_map, size(result.cs_map));
end

function verify_equivalence(testCase, M)
[sample_file, model_file] = fixture_files(testCase);
result = reqml.predictSWS(sample_file, Model=model_file, M=M, StepPixels=12);

data = reqml.io.load_wavefield_sample(sample_file);
cfg = reqml.config.default_feature_config("M", M, "cs_guess", 3);
dataset = reqml.datasets.extract_examples_from_sample(data, cfg, ...
    DatasetId="manual", SampleId="manual", StepX=12, StepZ=12, ...
    StoreReqCurves=false, UseWindowParfor=false);
examples = dataset.examples;
examples.campaign_frequency_hz = repmat(data.frequency_hz, height(examples), 1);
bundle = load(model_file, "model", "predictor_names");
X = reqml.training.build_numeric_predictor_matrix( ...
    examples, string(bundle.predictor_names(:)));
q_expected = reqml.training.predict_regression_model( ...
    bundle.model, X, ClipRange=[0.001 0.999]);
sws_expected = reqml.evaluation.convert_q_predictions_to_sws( ...
    examples, q_expected);

verifyEqual(testCase, result.patch_predictions.q_pred, q_expected, AbsTol=1e-12);
verifyEqual(testCase, result.patch_predictions.cs_pred_m_s, ...
    sws_expected.cs_pred_m_s, AbsTol=1e-12);
verifyTrue(testCase, all(result.valid_mask, "all"));
end

function [sample_file, model_file] = fixture_files(testCase)
folder = string(testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
sample_file = fullfile(folder, "wavefield_sample.mat");
model_file = fullfile(folder, "model_bundle.mat");

dx = 0.0005; x = (0:80)*dx; z = x; [X, Z] = meshgrid(x, z);
frequency = 400; cs = 2;
wave = sin(2*pi*frequency/cs*(0.8*X+0.6*Z)) + ...
    0.35*cos(2*pi*frequency/cs*(-0.4*X+0.9*Z)+0.2);
wavefield_sample = struct(); %#ok<NASGU>
wavefield_sample.schema_name = "wavefield_sample";
wavefield_sample.schema_version = "1.0";
wavefield_sample.generator = struct("name", "unit_test");
wavefield_sample.coordinates = struct("x_m", x, "z_m", z, ...
    "dx_m", dx, "dz_m", dx, "array_order", "zx");
wavefield_sample.wavefield = struct("data_zx", wave, ...
    "frequency_hz", frequency, "component", "axial", ...
    "quantity", "displacement", "units", "a.u.");
wavefield_sample.truth = struct("cs_map_zx", cs*ones(size(wave)), ...
    "k_map_zx", 2*pi*frequency/cs*ones(size(wave)), ...
    "material_id_zx", ones(size(wave), "uint16"), ...
    "valid_mask_zx", true(size(wave)));
wavefield_sample.validation = struct("valid", true, "analysis_ready", true);
wavefield_sample.provenance = struct("sample_id", "unit_test_sample");
save(sample_file, "wavefield_sample");

predictor_names = ["REQ_M"; "REQ_cs_guess_m_s"; "GRID_dx_m"; ...
    "GRID_dz_m"; "REQ_dkx_rad_m"; "REQ_dkz_rad_m"; ...
    "REQ_Nbins_effective"; "campaign_frequency_hz"]; %#ok<NASGU>
model = struct("model_type", "ridge", "mu", zeros(1, 8), ...
    "sigma", ones(1, 8), "coefficients", [0.5; zeros(8, 1)]); %#ok<NASGU>
model_metadata = struct("model_id", "test_q0_model"); %#ok<NASGU>
save(model_file, "model", "model_metadata", "predictor_names");
end
