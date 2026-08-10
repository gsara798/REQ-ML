function tests=test_homogeneous_splits
tests=functiontests(localfunctions);
end

function testCompositionalConditionHoldoutHasZeroLeakage(testCase)
[examples,conditions]=fixture();
held=conditions.cs_m_s==3 & conditions.frequency_hz==400;
split=reqml.homogeneous.makeConditionHoldoutSplit( ...
    examples,conditions,held,Seed=17,HoldoutId="cs3_f400");
report=reqml.splits.validate_split_integrity(examples,split);
verifyTrue(testCase,report.valid,report.summary);
test_conditions=unique(split.condition_id(split.test_mask));
expected=conditions.condition_id(held);
verifyEqual(testCase,sort(test_conditions),sort(expected));
verifyEmpty(testCase,intersect(test_conditions, ...
    unique(split.condition_id(split.train_mask))));
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
function testCompleteHoldoutSpecificationCount(testCase)
root=fileparts(fileparts(fileparts(mfilename("fullpath"))));
config=jsondecode(fileread(fullfile(root,"configs","homogeneous", ...
    "homogeneous_cartesian_q0_v1.json")));
spec=reqml.homogeneous.buildHoldoutSpecifications(config);
verifyEqual(testCase,height(spec),17);
verifyEqual(testCase,groupcounts(categorical(spec.family)),[1;4;3;4;5]);
verifyEqual(testCase,sum(spec.family~="compositional"),16);
verifyEqual(testCase,spec.experiment_id(end),"compositional_cs3_f400");
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
