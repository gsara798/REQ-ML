function tests = test_select_deficit_aware_centers
%TEST_SELECT_DEFICIT_AWARE_CENTERS Test hybrid analytic center selection.
tests = functiontests(localfunctions);
end

function setupOnce(~)
root = fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(fullfile(root,"src"));
end

function testTargetIsFirstAndOpportunisticCellsAreClassified(testCase)
[truth,state,target,options] = fixture();
r = call_selector(truth,state,target,options);
verifyEqual(testCase,r.centers.center_selection_role(1),"analytic_target");
verifyEqual(testCase,r.centers.achieved_cell_key(1),target.requested_cell_key);
verifyGreaterThan(testCase,height(r.centers),1);
verifyTrue(testCase,all(r.centers.center_selection_role(2:end)== ...
    "opportunistic_deficit_fill"));
verifyTrue(testCase,all(r.centers.coverage_valid));
end

function testCompleteCellsAreExcludedAndZeroDeficitsReturnTarget(testCase)
[truth,state,target,options] = fixture();
state.coverage_complete(:)=true;
state.example_deficit(:)=0;
state.independent_run_deficit(:)=0;
state.independent_condition_deficit(:)=0;
state.deficit_score(:)=0;
r=call_selector(truth,state,target,options);
verifyEqual(testCase,height(r.centers),1);
verifyEqual(testCase,r.centers.center_selection_role,"analytic_target");
end

function testRunDeficitHasPriorityOverExampleOnly(testCase)
[truth,state,target,options] = fixture();
keys=unique_candidate_keys(truth,state,target,options);
keys(keys==target.requested_cell_key)=[];
verifyGreaterThanOrEqual(testCase,numel(keys),2);
state.coverage_complete(:)=true;
state.example_deficit(:)=0; state.independent_run_deficit(:)=0;
state.independent_condition_deficit(:)=0; state.deficit_score(:)=0;
i1=find(state.cell_key==keys(1)); i2=find(state.cell_key==keys(2));
state.coverage_complete([i1 i2])=false;
state.example_deficit([i1 i2])=[1 4];
state.independent_run_deficit([i1 i2])=[1 0];
state.deficit_score([i1 i2])=[1 3];
options.MaximumCentersPerRun=2;
r=call_selector(truth,state,target,options);
verifyEqual(testCase,r.centers.achieved_cell_key(2),keys(1));
end

function testExampleOnlyDeficitIsEligible(testCase)
[truth,state,target,options] = fixture();
state.independent_run_deficit(:)=0;
state.independent_condition_deficit(:)=0;
state.coverage_complete=state.example_deficit==0;
r=call_selector(truth,state,target,options);
verifyGreaterThan(testCase,height(r.centers),1);
verifyTrue(testCase,any(r.centers.pre_iteration_example_deficit(2:end)>0));
end

function testCapsAndSpatialSeparationAreEnforced(testCase)
[truth,state,target,options] = fixture();
options.MaximumCentersPerRun=3;
options.MaximumCentersPerCellPerRun=1;
options.MinimumCenterSeparationFraction=1;
r=call_selector(truth,state,target,options);
verifyLessThanOrEqual(testCase,height(r.centers),3);
verifyLessThanOrEqual(testCase,max(groupcounts( ...
    categorical(r.centers.achieved_cell_key))),1);
if height(r.centers)>1
    verifyGreaterThanOrEqual(testCase,min( ...
        r.centers.distance_to_nearest_selected_center_pixels(2:end)),9);
end
end

function testSelectionIsDeterministic(testCase)
[truth,state,target,options] = fixture();
a=call_selector(truth,state,target,options);
b=call_selector(truth,state,target,options);
verifyEqual(testCase,a.centers,b.centers);
verifyEqual(testCase,a.rejection_counts,b.rejection_counts);
end

function testTargetMismatchIsAuditable(testCase)
[truth,state,target,options] = fixture();
target.requested_cell_key="s03_f01_p01_d02_g01";
r=call_selector(truth,state,target,options);
verifyTrue(testCase,r.centers.target_cell_mismatch(1));
verifyFalse(testCase,r.centers.selected_for_requested_cell(1));
end

function testMissingDeficitDataRaisesClearError(testCase)
[truth,state,target,options] = fixture();
state=removevars(state,"deficit_score");
verifyError(testCase,@()call_selector(truth,state,target,options), ...
    "reqml:MissingPreIterationDeficitData");
end

function testCoverageIndependenceUsesRunsAndConditions(testCase)
examples=make_examples(["r1";"r1";"r2";"r2"], ...
    ["c1";"c1";"c1";"c1"]);
r=reqml.coverage.computePatchCoverage(examples,FieldCoverageMode="nominal", ...
    PurityEdges=[.5 .7 .9 .98 1],DiffusivityEdges=[0 .01 .05 1], ...
    SwsEdges=[1.5 2 2.5 3],FrequencyEdges=[199 300], ...
    MinimumExamples=4,MinimumIndependentRuns=2, ...
    MinimumIndependentConditions=1);
row=r.observed_summary(1,:);
verifyEqual(testCase,row.example_count,4);
verifyEqual(testCase,row.independent_run_count,2);
verifyEqual(testCase,row.independent_condition_count,1);
end

function keys=unique_candidate_keys(truth,state,target,options)
options.MinimumCenterSeparationFraction=0;
options.MaximumCentersPerCellPerRun=1;
r=call_selector(truth,state,target,options);
keys=unique(r.centers.achieved_cell_key,"stable");
end

function r=call_selector(truth,state,target,o)
r=reqml.datasets.selectDeficitAwareCenters(truth,9,state,target, ...
    PurityEdges=o.PurityEdges,DiffusivityEdges=o.DiffusivityEdges, ...
    SwsEdges=o.SwsEdges,FrequencyEdges=o.FrequencyEdges, ...
    FrequencyHz=220,Dnom=.02,CandidateStepPixels=2, ...
    MaximumCentersPerRun=o.MaximumCentersPerRun, ...
    MaximumCentersPerCellPerRun=o.MaximumCentersPerCellPerRun, ...
    MinimumCenterSeparationFraction=o.MinimumCenterSeparationFraction, ...
    MinimumValidFraction=1,DeterministicSeed=7, ...
    GridSpacingM=[0.0005 0.0005], ...
    DiscretizationPairsM=[0.0005 0.0005], ...
    XCoordinatesM=(0:40)'*.0005,ZCoordinatesM=(0:40)'*.0005, ...
    InterfaceOrientation="x",InterfacePositionM=.01);
end

function [truth,state,target,o]=fixture()
[X,~]=meshgrid(1:41,1:41);
truth.material_id_zx=uint16(X>21);
truth.cs_m_s_zx=1.75*ones(41); truth.cs_m_s_zx(X>21)=2.75;
truth.valid_mask_zx=true(41);
o.PurityEdges=[.5 .7 .9 .98 1]; o.DiffusivityEdges=[0 .01 .05 1];
o.SwsEdges=[1.5 2 2.5 3]; o.FrequencyEdges=[199 300];
o.MaximumCentersPerRun=12; o.MaximumCentersPerCellPerRun=2;
o.MinimumCenterSeparationFraction=.75;
empty=table( ...
    zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
    zeros(0,1),zeros(0,1),zeros(0,1),VariableNames=[ ...
    "sws_bin","frequency_bin","purity_bin","diffusivity_bin", ...
    "discretization_bin","example_count", ...
    "independent_run_count","independent_condition_count"]);

summary=reqml.coverage.completeCoverageGrid( ...
    empty,o.SwsEdges,o.FrequencyEdges,o.PurityEdges,o.DiffusivityEdges, ...
    [0.0005 0.0005]);
state=reqml.coverage.findCoverageDeficits(summary,MinimumExamples=4, ...
    MinimumIndependentRuns=2,MinimumIndependentConditions=1,IncludeComplete=true);
target.center_indices_xz=[17 21];
target.requested_cell_key="s01_f01_p04_d02_g01";
target.predicted_discrete_purity=1;
end

function t=make_examples(runs,conditions)
n=numel(runs);
t=table(repmat(.6,n,1),repmat(1.75,n,1),repmat(220,n,1), ...
    repmat(16,n,1),repmat(.1,n,1), ...
    repmat(0.0005,n,1),repmat(0.0005,n,1), ...
    runs,conditions,VariableNames=[ ...
    "truth_material_purity","truth_cs_center_m_s", ...
    "campaign_frequency_hz","campaign_direction_count", ...
    "campaign_solid_angle_sr","GRID_dx_m","GRID_dz_m", ...
    "campaign_run_id","campaign_condition_id"]);
end
