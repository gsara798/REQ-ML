function tests=test_homogeneous_q0_reporting
tests=functiontests(localfunctions);
end
function setupOnce(~)
root=fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(fullfile(root,"src"));
end
function testGroupedMetricsIncludeBiasAndThresholds(testCase)
n=8; cs_m_s=repelem([2;3],4); frequency_hz=repmat([400;400],4,1);
field_regime=repmat(["single";"directional"],4,1);
q_true=.7*ones(n,1); q_error=[-.01;.01;-.02;.02;-.03;.03;-.04;.04];
q_pred=q_true+q_error; cs_error_percent=100*q_error;
cs_absolute_error_percent=abs(cs_error_percent);
cs_error_m_s=cs_m_s.*cs_error_percent/100;
cs_true_m_s=cs_m_s; cs_pred_m_s=cs_true_m_s+cs_error_m_s;
sws_valid=true(n,1); partition=repmat("test",n,1);
T=table(partition,cs_m_s,frequency_hz,field_regime,q_true,q_pred,q_error, ...
    cs_true_m_s,cs_pred_m_s,cs_error_m_s,cs_error_percent, ...
    cs_absolute_error_percent,sws_valid);
s=reqml.homogeneous.summarizeQ0ByGroup(T,"cs_m_s");
verifyEqual(testCase,height(s),2);
verifyTrue(testCase,all(ismember(["q_mae","q_bias","sws_mape", ...
    "sws_error_gt10_pct","sws_underestimate_pct"], ...
    string(s.Properties.VariableNames))));
verifyEqual(testCase,s.sws_underestimate_pct,[50;50]);
end

function testPartitionAwareGrouping(testCase)
partition=["train";"train";"test";"test"];
cs_m_s=[2;2;2;2];
q_true=.5*ones(4,1); q_error=[-.01;.01;-.02;.02]; q_pred=q_true+q_error;
cs_true_m_s=cs_m_s; cs_error_percent=100*q_error;
cs_absolute_error_percent=abs(cs_error_percent);
cs_error_m_s=cs_true_m_s.*q_error;
cs_pred_m_s=cs_true_m_s+cs_error_m_s; sws_valid=true(4,1);
T=table(partition,cs_m_s,q_true,q_pred,q_error,cs_true_m_s, ...
    cs_pred_m_s,cs_error_m_s,cs_error_percent, ...
    cs_absolute_error_percent,sws_valid);
s=reqml.homogeneous.summarizeQ0ByGroup(T,["partition","cs_m_s"]);
verifyEqual(testCase,height(s),2);
verifyEqual(testCase,sort(s.partition),["test";"train"]);
verifyEqual(testCase,s.row_count,[2;2]);
end
