function tests = test_purity_evaluation
%TEST_PURITY_EVALUATION Test partitioned purity metrics.

tests = functiontests(localfunctions);

end

function testComputesMetricsByPartition(testCase)

truth = [0.2; 0.4; 0.6; 0.8; 0.9; 1.0];
prediction = [0.3; 0.4; 0.5; 0.9; 0.8; 1.0];

partition = [
    "train"
    "train"
    "validation"
    "validation"
    "test"
    "test"
    ];

metrics = reqml.evaluation.evaluate_purity_predictions( ...
    truth, prediction, partition, "purity_test");

verifyEqual(testCase, height(metrics), 3);
verifyEqual(testCase, ...
    metrics.partition, ...
    ["train"; "validation"; "test"]);

verifyEqual(testCase, ...
    metrics.purity_mae, ...
    [0.05; 0.10; 0.05], ...
    AbsTol=1e-12);

end
