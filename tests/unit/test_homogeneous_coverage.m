function tests=test_homogeneous_coverage
tests=functiontests(localfunctions);
end
function setupOnce(~)
root=fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(fullfile(root,"src"));
end
function testCompleteCoverageAggregation(testCase)
[d,csv,s]=fixture(100);
coverage=reqml.homogeneous.summarizeCoverage(d,csv,s);
verifyTrue(testCase,coverage.complete);
verifyEqual(testCase,coverage.completed_condition_count,1);
verifyEqual(testCase,coverage.selected_patch_count,300);
verifyEqual(testCase,coverage.conditions.coverage_fraction,1);
end
function testSupplementaryPlanForNonstructuralDeficit(testCase)
[d,csv,s,cfg]=fixture(80);
coverage=reqml.homogeneous.summarizeCoverage(d,csv,s);
plan=reqml.homogeneous.planCoverageDeficits(coverage,cfg);
verifyEqual(testCase,plan.action_count,1);
verifyEqual(testCase,plan.actions.action,"supplementary_realization");
verifyEqual(testCase,plan.actions.realization_index,4);
verifyGreaterThan(testCase,plan.actions.seed,max(d.runs.seed));
end
function testStructuralDeficitUsesLargerDomain(testCase)
[d,csv,s,cfg]=fixture(70);
s.available_patch_count(:)=70;
coverage=reqml.homogeneous.summarizeCoverage(d,csv,s);
plan=reqml.homogeneous.planCoverageDeficits(coverage,cfg);
verifyEqual(testCase,unique(plan.actions.action),"larger_domain");
verifyGreaterThan(testCase,plan.actions.domain_x_m,d.conditions.domain_x_m);
end
function testDatasetInvariantGate(testCase)
cfg=jsondecode(fileread(config_path()));
d=reqml.homogeneous.materializeCartesianDesign(cfg);
examples=table(["e1";"e2"],["r1";"r2"],[1;2],[1;2], ...
    ["homogeneous";"homogeneous"],[1;1],[2;2],[3;3],[true;true], ...
    VariableNames=["example_id","campaign_run_id","cx","cz", ...
    "campaign_geometry_family","truth_material_purity","REQ_M", ...
    "REQ_cs_guess_m_s","target_valid"]);
dataset=struct("examples",examples);
coverage=struct("complete",true,"completed_condition_count",240, ...
    "condition_count",240);
report=reqml.homogeneous.validateDataset(dataset,d,coverage,cfg);
verifyTrue(testCase,report.valid);
dataset.examples.truth_material_purity(2)=.9;
verifyError(testCase,@() reqml.homogeneous.validateDataset( ...
    dataset,d,coverage,cfg),"reqml:HomogeneousCartesianDatasetGateFailed");
end
function [d,csv,s,cfg]=fixture(selected)
cfg=jsondecode(fileread(config_path()));
full=reqml.homogeneous.materializeCartesianDesign(cfg);
d=full; d.conditions=full.conditions(1,:); d.runs=full.runs(1:3,:);
d.condition_count=1; d.run_count=3;
root=string(tempname); mkdir(root); csv=fullfile(root,"campaign_runs.csv");
design_id=d.runs.design_id; condition_id=d.runs.condition_id;
realization_id=d.runs.realization_index; run_id=compose("run_%03d",(1:3)');
status=repmat("completed",3,1); wavefield_sample_path=compose("sample_%d.mat",(1:3)');
T=table(design_id,condition_id,realization_id,run_id,status, ...
    wavefield_sample_path); writetable(T,csv);
s=table(run_id,repmat(100,3,1),repmat(selected,3,1), ...
    repmat(100-selected,3,1),repmat(d.conditions.patch_width_px,3,1), ...
    repmat(d.conditions.patch_height_px,3,1), ...
    repmat(d.conditions.stride_x_px,3,1),repmat(d.conditions.stride_z_px,3,1), ...
    VariableNames=["run_id","available_patch_count","selected_patch_count", ...
    "deficit_patch_count","patch_width_px","patch_height_px", ...
    "stride_x_px","stride_z_px"]);
end
function path=config_path()
root=fileparts(fileparts(fileparts(mfilename("fullpath"))));
path=fullfile(root,"configs","homogeneous","homogeneous_cartesian_q0_v1.json");
end
