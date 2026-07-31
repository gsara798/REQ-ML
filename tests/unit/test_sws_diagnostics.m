function tests = test_sws_diagnostics
%TEST_SWS_DIAGNOSTICS Test grouped and worst-case SWS diagnostics.

tests = functiontests(localfunctions);

end

function testGroupedSummarySeparatesConditions(test_case)

predictions = make_predictions();

summary = reqml.evaluation.summarize_sws_by_group( ...
    predictions, ...
    ["campaign_frequency_hz"; "campaign_direction_count"], ...
    ModelId="bagged_full", ...
    Partition="test");

verifyEqual(test_case, height(summary), 2);
verifyEqual(test_case, sum(summary.row_count), 4);
verifyGreaterThanOrEqual(test_case, ...
    summary.sws_mape(1), summary.sws_mape(2));

end

function testWorstCasesAreSorted(test_case)

predictions = make_predictions();

worst = reqml.evaluation.select_worst_sws_predictions( ...
    predictions, ...
    ModelId="bagged_full", ...
    Partition="test", ...
    Count=3);

verifyEqual(test_case, height(worst), 3);

verifyTrue(test_case, all(diff( ...
    worst.cs_absolute_error_percent) <= 0));

end

function predictions = make_predictions()

predictions = table();

predictions.model_id = repmat("bagged_full", 4, 1);
predictions.partition = repmat("test", 4, 1);

predictions.campaign_run_id = ...
    ["run1"; "run1"; "run2"; "run2"];

predictions.campaign_frequency_hz = ...
    [300; 300; 500; 500];

predictions.campaign_background_cs_m_s = ...
    [2; 2; 4; 4];

predictions.campaign_direction_count = ...
    [1; 1; 8; 8];

predictions.patch_idx = (1:4)';
predictions.cx = (1:4)';
predictions.cz = (1:4)';
predictions.x_center_m = (1:4)' * 0.001;
predictions.z_center_m = (1:4)' * 0.001;

predictions.q_true = [0.5; 0.5; 0.7; 0.7];
predictions.q_pred = [0.5; 0.6; 0.65; 0.9];

predictions.k_pred_rad_m = [100; 110; 120; 130];

predictions.cs_true_m_s = [2; 2; 4; 4];
predictions.cs_pred_m_s = [2; 2.2; 3.6; 5];

predictions.cs_error_m_s = ...
    predictions.cs_pred_m_s - predictions.cs_true_m_s;

predictions.cs_error_percent = ...
    100 * predictions.cs_error_m_s ./ predictions.cs_true_m_s;

predictions.cs_absolute_error_percent = ...
    abs(predictions.cs_error_percent);

predictions.sws_valid = true(4, 1);

end
