function tests = test_summarize_dataset
%TEST_SUMMARIZE_DATASET Test dataset auditing and feature detection.

tests = functiontests(localfunctions);

end

function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end

function testSummarizesDatasetAndDetectsFeatures(testCase)

examples = make_examples();

dataset = struct();
dataset.dataset_id = "summary_test_v1";
dataset.examples = examples;

summary = reqml.datasets.summarize_dataset(dataset);

verifyEqual(testCase, ...
    summary.schema_name, ...
    "reqml_dataset_summary");

verifyEqual(testCase, ...
    summary.schema_version, ...
    "1.1");

verifyEqual(testCase, summary.example_count, 4);
verifyEqual(testCase, summary.sample_count, 2);
verifyEqual(testCase, summary.run_count, 2);

verifyTrue(testCase, ...
    ismember("radial_entropy", ...
        summary.candidate_features));

verifyFalse(testCase, ...
    ismember("constant_feature", ...
        summary.candidate_features));

verifyFalse(testCase, ...
    ismember("truth_material_purity", ...
        summary.candidate_features));

verifyFalse(testCase, ...
    ismember("q_target_from_center_truth", ...
        summary.candidate_features));

verifyTrue(testCase, ...
    ismember("REQ_M", summary.candidate_features));

verifyTrue(testCase, ...
    ismember("REQ_cs_guess_m_s", ...
        summary.candidate_features));

verifyTrue(testCase, ...
    ismember("campaign_frequency_hz", ...
        summary.candidate_features));

verifyFalse(testCase, ...
    ismember("M", summary.candidate_features));

verifyFalse(testCase, ...
    ismember("SIM_f0", summary.candidate_features));

verifyFalse(testCase, ...
    ismember("SIM_cs_bg", summary.candidate_features));

verifyTrue(testCase, ...
    ismember("constant_feature", ...
        summary.constant_numeric_variables));

feature_row = summary.variable_registry( ...
    summary.variable_registry.variable_name == ...
        "radial_entropy", ...
    :);

verifyEqual(testCase, ...
    feature_row.role, ...
    "feature");

verifyTrue(testCase, ...
    feature_row.trainable);

truth_row = summary.variable_registry( ...
    summary.variable_registry.variable_name == ...
        "truth_material_purity", ...
    :);

verifyEqual(testCase, ...
    truth_row.role, ...
    "truth");

verifyFalse(testCase, ...
    truth_row.trainable);

verifyEqual(testCase, ...
    summary.target.valid_count, ...
    4);

verifyEqual(testCase, ...
    height(summary.examples_per_run), ...
    2);

verifyEqual(testCase, ...
    summary.examples_per_run.example_count, ...
    [2; 2]);

end

function testRejectsEmptyDataset(testCase)

verifyError(testCase, ...
    @() reqml.datasets.summarize_dataset(table()), ...
    "reqml:EmptyDataset");

end

function examples = make_examples()

examples = table();

examples.dataset_id = repmat("dataset", 4, 1);
examples.sample_id = [
    "sample_1"
    "sample_1"
    "sample_2"
    "sample_2"
    ];

examples.example_id = [
    "example_1"
    "example_2"
    "example_3"
    "example_4"
    ];

examples.campaign_run_id = [
    "run_1"
    "run_1"
    "run_2"
    "run_2"
    ];

examples.campaign_background_cs_m_s = ...
    [2; 2; 3; 3];

examples.campaign_frequency_hz = ...
    [300; 300; 500; 500];

examples.REQ_M = [2; 2; 3; 3];
examples.M = [2; 2; 3; 3];
examples.REQ_cs_guess_m_s = [2.5; 2.5; 3.5; 3.5];
examples.SIM_f0 = [300; 300; 500; 500];
examples.SIM_cs_bg = [2; 2; 3; 3];

examples.campaign_direction_count = ...
    [1; 1; 8; 8];

examples.radial_entropy = ...
    [0.1; 0.2; 0.3; 0.4];

examples.angular_spread = ...
    [1.0; 1.2; 1.4; 1.6];

examples.constant_feature = ...
    ones(4, 1);

examples.truth_material_purity = ...
    [1; 1; 0.8; 0.9];

examples.q_target_from_center_truth = ...
    [0.6; 0.7; 0.8; 0.9];

examples.target_valid = ...
    true(4, 1);

end
