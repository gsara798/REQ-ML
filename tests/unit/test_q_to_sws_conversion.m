function tests = test_q_to_sws_conversion
%TEST_Q_TO_SWS_CONVERSION Test q-to-k-to-SWS conversion.

tests = functiontests(localfunctions);

end

function testExactMappingRecovery(test_case)

campaign_frequency_hz = [500; 500];
truth_cs_center_m_s = [2; 4];

mapping_a = struct( ...
    "Ecum", single([0; 0.5; 1]), ...
    "k_cent", single([0; 500*pi; 1000*pi]));

mapping_b = struct( ...
    "Ecum", single([0; 0.5; 1]), ...
    "k_cent", single([0; 250*pi; 500*pi]));

req_mapping = {mapping_a; mapping_b};

examples = table( ...
    campaign_frequency_hz, ...
    truth_cs_center_m_s, ...
    req_mapping);

q_pred = [0.5; 0.5];

result = reqml.evaluation.convert_q_predictions_to_sws( ...
    examples, q_pred);

verifyEqual( ...
    test_case, ...
    result.cs_pred_m_s, ...
    truth_cs_center_m_s, ...
    RelTol=1e-6);

verifyTrue(test_case, all(result.sws_valid));

end

function testSwsMetricsRemainPartitioned(test_case)

sws_table = table();
sws_table.cs_true_m_s = ones(6, 1) * 2;
sws_table.cs_pred_m_s = [2; 2; 3; 3; 2; 2];
sws_table.cs_error_m_s = ...
    sws_table.cs_pred_m_s - sws_table.cs_true_m_s;
sws_table.cs_error_percent = ...
    100*sws_table.cs_error_m_s ./ sws_table.cs_true_m_s;
sws_table.cs_absolute_error_percent = ...
    abs(sws_table.cs_error_percent);
sws_table.sws_valid = true(6, 1);

partition = [ ...
    "train"
    "train"
    "validation"
    "validation"
    "test"
    "test"];

metrics = reqml.evaluation.evaluate_sws_predictions( ...
    sws_table, partition, "synthetic");

validation = metrics.partition == "validation";
test = metrics.partition == "test";

verifyGreaterThan(test_case, metrics.sws_mape(validation), 0);
verifyEqual(test_case, metrics.sws_mape(test), 0, AbsTol=0);

end
