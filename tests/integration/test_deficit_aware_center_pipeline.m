function tests = test_deficit_aware_center_pipeline
%TEST_DEFICIT_AWARE_CENTER_PIPELINE Test hybrid extraction metadata end to end.

tests = functiontests(localfunctions);

end


function setupOnce(~)

root = fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(fullfile(root, "src"));

end


function testBuildPreservesTargetAndAddsTraceableDeficitCenters(testCase)

fixture = make_fixture(testCase);
edges = coverage_edges();
state = empty_deficit_state(edges);

dataset = reqml.datasets.build_dataset_from_campaign( ...
    fixture.campaign_csv, struct("M", 2), ...
    DatasetId="hybrid_center_integration", MaxSamples=1, ...
    SaveOutputs=false, AdaptiveBatchPlanFile=fixture.plan_file, ...
    CenterSelectionMode= ...
        "analytic_target_plus_deficit_aware_centers", ...
    PreIterationDeficitState=state, ...
    PurityEdges=edges.purity, DiffusivityEdges=edges.dnom, ...
    SwsEdges=edges.sws, FrequencyEdges=edges.frequency, ...
    CandidateStepPixels=2, MaximumCentersPerRun=4, ...
    MaximumCentersPerCellPerRun=2, ...
    MinimumCenterSeparationFraction=0.75, ...
    RealizationsPerCondition=2, Loader=@hybrid_loader, ...
    ReadinessEvaluator=@hybrid_readiness, Extractor=@hybrid_extractor);

examples = dataset.examples;
verifyGreaterThan(testCase, height(examples), 1);
verifyEqual(testCase, examples.center_selection_role(1), "analytic_target");
verifyTrue(testCase, all(examples.center_selection_role(2:end) == ...
    "opportunistic_deficit_fill"));
verifyEqual(testCase, examples.center_rank, (1:height(examples))');
verifyTrue(testCase, examples.selected_for_requested_cell(1));
verifyFalse(testCase, examples.target_cell_mismatch(1));
verifyEqual(testCase, examples.predicted_discrete_purity(1), ...
    examples.achieved_purity(1), AbsTol=1e-12);
verifyTrue(testCase, all(examples.pre_iteration_example_count == 0));
verifyTrue(testCase, all(examples.pre_iteration_independent_run_count == 0));
verifyTrue(testCase, all(examples.pre_iteration_independent_condition_count == 0));
verifyEqual(testCase, numel(unique(examples.campaign_run_id)), 1);
verifyEqual(testCase, numel(unique(examples.campaign_condition_id)), 1);
verifyGreaterThanOrEqual(testCase, ...
    min(examples.distance_to_nearest_selected_center_window_fraction(2:end)), ...
    0.75);

summary = dataset.sample_summaries;
verifyEqual(testCase, summary.selected_center_count, height(examples));
verifyEqual(testCase, summary.analytic_target_example_count, 1);
verifyEqual(testCase, summary.opportunistic_example_count, height(examples)-1);

end


function fixture = make_fixture(testCase)

root = string(testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
sample_file = fullfile(root, "wavefield_sample.mat");
placeholder = true; %#ok<NASGU>
save(sample_file, "placeholder");

run = table(1, "run_hybrid_001", "swsynth", "hash_hybrid_001", ...
    "completed", "completed_valid", "hybrid_fixture", 71001, 500, 2, ...
    8, 1, root, "", sample_file, "", "", "condition_hybrid_001", ...
    0.5, "bilayer", VariableNames=[ ...
    "ordinal","run_id","backend","hash_sha256","status", ...
    "outcome_status","scenario","seed","frequency_hz", ...
    "background_cs_m_s","direction_count","valid","run_directory", ...
    "resolved_config_path","wavefield_sample_path","summary_path", ...
    "validation_report_path","condition_id","solid_angle_sr", ...
    "geometry_family"]);
fixture.campaign_csv = fullfile(root, "campaign_runs.csv");
writetable(run, fixture.campaign_csv);

edges = coverage_edges();
dnom = reqml.coverage.computeNominalAngularCoverage(8, 0.5, ...
    MaximumDirectionCount=128);
dnom_bin = discretize(dnom, edges.dnom);
purity = 21 / 25;
requested = struct( ...
    "sws_bin",1, ...
    "frequency_bin",4, ...
    "purity_bin",2, ...
    "diffusivity_bin",dnom_bin, ...
    "discretization_bin",1, ...
    "requested_cell_key", ...
        compose("s%02d_f%02d_p%02d_d%02d_g%02d", ...
            1,4,2,dnom_bin,1));
control = struct( ...
    "geometry_control_mode", "analytic_bilayer", ...
    "selected_patch_center_indices_xz", [23 31], ...
    "patch_size_pixels", [25 25], ...
    "grid_spacing_m", [0.0005 0.0005], ...
    "predicted_discrete_purity", purity, ...
    "interface_orientation", "x", ...
    "interface_position_m", 0.015);
condition = struct("condition_id","condition_hybrid_001", ...
    "seed",71001,"requested_coverage",requested, ...
    "geometry_control",control);
plan = struct("physical_conditions",condition);
fixture.plan_file = fullfile(root, "adaptive_batch_plan.json");
write_text(fixture.plan_file, jsonencode(plan, PrettyPrint=true));

end


function edges = coverage_edges()

edges = struct("purity",[0.5 0.7 0.9 0.98 1], ...
    "dnom",[0 0.01 0.05 0.2 0.5 1], ...
    "sws",[1.5 2 2.5 3 3.5 4], ...
    "frequency",[199 250 350 450 550 601]);

end


function state = empty_deficit_state(edges)

observed = table( ...
    zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
    zeros(0,1),zeros(0,1),zeros(0,1),VariableNames=[ ...
    "sws_bin","frequency_bin","purity_bin","diffusivity_bin", ...
    "discretization_bin","example_count", ...
    "independent_run_count","independent_condition_count"]);

summary = reqml.coverage.completeCoverageGrid( ...
    observed,edges.sws,edges.frequency,edges.purity,edges.dnom, ...
    [0.0005 0.0005]);
state = reqml.coverage.findCoverageDeficits(summary, MinimumExamples=4, ...
    MinimumIndependentRuns=2, MinimumIndependentConditions=1, ...
    IncludeComplete=true);

end


function data = hybrid_loader(~)

n = 61;
data = struct();
data.wavefield_zx = complex(ones(n), 0.1);
data.dx_m = 0.0005;
data.dz_m = 0.0005;
data.frequency_hz = 500;
data.background_cs_m_s = 2;
data.axes = struct("x_m",(0:n-1)'*data.dx_m, ...
    "z_m",(0:n-1)'*data.dz_m);
material = ones(n,n,"uint16");
material(:,32:end) = 2;
sws = 1.75 * ones(n);
sws(:,32:end) = 2.75;
data.truth = struct("cs_m_s_zx",sws,"material_id_zx",material, ...
    "valid_mask_zx",true(n));

end


function report = hybrid_readiness(~, varargin) %#ok<INUSD>

report = struct("valid",true,"summary","ready", ...
    "window_points_x",25,"window_points_z",25, ...
    "placements_x",17,"placements_z",17);

end


function extraction = hybrid_extractor(data, ~, options)

arguments
    data (1,1) struct
    ~
    options.DatasetId (1,1) string
    options.SampleId (1,1) string
    options.StepX (1,1) double = NaN
    options.StepZ (1,1) double = NaN
    options.StoreReqCurves (1,1) logical = false
    options.UseWindowParfor (1,1) logical = false
    options.CenterIndices (:,2) double = zeros(0,2)
end

centers = options.CenterIndices;
n = size(centers,1);
purity = zeros(n,1);
for index = 1:n
    x = centers(index,1); z = centers(index,2);
    ids = data.truth.material_id_zx(z-12:z+12,x-12:x+12);
    purity(index) = reqml.datasets.computeMaterialPatchPurity(ids,true(25));
end
examples = table();
examples.dataset_id = repmat(options.DatasetId,n,1);
examples.sample_id = repmat(options.SampleId,n,1);
examples.example_id = compose(options.SampleId + "__z%05d_x%05d", ...
    centers(:,2), centers(:,1));
examples.cx = centers(:,1);
examples.cz = centers(:,2);
examples.material_patch_purity = purity;
examples.q_target_from_center_truth = ones(n,1);
examples.target_valid = true(n,1);
examples.target_definition = repmat("center_pixel_truth",n,1);
extraction = struct("examples",examples,"sample_summary",struct( ...
    "example_count",n,"valid_example_count",n, ...
    "minimum_material_purity",min(purity), ...
    "median_material_purity",median(purity)));

end


function write_text(path_value, value)

file_id = fopen(path_value,"w");
cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id,"%s",value);
clear cleanup

end
