function tests = test_regression_training
%TEST_REGRESSION_TRAINING Test reproducible ML training primitives.

tests = functiontests(localfunctions);

end

function testNumericMatrixPreservesOrder(test_case)

T = table( ...
    [1; 2; 3], ...
    [10; 20; 30], ...
    'VariableNames', ["a", "b"]);

[X, metadata] = reqml.training.build_numeric_predictor_matrix( ...
    T, ["b"; "a"]);

verifyEqual(test_case, X, [10 1; 20 2; 30 3]);
verifyEqual(test_case, metadata.predictor_names, ["b"; "a"]);

end

function testRidgeUsesTrainingRowsOnly(test_case)

x = (1:20)';
X = [x, x.^2];

target = 0.2 + 0.01*x;
target(16:20) = 0.95;

train_mask = false(20, 1);
train_mask(1:15) = true;

spec = struct( ...
    "id", "ridge_test", ...
    "type", "ridge", ...
    "lambda", 1.0, ...
    "random_seed", 41);

model = reqml.training.fit_regression_model( ...
    X, target, train_mask, spec);

prediction = reqml.training.predict_regression_model(model, X);

verifyEqual(test_case, model.training_row_count, 15);
verifyLessThan(test_case, mean(prediction(1:15)), 0.5);

end

function testRidgeIsDeterministic(test_case)

rng(7);
X = randn(100, 5);
target = 0.6 + X*[0.02; -0.03; 0.01; 0; 0.04];

train_mask = false(100, 1);
train_mask(1:70) = true;

spec = struct( ...
    "id", "ridge_test", ...
    "type", "ridge", ...
    "lambda", 0.5, ...
    "random_seed", 51);

model_a = reqml.training.fit_regression_model( ...
    X, target, train_mask, spec);

model_b = reqml.training.fit_regression_model( ...
    X, target, train_mask, spec);

verifyEqual(test_case, ...
    model_a.coefficients, ...
    model_b.coefficients, ...
    AbsTol=0);

end

function testBaggedTreesAreDeterministic(test_case)

rng(11);
X = randn(120, 4);
target = 0.7 + 0.03*X(:,1) - 0.02*X(:,2);

train_mask = false(120, 1);
train_mask(1:80) = true;

spec = struct( ...
    "id", "bag_test", ...
    "type", "bagged_trees", ...
    "num_learning_cycles", 20, ...
    "min_leaf_size", 5, ...
    "use_parallel", false, ...
    "random_seed", 61);

model_a = reqml.training.fit_regression_model( ...
    X, target, train_mask, spec);

prediction_a = reqml.training.predict_regression_model(model_a, X);

model_b = reqml.training.fit_regression_model( ...
    X, target, train_mask, spec);

prediction_b = reqml.training.predict_regression_model(model_b, X);

verifyEqual(test_case, prediction_a, prediction_b, AbsTol=0);

end

function testTrainingRestoresRandomState(test_case)

% Generate fixture data before establishing the RNG state under test.
rng(1234);
X = randn(30, 2);
target = 0.5 + 0.01*X(:,1);

train_mask = false(30, 1);
train_mask(1:20) = true;

spec = struct( ...
    "id", "ridge_test", ...
    "type", "ridge", ...
    "lambda", 1.0, ...
    "random_seed", 71);

% Capture the precise state that must survive model fitting.
rng(4321, "twister");
state_before_training = rng;

expected_next_value = rand();

% Restore the captured state, fit, and verify the next draw is unchanged.
rng(state_before_training);

reqml.training.fit_regression_model( ...
    X, target, train_mask, spec);

actual_next_value = rand();

verifyEqual( ...
    test_case, ...
    actual_next_value, ...
    expected_next_value, ...
    AbsTol=0);

end
