function tests=test_homogeneous_splits
tests=functiontests(localfunctions);
end
function setupOnce(~)
root=fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(fullfile(root,"src"));
end
function testHeldOutCsHasNoConditionLeakage(testCase)
[examples,conditions]=fixture();
s=reqml.homogeneous.makeHeldOutSplit(examples,conditions,"cs_m_s",3,Seed=91);
test_conditions=unique(examples.campaign_condition_id(s.test_mask));
rows=ismember(conditions.condition_id,test_conditions);
verifyEqual(testCase,unique(conditions.cs_m_s(rows)),3);
verifyFalse(testCase,any(ismember(test_conditions, ...
    unique(examples.campaign_condition_id(~s.test_mask)))));
verifyEqual(testCase,numel(unique(test_conditions)),4);
end
function testHeldOutFrequencyIsDeterministic(testCase)
[examples,conditions]=fixture();
a=reqml.homogeneous.makeHeldOutSplit(examples,conditions,"frequency_hz",400,Seed=92);
b=reqml.homogeneous.makeHeldOutSplit(examples,conditions,"frequency_hz",400,Seed=92);
verifyEqual(testCase,a.partition,b.partition);
test_conditions=unique(examples.campaign_condition_id(a.test_mask));
rows=ismember(conditions.condition_id,test_conditions);
verifyEqual(testCase,unique(conditions.frequency_hz(rows)),400);
end
function [examples,conditions]=fixture()
condition_id=compose("c%02d",(1:12)');
cs_m_s=repelem([1;2;3],4);
frequency_hz=repmat([200;300;400;500],3,1);
dx_m=repmat(.00025,12,1); field_regime=repmat("single",12,1);
conditions=table(condition_id,cs_m_s,frequency_hz,dx_m,field_regime);
campaign_condition_id=repelem(condition_id,6);
campaign_run_id=compose("%s_r%02d",campaign_condition_id, ...
    repmat(repelem((1:3)',2),12,1));
example_id=compose("e%04d",(1:72)');
examples=table(example_id,campaign_condition_id,campaign_run_id);
end
