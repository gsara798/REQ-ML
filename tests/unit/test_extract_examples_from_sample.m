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

function testExplicitCentersFlowThroughTruthAndTarget(testCase)

data = make_loaded_sample();
feat_cfg = struct("win_size", 3, "M", 2);

centers = [
    3, 3
    4, 3
    6, 3
];

dataset = reqml.datasets.extract_examples_from_sample( ...
    data, ...
    feat_cfg, ...
    DatasetId="explicit_centers_v1", ...
    SampleId="sample_explicit", ...
    CenterIndices=centers, ...
    Estimator=@fake_explicit_center_estimator);

examples = dataset.examples;

verifyEqual(testCase, height(examples), size(centers, 1));
verifyEqual(testCase, examples.cx, centers(:, 1));
verifyEqual(testCase, examples.cz, centers(:, 2));

verifyEqual(testCase, ...
    examples.truth_cs_center_m_s, ...
    [2; 2; 4]);

verifyEqual(testCase, ...
    examples.truth_material_id_center, ...
    [1; 1; 2]);

verifyEqual(testCase, ...
    examples.truth_material_purity, ...
    [1; 2/3; 1], ...
    AbsTol=1e-12);

expected_k = ...
    2*pi*data.frequency_hz ./ ...
    examples.truth_cs_center_m_s;

expected_q = expected_k / 2000;

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
    examples.example_id, ...
    [
        "sample_explicit__z00003_x00003"
        "sample_explicit__z00003_x00004"
        "sample_explicit__z00003_x00006"
    ]);

end


function out = fake_explicit_center_estimator( ...
    ~, ~, ~, varargin)

center_indices = [];

for index = 1:2:numel(varargin)
    if string(varargin{index}) == "CenterIndices"
        center_indices = double(varargin{index + 1});
        break
    end
end

if isempty(center_indices)
    error("reqml:MissingTestCenterIndices", ...
        "The explicit centers were not forwarded to the estimator.");
end

n = size(center_indices, 1);

rows = table();
rows.cx = center_indices(:, 1);
rows.cz = center_indices(:, 2);
rows.q_local_req = 0.5 * ones(n, 1);
rows.req_mapping = repmat({fake_mapping()}, n, 1);

out = struct();
out.feature_table = rows;
out.half_win = 1;
out.win_size = 3;
out.center_indices = center_indices;

end


function testSelectsCentersForMultipleRequestedCells(testCase)

data = make_loaded_sample();
feat_cfg = struct("win_size", 3, "M", 2);

requested = table( ...
    [1; 1; 2], ...
    [1; 1; 1], ...
    [1; 2; 2], ...
    [1; 1; 1], ...
    [2; 2; 2], ...
    VariableNames=[ ...
        "sws_bin", ...
        "frequency_bin", ...
        "purity_bin", ...
        "diffusivity_bin", ...
        "needed_example_count"]);

dataset = reqml.datasets.extract_examples_from_sample( ...
    data, ...
    feat_cfg, ...
    SampleId="automatic_centers", ...
    RequestedCoverageCells=requested, ...
    PurityEdges=[0.5 0.8 1.0001], ...
    DiffusivityEdges=[0 1], ...
    SwsEdges=[1.5 3.0 4.5], ...
    FrequencyEdges=[400 600], ...
    DiffusivityValue=0.5, ...
    CandidateStepPixels=1, ...
    MaximumCentersPerCell=2, ...
    MinimumCenterDistancePixels=0, ...
    CenterSelectionSeed=19, ...
    Estimator=@fake_explicit_center_estimator);

verifyGreaterThan(testCase, ...
    height(dataset.center_selection), ...
    0);

verifyEqual(testCase, ...
    dataset.examples.cx, ...
    dataset.center_selection.cx);

verifyEqual(testCase, ...
    dataset.examples.cz, ...
    dataset.center_selection.cz);

verifyEqual(testCase, ...
    dataset.examples.truth_cs_center_m_s, ...
    dataset.center_selection.truth_cs_center_m_s);

verifyEqual(testCase, ...
    dataset.examples.truth_material_purity, ...
    dataset.center_selection.truth_material_purity, ...
    AbsTol=1e-12);

verifyTrue(testCase, all(ismember( ...
    dataset.center_selection.selection_target_cell_key, ...
    requested_cell_keys(requested))));

end


function keys = requested_cell_keys(requested)

keys = compose( ...
    "s%02d_f%02d_p%02d_d%02d", ...
    requested.sws_bin, ...
    requested.frequency_bin, ...
    requested.purity_bin, ...
    requested.diffusivity_bin);

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
rows.req_mapping = {
    fake_mapping()
    fake_mapping()
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
rows.q_local_req = 0.75;
rows.req_mapping = {fake_mapping()};

out = struct();
out.feature_table = rows;
out.half_win = 1;
out.win_size = 3;

end

function mapping = fake_mapping()

mapping = struct();
mapping.k_cent = [0; 2000];
mapping.Ecum = [0; 1];

end

