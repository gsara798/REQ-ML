function tests = test_reproducible_baseline_pipeline
%TEST_REPRODUCIBLE_BASELINE_PIPELINE Test split and baseline correctness.

tests = functiontests(localfunctions);

end

function testConfigurableGroupedSplit(test_case)

examples = make_examples();

split_a = reqml.splits.make_grouped_condition_split( ...
    examples, ...
    GroupColumns=["material_id", "frequency_hz"], ...
    RunColumn="run_id", ...
    Seed=91, ...
    TrainFraction=0.50, ...
    ValidationFraction=0.25, ...
    TestFraction=0.25);

split_b = reqml.splits.make_grouped_condition_split( ...
    examples, ...
    GroupColumns=["material_id", "frequency_hz"], ...
    RunColumn="run_id", ...
    Seed=91, ...
    TrainFraction=0.50, ...
    ValidationFraction=0.25, ...
    TestFraction=0.25);

verifyEqual(test_case, split_a.partition, split_b.partition);
verifyEqual(test_case, split_a.condition_id, split_b.condition_id);

verifyFalse(test_case, any(split_a.train_mask & split_a.validation_mask));
verifyFalse(test_case, any(split_a.train_mask & split_a.test_mask));
verifyFalse(test_case, any(split_a.validation_mask & split_a.test_mask));

verifyTrue(test_case, all( ...
    split_a.train_mask | ...
    split_a.validation_mask | ...
    split_a.test_mask));

conditions = unique(split_a.condition_id);

for index = 1:numel(conditions)
    mask = split_a.condition_id == conditions(index);
    verifyEqual(test_case, numel(unique(split_a.partition(mask))), 1);
end

end

function testFixedQUsesTrainingRowsOnly(test_case)

target = [0.2; 0.3; 0.4; 0.9; 0.99];
train_mask = [true; true; true; false; false];

result = reqml.baselines.predict_fixed_q( ...
    target, ...
    train_mask, ...
    Estimator="median");

verifyEqual(test_case, result.fitted_value, 0.3, AbsTol=1e-12);
verifyEqual(test_case, result.q_pred, repmat(0.3, 5, 1), AbsTol=1e-12);

end

function testTheoryBaselineRejectsInvalidRows(test_case)

verifyError(test_case, ...
    @() reqml.baselines.predict_discrete_theory_q( ...
        [0.6; NaN], ...
        [true; false]), ...
    "reqml:InvalidTheoryBaselineRows");

end

function testMetricsKeepValidationSeparate(test_case)

q_true = [0.2; 0.3; 0.4; 0.5; 0.6; 0.7];
q_pred = [0.2; 0.3; 0.4; 0.9; 0.6; 0.7];

partition = [ ...
    "train"
    "train"
    "validation"
    "validation"
    "test"
    "test"
    ];

metrics = reqml.evaluation.evaluate_q_predictions( ...
    q_true, ...
    q_pred, ...
    partition, ...
    "synthetic");

verifyEqual(test_case, height(metrics), 3);

validation_row = metrics.partition == "validation";
test_row = metrics.partition == "test";

verifyGreaterThan(test_case, metrics.q_mae(validation_row), 0);
verifyEqual(test_case, metrics.q_mae(test_row), 0, AbsTol=1e-12);

end

function testRegistrySelection(test_case)

registry = table( ...
    ["frequency"; "feature_a"; "target_q"; "theory_q"], ...
    ["operational_context"; "radial"; "target"; "theory_baseline"], ...
    [true; true; false; false], ...
    'VariableNames', ["variable_name", "group", "trainable"]);

context = reqml.training.select_predictors_from_registry( ...
    registry, ...
    "context_only");

full = reqml.training.select_predictors_from_registry( ...
    registry, ...
    "full");

verifyEqual(test_case, context, "frequency");
verifyEqual(test_case, full, ["frequency"; "feature_a"]);

end

function examples = make_examples()

material_id = repelem((1:4)', 4);
frequency_hz = repmat(repelem([300; 500], 2), 4, 1);
run_id = "run_" + string((1:16)');

examples = table(material_id, frequency_hz, run_id);

end

function testPersistedSplitArtifactsMatch(test_case)

examples = make_examples();

split = reqml.splits.make_grouped_condition_split( ...
    examples, ...
    GroupColumns=["material_id", "frequency_hz"], ...
    RunColumn="run_id", ...
    Seed=91, ...
    TrainFraction=0.50, ...
    ValidationFraction=0.25, ...
    TestFraction=0.25);

output_directory = string(tempname);
cleanup = onCleanup(@() remove_directory(output_directory));

paths = reqml.splits.save_grouped_condition_split( ...
    split, ...
    output_directory);

loaded = load(paths.examples_mat, "example_partitions");
mat_table = loaded.example_partitions;

csv_table = readtable( ...
    paths.examples_csv, ...
    Delimiter=",", ...
    ReadVariableNames=true, ...
    TextType="string", ...
    VariableNamingRule="preserve");

verifyEqual(test_case, ...
    string(csv_table.Properties.VariableNames), ...
    ["row_index", "condition_id", "partition"]);

verifyEqual(test_case, mat_table.row_index, csv_table.row_index);
verifyEqual(test_case, mat_table.condition_id, string(csv_table.condition_id));
verifyEqual(test_case, mat_table.partition, string(csv_table.partition));

clear cleanup

end

function remove_directory(path)

if isfolder(path)
    rmdir(path, "s");
end

end
