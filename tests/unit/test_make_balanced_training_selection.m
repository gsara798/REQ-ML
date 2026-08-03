function tests = test_make_balanced_training_selection
%TEST_MAKE_BALANCED_TRAINING_SELECTION

tests = functiontests(localfunctions);

end


function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end


function testBalancesCellsAndConditions(testCase)

examples = make_examples();

result = ...
    reqml.datasets.makeBalancedTrainingSelection( ...
        examples, ...
        PurityEdges=[0.5 0.7 0.9 1.0], ...
        NominalAngularCoverageEdges=[0 0.5 1.0], ...
        SwsEdges=[1.5 3.0 4.5], ...
        FrequencyEdges=[199 400 601], ...
        MaximumExamplesPerCell=6, ...
        MaximumExamplesPerConditionPerCell=3, ...
        RandomSeed=81);

selected = result.examples.selected_for_training;
weights = result.examples.training_weight;

verifyEqual(testCase, nnz(selected), 11);

verifyTrue(testCase, ...
    all(weights(selected) > 0));

verifyTrue(testCase, ...
    all(weights(~selected) == 0));

verifyEqual(testCase, ...
    mean(weights(selected)), ...
    1, ...
    AbsTol=1e-12);

verifyEqual(testCase, ...
    result.summary.selected_example_count, ...
    [6; 5]);

verifyEqual(testCase, ...
    result.summary.training_weight_sum, ...
    [5.5; 5.5], ...
    AbsTol=1e-12);

end


function testSelectionIsReproducible(testCase)

examples = make_examples();

arguments = { ...
    "PurityEdges", [0.5 0.7 0.9 1.0], ...
    "NominalAngularCoverageEdges", [0 0.5 1.0], ...
    "SwsEdges", [1.5 3.0 4.5], ...
    "FrequencyEdges", [199 400 601], ...
    "MaximumExamplesPerCell", 5, ...
    "MaximumExamplesPerConditionPerCell", 3, ...
    "RandomSeed", 99 ...
    };

a = reqml.datasets.makeBalancedTrainingSelection( ...
    examples, arguments{:});

b = reqml.datasets.makeBalancedTrainingSelection( ...
    examples, arguments{:});

verifyEqual(testCase, ...
    a.examples.selected_for_training, ...
    b.examples.selected_for_training);

verifyEqual(testCase, ...
    a.examples.training_weight, ...
    b.examples.training_weight, ...
    AbsTol=0);

end


function examples = make_examples()

row_count = 20;

examples = table();

examples.truth_material_purity = [
    repmat(0.6, 10, 1)
    repmat(0.8, 10, 1)
    ];

examples.campaign_direction_count = [
    repmat(16, 10, 1)
    repmat(128, 10, 1)
    ];

examples.campaign_solid_angle_sr = [
    repmat(pi, 10, 1)
    repmat(4*pi, 10, 1)
    ];

examples.truth_cs_center_m_s = ...
    repmat(2.5, row_count, 1);

examples.campaign_frequency_hz = ...
    repmat(300, row_count, 1);

examples.campaign_condition_id = [
    repmat("condition_a", 7, 1)
    repmat("condition_b", 3, 1)
    repmat("condition_c", 8, 1)
    repmat("condition_d", 2, 1)
    ];

examples.campaign_run_id = compose( ...
    "run_%02d", ...
    (1:row_count)');

end
