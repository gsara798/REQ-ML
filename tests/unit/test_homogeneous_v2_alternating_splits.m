function tests=test_homogeneous_v2_alternating_splits
tests=functiontests(localfunctions);
end

function testSwsAlternatingIntegrity(testCase)
[e,cfg,d]=fixture(); s=reqml.homogeneous.makeV2AlternatingSplit(e,d.conditions,"sws",cfg);
test_cs=unique(d.conditions.cs_m_s(s.conditions.partition=="test"));
verifyEqual(testCase,test_cs,double(cfg.splits.sws_interpolation_test_m_s(:)));
verifyEmpty(testCase,intersect(unique(e.campaign_condition_id(s.train_mask)), ...
    unique(e.campaign_condition_id(s.test_mask))));
verifyEqual(testCase,unique(e.REQ_M(s.test_mask)),[2;3]);
end

function testAngularAlternatingIntegrity(testCase)
[e,cfg,d]=fixture(); s=reqml.homogeneous.makeV2AlternatingSplit(e,d.conditions,"angular",cfg);
levels=unique(d.conditions.angular_level(s.conditions.partition=="test"));
verifyEqual(testCase,levels,double(cfg.splits.angular_interpolation_test_levels(:)));
verifyFalse(testCase,any(ismember(d.conditions.angular_level( ...
    s.conditions.partition~="test"),levels)));
end

function testRejectsIncompleteSupport(testCase)
[e,cfg,d]=fixture(); cfg.splits.angular_interpolation_test_levels=[2 4];
verifyError(testCase,@() reqml.homogeneous.makeV2AlternatingSplit( ...
    e,d.conditions,"angular",cfg),"reqml:InvalidV2AlternatingSupport");
end

function [e,cfg,d]=fixture
root=string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
cfg=jsondecode(fileread(fullfile(root,"configs","homogeneous","homogeneous_cartesian_q0_v2.json")));
d=reqml.homogeneous.materializeCartesianDesign(cfg);
ids=repelem(d.conditions.condition_id,2); M=repmat([2;3],height(d.conditions),1);
e=table(ids,M,ids,VariableNames=["campaign_condition_id","REQ_M","campaign_run_id"]);
end
