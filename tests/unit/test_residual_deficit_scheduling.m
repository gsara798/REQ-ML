function tests = test_residual_deficit_scheduling
%TEST_RESIDUAL_DEFICIT_SCHEDULING Test production repeat decisions.
tests=functiontests(localfunctions);
end

function setupOnce(~)
root=fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(fullfile(root,"src"));
end

function testExampleOnlyDeficitUsesExistingCondition(testCase)
r=make_report(2,0,0,true);
q=map(r);
verifyEqual(testCase,q.planned_action,"opportunistic_examples");
verifyEqual(testCase,q.condition_id,"existing_condition");
verifyEqual(testCase,q.realization_count,1);
verifyEqual(testCase,q.realization_start_index,3);
verifyEqual(testCase,q.planned_new_condition_count,0);
end

function testRunDeficitSchedulesAdditionalRealization(testCase)
q=map(make_report(0,1,0,true));
verifyEqual(testCase,q.planned_action,"additional_realization");
verifyEqual(testCase,q.condition_id,"existing_condition");
verifyEqual(testCase,q.expected_independent_run_contribution,1);
end

function testConditionDeficitSchedulesNewPhysicalCondition(testCase)
q=map(make_report(0,0,1,true));
verifyEqual(testCase,q.planned_action,"new_condition");
verifyNotEqual(testCase,q.condition_id,"existing_condition");
verifyEqual(testCase,q.planned_new_condition_count,1);
verifyEqual(testCase,q.expected_independent_condition_contribution,1);
end

function testCompletedCellsAreNotRequested(testCase)
r=make_report(0,0,0,true);
r.deficits=r.deficits([], :);
q=map(r);
verifyEmpty(testCase,q);
end

function testAdditionalRealizationsPreserveConditionAndChangeRuns(testCase)
q=map(make_report(2,0,0,true));
q.realization_count=2; q.realization_start_index=1;
a=materialize(q);
q.realization_start_index=3;
b=materialize(q);
verifyEqual(testCase,a.condition_id,b.condition_id);
verifyEqual(testCase,a.seed,b.seed);
verifyEqual(testCase,a.material,b.material);
verifyEqual(testCase,a.wavefield,b.wavefield);
verifyEqual(testCase,a.geometry,b.geometry);
verifyEqual(testCase,a.geometry_control,b.geometry_control);
runs_a=reqml.campaigns.physicalConditionToSwsynthRuns(a);
runs_b=reqml.campaigns.physicalConditionToSwsynthRuns(b);
verifyEqual(testCase,[runs_a.realization_id],[1 2]);
verifyEqual(testCase,[runs_b.realization_id],[3 4]);
verifyEmpty(testCase,intersect(string({runs_a.design_id}), ...
    string({runs_b.design_id})));
seed_a=override_seed(runs_a); seed_b=override_seed(runs_b);
verifyEmpty(testCase,intersect(seed_a,seed_b));
end

function testNewConditionRematerializesNuisanceParameters(testCase)
q1=map(make_report(4,2,1,false),"batch_a");
q2=map(make_report(4,2,1,false),"batch_b");
a=materialize(q1); b=materialize(q2);
verifyNotEqual(testCase,a.condition_id,b.condition_id);
verifyNotEqual(testCase,a.seed,b.seed);
changed = a.wavefield.frequency_hz~=b.wavefield.frequency_hz || ...
    a.material.object_cs_m_s~=b.material.object_cs_m_s || ...
    a.geometry_control.dominant_material_side~= ...
        b.geometry_control.dominant_material_side;
verifyTrue(testCase,changed);
end

function request=map(report,prefix)
if nargin<2, prefix="batch"; end
request=reqml.campaigns.mapDeficitsToConditionRequests(report, ...
    MaximumConditions=12,RealizationsPerCondition=2,PlannerSeed=7, ...
    ConditionIdPrefix=prefix,SchedulingMode="residual_deficit_aware");
end

function condition=materialize(request)
request.geometry_family="bilayer";
condition=reqml.campaigns.materializePhysicalConditions(request, ...
    TrainingGeometryMode="analytic_bilayer",GridSpacingM=[.0005 .0005], ...
    PatchWindowWavelengths=3,CsGuessMPerS=3, ...
    PackingMode="packing_aware", ...
    DomainPolicyMode="adaptive_for_center_packing", ...
    DefaultDomainSizeM=[.05 .05],ExpandedDomainSizeM=[.07 .07], ...
    StableConditionSeedFromId=true,PlannerSeed=99);
end

function report=make_report(e,r,c,with_existing)
deficits=table(1,1,3,2,1,e,r,c,e+r+c,VariableNames=[ ...
    "sws_bin","frequency_bin","purity_bin","diffusivity_bin", ...
    "discretization_bin","example_deficit", ...
    "independent_run_deficit", ...
    "independent_condition_deficit","deficit_score"]);
report=struct("deficits",deficits,"config",struct( ...
    "purity_edges",[.5 .7 .9 .98 1], ...
    "diffusivity_edges",[0 .01 .05 .2 .5 1], ...
    "sws_edges",[1.5 2 2.5 3 3.5 4], ...
    "frequency_edges",[199 250 350 450 550 601], ...
    "discretization_pairs_m",[0.0005 0.0005]));
if with_existing
    report.assigned_examples=table( ...
        ["s01_f01_p03_d02_g01";"s01_f01_p03_d02_g01"], ...
        ["existing_condition";"existing_condition"],[1;2], ...
        ["analytic_target";"analytic_target"],VariableNames=[ ...
        "requested_condition_cell_key","campaign_condition_id", ...
        "campaign_realization_id","center_selection_role"]);
else
    report.assigned_examples=table(strings(0,1),strings(0,1), ...
        zeros(0,1),strings(0,1),VariableNames=[ ...
        "requested_condition_cell_key","campaign_condition_id", ...
        "campaign_realization_id","center_selection_role"]);
end
end

function seeds=override_seed(runs)
seeds=zeros(numel(runs),1);
for i=1:numel(runs)
    paths=string({runs(i).overrides.path});
    seeds(i)=runs(i).overrides(paths=="seed").value;
end
end
