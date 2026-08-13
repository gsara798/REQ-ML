function tests = test_deficit_aware_pilot_audit
%TEST_DEFICIT_AWARE_PILOT_AUDIT Test V4 center and rejection aggregation.

tests = functiontests(localfunctions);

end


function setupOnce(~)
root = fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(fullfile(root,"src"));
end


function testAggregatesMarginalCentersAndZeroOpportunityIteration(testCase)

root = make_pilot(testCase);
audit = reqml.analysis.auditDeficitAwarePilot(root, ...
    RecomputeRequestedMetrics=false,SaveOutputs=false);

summary = audit.center_selection_summary;
verifyEqual(testCase,summary.selected_center_count,[2;1]);
verifyEqual(testCase,summary.analytic_target_center_count,[1;1]);
verifyEqual(testCase,summary.opportunistic_center_count,[1;0]);
verifyEqual(testCase, ...
    summary.newly_observed_cells_with_opportunistic_contribution,[1;0]);
verifyEqual(testCase, ...
    summary.newly_complete_cells_with_opportunistic_contribution,[0;0]);
verifyEqual(testCase,summary.opportunistic_run_cell_pair_count,[1;0]);
verifyEqual(testCase,summary.opportunistic_condition_cell_pair_count,[1;0]);
verifyEqual(testCase,summary.analytic_target_cell_mismatch_count,[0;0]);
verifyEqual(testCase, ...
    summary.median_absolute_target_predicted_purity_error,[0.01;0.01], ...
    AbsTol=1e-12);
verifyEqual(testCase,height(audit.selected_center_audit),3);
verifyEqual(testCase,height(audit.pre_iteration_deficit_state),4);

rejections = audit.rejection_summary;
row = rejections.iteration_index==1 & ...
    rejections.rejection_reason=="insufficient_spatial_separation";
verifyEqual(testCase,rejections.rejection_count(row),3);

end


function testBuildsV2V3V4EqualIterationComparison(testCase)

root = make_pilot(testCase);
audit = reqml.analysis.auditDeficitAwarePilot(root,V2Root=root,V3Root=root, ...
    RecomputeRequestedMetrics=false,SaveOutputs=false);
comparison = audit.first_ten_comparison;
verifyEqual(testCase,height(comparison),6);
verifyEqual(testCase,unique(comparison.campaign_version),["v2";"v3";"v4"]);
for version=["v2","v3","v4"]
    verifyEqual(testCase,comparison.iteration_index( ...
        comparison.campaign_version==version),[1;2]);
end

end


function testMissingIterationArtifactFailsClearly(testCase)

root = make_pilot(testCase);
delete(fullfile(root,"iteration_002","pre_iteration_deficit_state.csv"));
verifyError(testCase,@() reqml.analysis.auditDeficitAwarePilot(root, ...
    RecomputeRequestedMetrics=false,SaveOutputs=false), ...
    "reqml:DeficitAwareAuditMissingArtifact");

end


function root = make_pilot(testCase)

root = string(testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
directories = [fullfile(root,"iteration_001");fullfile(root,"iteration_002")];
for directory=directories', mkdir(fullfile(directory,"dataset")); end

iterations = table((1:2)',[2;1],[2;3],[2;3],[2;2],[2;1], ...
    repmat(fullfile(root,"batch"),2,1),directories,VariableNames=[ ...
    "iteration_index","executed_run_count","accumulated_run_count", ...
    "example_count","observed_coverage_cell_count","deficient_cell_count", ...
    "batch_directory","iteration_directory"]);
writetable(iterations,fullfile(root,"adaptive_loop_iterations.csv"));

examples1 = make_examples(["run1";"run1"],["condition1";"condition1"], ...
    ["analytic_target";"opportunistic_deficit_fill"],["c1";"c2"], ...
    [false;true],[0.80;NaN],[0.81;0.75]);
examples2 = [examples1;make_examples("run2","condition2", ...
    "analytic_target","c1",false,0.80,0.79)];
examples = examples1; %#ok<NASGU>
save(fullfile(directories(1),"dataset","examples.mat"),"examples");
examples = examples2; %#ok<NASGU>
save(fullfile(directories(2),"dataset","examples.mat"),"examples");

summaries1 = table("run1",2,1,1,0,3,VariableNames=["run_id", ...
    "selected_center_count","analytic_target_example_count", ...
    "opportunistic_example_count","rejected_cell_already_complete", ...
    "rejected_insufficient_spatial_separation"]);
summaries2 = [summaries1;table("run2",1,1,0,2,0, ...
    VariableNames=summaries1.Properties.VariableNames)];
writetable(summaries1,fullfile(directories(1),"dataset","sample_summaries.csv"));
writetable(summaries2,fullfile(directories(2),"dataset","sample_summaries.csv"));

state1 = table(["c1";"c2"],[0;0],[false;false], ...
    VariableNames=["cell_key","example_count","coverage_complete"]);
state2 = table(["c1";"c2"],[1;1],[false;false], ...
    VariableNames=state1.Properties.VariableNames);
writetable(state1,fullfile(directories(1),"pre_iteration_deficit_state.csv"));
writetable(state2,fullfile(directories(2),"pre_iteration_deficit_state.csv"));

coverage1 = table(["c1";"c2"],[1;1], ...
    VariableNames=["cell_key","example_count"]);
coverage2 = table(["c1";"c2"],[2;1], ...
    VariableNames=coverage1.Properties.VariableNames);
writetable(coverage1,fullfile(directories(1),"coverage_summary.csv"));
writetable(coverage2,fullfile(directories(2),"coverage_summary.csv"));
writetable(table(["c1";"c2"],VariableNames="cell_key"), ...
    fullfile(directories(1),"coverage_deficits.csv"));
writetable(table("c2",VariableNames="cell_key"), ...
    fullfile(directories(2),"coverage_deficits.csv"));

requests1 = make_requests(0.01);
requests2 = make_requests(-0.01);
writetable(requests1,fullfile(directories(1),"requested_vs_achieved.csv"));
writetable(requests2,fullfile(directories(2),"requested_vs_achieved.csv"));

end


function examples = make_examples(run_id,condition_id,role,key,is_opportunistic, ...
        predicted,achieved)
n = numel(run_id);
examples = table(string(run_id),string(condition_id),string(role),string(key), ...
    ~logical(is_opportunistic),logical(is_opportunistic),false(n,1), ...
    double(predicted),double(achieved),VariableNames=[ ...
    "campaign_run_id","campaign_condition_id","center_selection_role", ...
    "achieved_cell_key","selected_for_requested_cell", ...
    "selected_for_opportunistic_cell","target_cell_mismatch", ...
    "predicted_discrete_purity","achieved_purity"]);
end


function requests = make_requests(error_value)
requests = table(true,1,1,1,error_value,VariableNames=[ ...
    "requested_cell_hit","patch_count","valid_patch_count", ...
    "requested_cell_patch_count","predicted_vs_achieved_purity_error"]);
end
