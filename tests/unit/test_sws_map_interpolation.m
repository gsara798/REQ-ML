function tests = test_sws_map_interpolation
%TEST_SWS_MAP_INTERPOLATION Test explicit map interpolation.

tests = functiontests(localfunctions);

end

function testInterpolationPreservesNativeNodes(test_case)

map = struct();
map.model_id = "bagged_full";
map.partition = "test";
map.campaign_run_id = "synthetic";

map.x_center_m = [0; 0.002];
map.z_center_m = [0; 0.002];

map.cs_pred_m_s = [
    2.0, 2.2
    2.4, 2.6
    ];

map.cs_true_m_s = 2*ones(2);

interpolated = reqml.evaluation.interpolate_sws_map( ...
    map, ...
    QuerySpacingM=0.001, ...
    Method="linear");

verifyEqual(test_case, size(interpolated.cs_pred_m_s), [3, 3]);

verifyEqual(test_case, ...
    interpolated.cs_pred_m_s(1,1), ...
    map.cs_pred_m_s(1,1), ...
    AbsTol=0);

verifyEqual(test_case, ...
    interpolated.cs_pred_m_s(1,end), ...
    map.cs_pred_m_s(1,end), ...
    AbsTol=0);

verifyEqual(test_case, ...
    interpolated.cs_pred_m_s(end,1), ...
    map.cs_pred_m_s(end,1), ...
    AbsTol=0);

verifyEqual(test_case, ...
    interpolated.cs_pred_m_s(end,end), ...
    map.cs_pred_m_s(end,end), ...
    AbsTol=0);

end
