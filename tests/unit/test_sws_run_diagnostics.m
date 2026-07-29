function tests = test_sws_run_diagnostics
%TEST_SWS_RUN_DIAGNOSTICS Test run-level summaries and map reconstruction.

tests = functiontests(localfunctions);

end

function testRunSummaryGivesOneRowPerMap(test_case)

predictions = make_predictions();

summary = reqml.evaluation.summarize_sws_by_run( ...
    predictions, ...
    ModelId="bagged_full", ...
    Partition="test");

verifyEqual(test_case, height(summary), 2);
verifyEqual(test_case, sort(summary.patch_count), [4; 4]);

run_a = summary.campaign_run_id == "run_a";
run_b = summary.campaign_run_id == "run_b";

verifyEqual(test_case, summary.sws_mape(run_a), 0, AbsTol=0);
verifyGreaterThan(test_case, summary.sws_mape(run_b), 0);

end

function testMapReconstructionPreservesCoordinates(test_case)

predictions = make_predictions();

map = reqml.evaluation.reconstruct_sws_map( ...
    predictions, ...
    "run_a", ...
    ModelId="bagged_full", ...
    Partition="test");

verifyEqual(test_case, size(map.cs_pred_m_s), [2, 2]);
verifyEqual(test_case, map.patch_count, 4);

verifyEqual( ...
    test_case, ...
    map.x_center_m, ...
    [0.001; 0.002]);

verifyEqual( ...
    test_case, ...
    map.z_center_m, ...
    [0.003; 0.004]);

verifyEqual( ...
    test_case, ...
    map.cs_pred_m_s, ...
    2*ones(2));

end

function predictions = make_predictions()

run_id = [
    repmat("run_a", 4, 1)
    repmat("run_b", 4, 1)
    ];

x = [ ...
    0.001
    0.002
    0.001
    0.002
    ];

z = [ ...
    0.003
    0.003
    0.004
    0.004
    ];

predictions = table();

predictions.model_id = repmat("bagged_full", 8, 1);
predictions.partition = repmat("test", 8, 1);
predictions.campaign_run_id = run_id;

predictions.campaign_frequency_hz = ...
    [repmat(300, 4, 1); repmat(500, 4, 1)];

predictions.campaign_background_cs_m_s = ...
    [repmat(2, 4, 1); repmat(4, 4, 1)];

predictions.campaign_direction_count = ...
    [repmat(1, 4, 1); repmat(8, 4, 1)];

predictions.x_center_m = [x; x];
predictions.z_center_m = [z; z];

predictions.q_true = repmat(0.5, 8, 1);
predictions.q_pred = repmat(0.5, 8, 1);

predictions.cs_true_m_s = [
    repmat(2, 4, 1)
    repmat(4, 4, 1)
    ];

predictions.cs_pred_m_s = [
    repmat(2, 4, 1)
    3.6
    4.0
    4.4
    4.8
    ];

predictions.cs_error_m_s = ...
    predictions.cs_pred_m_s - predictions.cs_true_m_s;

predictions.cs_error_percent = ...
    100 * predictions.cs_error_m_s ./ ...
    predictions.cs_true_m_s;

predictions.cs_absolute_error_percent = ...
    abs(predictions.cs_error_percent);

predictions.sws_valid = true(8, 1);

end
