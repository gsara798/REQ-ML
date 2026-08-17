function report = run_analytic_point_force_q0_v1(options)
%RUN_ANALYTICPOINTFORCEQ0V1 Run the fixed eight-case Frozen-Q0 diagnostic.

arguments
    options.ConfigFile {mustBeTextScalar} = ""
    options.OutputDirectory {mustBeTextScalar} = ""
    options.Model {mustBeTextScalar} = ""
    options.RunSimulations (1,1) logical = true
    options.RunInference (1,1) logical = true
    options.MakePlots (1,1) logical = true
    options.SmokeOnly (1,1) logical = false
    options.UseParallel (1,1) logical = false
end

repositoryRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(fullfile(repositoryRoot,"src"));
configFile = string(options.ConfigFile);
if strlength(configFile) == 0
    configFile = fullfile(repositoryRoot,"configs","validation", ...
        "reqml_analytic_point_force_q0_v1.json");
end
config = jsondecode(fileread(configFile));

frameworkRoot = string(config.simulation_framework_root);
frameworkCommit = reqml.analysis.verifyRequiredGitCommit(frameworkRoot, ...
    config.required_simulation_framework_commit);
frameworkSrc = fullfile(frameworkRoot,"src");
if ~isfolder(frameworkSrc)
    error("reqml:SimulationFrameworkSourceNotFound", ...
        "Simulation framework source was not found: %s",frameworkSrc);
end

modelFile = resolvePath(config.model_file,repositoryRoot);
if strlength(string(options.Model)) > 0
    modelFile = string(options.Model);
end
if ~isfile(modelFile)
    error("reqml:Q0ModelNotFound", ...
        "Frozen current Q0 model was not found: %s",modelFile);
end
modelProvenance = verifyFrozenModelProvenance(modelFile, ...
    config.expected_model_provenance);
[resolvedModel,modelResolution] = reqml.models.resolveCurrentQ0Model( ...
    Model=modelFile,RepositoryRoot=repositoryRoot);

outputDirectory = resolvePath(config.output_directory,repositoryRoot);
if strlength(string(options.OutputDirectory)) > 0
    outputDirectory = string(options.OutputDirectory);
end
paths = outputPaths(outputDirectory);
ensureDirectories(paths);
simulationOutput = fullfile(outputDirectory,"simulations");
[campaign,design] = reqml.analysis.buildAnalyticPointForceCampaign( ...
    config,simulationOutput);
writetable(design,paths.designCsv);
writeJson(paths.designJson,table2struct(design));
writeJson(paths.campaignFile,campaign);

fprintf("\nAnalytic point-force Frozen-Q0 design (%d runs):\n",height(design));
disp(design(:,["design_id","cs_true_m_s","force_label", ...
    "geometric_decay_exponent","seed","expected_source_x_m", ...
    "expected_source_z_m"]));

pathWasAdded = ~containsPath(frameworkSrc);
if pathWasAdded
    addpath(frameworkSrc); rehash;
end
cleanupPath = onCleanup(@() restorePath(frameworkSrc,pathWasAdded));
[expandedRuns,validation] = simcampaigns.validateCampaign(paths.campaignFile);
if ~validation.valid || numel(expandedRuns) ~= 8
    error("reqml:AnalyticPointForceCampaignInvalid", ...
        "Campaign validation failed or did not resolve exactly eight runs.");
end
validateResolvedDesign(expandedRuns,design,config);
fprintf("Resolved SOURCE-Z example: %s\n",design.design_id(1));
fprintf("Resolved matched SOURCE-X example: %s\n",design.design_id(3));

reqmlCommit = gitCommit(repositoryRoot);
smokeIndices = find(design.cs_true_m_s==2 & ...
    design.geometric_decay_exponent==0);
smokeDesign = design(smokeIndices,:);
if options.RunSimulations
    smokeCampaign = campaign;
    smokeCampaign.runs = campaign.runs(smokeIndices);
    writeJson(paths.campaignFile,smokeCampaign);
    reqml.campaigns.executeAdaptiveBatch(paths.batchDirectory, ...
        frameworkRoot,Resume=true,ContinueOnError=false);
end

smokeCsv = campaignCsvPath(simulationOutput,config.diagnostic_id);
if ~isfile(smokeCsv)
    error("reqml:AnalyticPointForceCampaignCsvNotFound", ...
        "Smoke campaign CSV was not found: %s",smokeCsv);
end
smokePhysics = verifyPhysicalSmokes(smokeDesign,smokeCsv,paths);

if options.RunInference
    for index = 1:height(smokeDesign)
        processCase(smokeDesign.design_id(index),design,smokeCsv,paths, ...
            config,resolvedModel,modelResolution,frameworkCommit, ...
            reqmlCommit,options.UseParallel,true);
    end
end
if options.MakePlots
    for index = 1:height(smokeDesign)
        makePerCaseFigure(smokeDesign.design_id(index),paths);
    end
end
verifySmokeInference(smokeDesign,paths);
fprintf("Physical and Frozen-Q0 smokes passed for SOURCE-Z and SOURCE-X.\n");

if options.SmokeOnly
    report = struct("output_directory",paths.root,"smoke_only",true, ...
        "smoke_physics",smokePhysics,"framework_commit",frameworkCommit, ...
        "reqml_commit",reqmlCommit);
    clear cleanupPath
    return
end

writeJson(paths.campaignFile,campaign);
if options.RunSimulations
    reqml.campaigns.executeAdaptiveBatch(paths.batchDirectory, ...
        frameworkRoot,Resume=true,ContinueOnError=false);
end
campaignCsv = campaignCsvPath(simulationOutput,config.diagnostic_id);
if ~isfile(campaignCsv)
    error("reqml:AnalyticPointForceCampaignCsvNotFound", ...
        "Complete campaign CSV was not found: %s",campaignCsv);
end

if options.RunInference
    for index = 1:height(design)
        processCase(design.design_id(index),design,campaignCsv,paths,config, ...
            resolvedModel,modelResolution,frameworkCommit,reqmlCommit, ...
            options.UseParallel,false);
    end
end

caseData = loadCaseResults(design,paths);
summary = buildSummary(caseData,design,config,frameworkCommit);
nodeSummary = buildNodeSummary(caseData,design);
spectralSummary = buildSpectralSummary(caseData,design);
writetable(summary,paths.summaryCsv);
writetable(nodeSummary,paths.nodeSummaryCsv);
if options.MakePlots
    makeAllFigures(caseData,design,paths,config);
end
writeReadme(paths.readme,summary,nodeSummary,smokePhysics,spectralSummary);
writeManifest(paths.manifest,configFile,config,paths,frameworkRoot, ...
    frameworkCommit,reqmlCommit,resolvedModel,modelResolution,summary);

report = struct("output_directory",paths.root,"summary_csv",paths.summaryCsv, ...
    "node_distance_summary_csv",paths.nodeSummaryCsv, ...
    "figures_directory",paths.figuresDirectory, ...
    "framework_commit",frameworkCommit,"reqml_commit",reqmlCommit, ...
    "model_file",string(resolvedModel),"smoke_only",false, ...
    "model_provenance",modelProvenance, ...
    "case_count",height(summary));
fprintf("\nDiagnostic complete: %s\n",paths.summaryCsv);
disp(summary(:,["design_id","MAPE_percent","bias_percent", ...
    "median_predicted_cs_m_s","invalid_fraction"]));
clear cleanupPath
end

function processCase(designId,design,campaignCsv,paths,config,modelFile, ...
        modelResolution,frameworkCommit,reqmlCommit,useParallel,force)
caseDirectory = fullfile(paths.casesDirectory,designId);
resultFile = fullfile(caseDirectory,"result.mat");
if isfile(resultFile) && ~force
    return
end
if ~isfolder(caseDirectory), mkdir(caseDirectory); end
runs = readtable(campaignCsv,TextType="string");
runIndex = find(runs.design_id==designId,1);
if isempty(runIndex) || ~isfile(runs.wavefield_sample_path(runIndex))
    error("reqml:AnalyticPointForceSampleNotFound", ...
        "Completed wavefield sample was not found for %s.",designId);
end
sampleFile = runs.wavefield_sample_path(runIndex);
prediction = reqml.predictSWS(sampleFile,Model=modelFile,M=config.M, ...
    StepPixels=config.step_pixels,UseParallel=useParallel);
data = reqml.io.load_wavefield_sample(sampleFile);
row = design(design.design_id==designId,:);

cs_pred_map = prediction.cs_map;
q_map = prediction.q_map;
valid_mask = prediction.valid_mask & isfinite(cs_pred_map);
cs_truth_map = double(row.cs_true_m_s)*ones(size(cs_pred_map));
signed_error_percent = 100*(cs_pred_map-cs_truth_map)./cs_truth_map;
signed_error_percent(~valid_mask) = NaN;
absolute_error_percent = abs(signed_error_percent);
x_mm = prediction.x_mm;
z_mm = prediction.z_mm;
patch_predictions = prediction.patch_predictions;
patch_examples = prediction.patch_examples;
wavefield_zx = data.wavefield_zx;
wavefield_x_mm = 1e3*data.axes.x_m(:)';
wavefield_z_mm = 1e3*data.axes.z_m(:);
source_xyz_m = actualSourceXYZ(data);
expectedSource = [row.expected_source_x_m,row.expected_source_y_m, ...
    row.expected_source_z_m];
if norm(source_xyz_m-expectedSource) > 5e-7
    error("reqml:AnalyticPointForceSourceMismatch", ...
        "Resolved source for %s does not match the design.",designId);
end
force_direction_xyz = [row.force_x,row.force_y,row.force_z];
radiation_model = string(row.radiation_model);
geometric_decay_exponent = double(row.geometric_decay_exponent);

patchWidthPixels = double(prediction.metadata.patch_width_pixels);
Lwin_normal_m = (patchWidthPixels-1)*double(data.dz_m);
node_distance_m = double(patch_examples.z_center_m)-source_xyz_m(3);
normalized_node_distance = abs(node_distance_m)/Lwin_normal_m;
patch_center_magnitude = sampleAtPatchCenters(data,patch_examples);
metadata = struct();
metadata.design = table2struct(row);
metadata.sample_file = sampleFile;
metadata.resolved_config_path = runs.resolved_config_path(runIndex);
metadata.framework_commit = frameworkCommit;
metadata.reqml_commit = reqmlCommit;
metadata.model = prediction.metadata;
metadata.model_resolution = modelResolution.source;
metadata.simulation_provenance = data.provenance;
metadata.simulation_sources = data.sources;
metadata.Lwin_normal_m = Lwin_normal_m;
metadata.Lwin_normal_definition = ...
    "(patch_width_pixels - 1) * dz_m; normal to horizontal nodal line";
metadata.patch_complex_coherence = ...
    "omitted: exact inference-window samples are not exposed by public API";

save(resultFile,"cs_pred_map","q_map","valid_mask","cs_truth_map", ...
    "signed_error_percent","absolute_error_percent","x_mm","z_mm", ...
    "patch_predictions","patch_examples","wavefield_zx", ...
    "wavefield_x_mm","wavefield_z_mm","source_xyz_m", ...
    "force_direction_xyz","radiation_model", ...
    "geometric_decay_exponent","node_distance_m", ...
    "normalized_node_distance","patch_center_magnitude","metadata","-v7.3");
end

function smoke = verifyPhysicalSmokes(smokeDesign,campaignCsv,paths)
runs = readtable(campaignCsv,TextType="string");
smoke = struct();
for label = ["sourcez","sourcex"]
    row = smokeDesign(smokeDesign.force_label==label,:);
    runIndex = find(runs.design_id==row.design_id,1);
    data = reqml.io.load_wavefield_sample(runs.wavefield_sample_path(runIndex));
    source = actualSourceXYZ(data);
    expected = [row.expected_source_x_m,row.expected_source_y_m, ...
        row.expected_source_z_m];
    if norm(source-expected) > 5e-7
        error("reqml:AnalyticPointForceSmokeSourceMismatch", ...
            "Smoke source coordinates do not match %s.",row.design_id);
    end
    U = data.wavefield_zx;
    z = double(data.axes.z_m(:));
    [~,nodeIndex] = min(abs(z-source(3)));
    offset = max(1,round(0.004/double(data.dz_m)));
    lowIndex = nodeIndex-offset;
    highIndex = nodeIndex+offset;
    tolerance = 1e-8*max(abs(U),[],"all");
    usable = abs(U(lowIndex,:))>tolerance & abs(U(highIndex,:))>tolerance;
    ratios = U(lowIndex,usable)./U(highIndex,usable);
    phaseDifference = abs(angle(median(ratios)));
    nodeRatio = max(abs(U(nodeIndex,:)))/max(abs(U),[],"all");
    if label == "sourcex"
        if nodeRatio > 1e-6 || abs(phaseDifference-pi) > 1e-4
            error("reqml:AnalyticPointForceSourceXSmokeFailed", ...
                "SOURCE-X did not exhibit the expected node and pi reversal.");
        end
    elseif phaseDifference > 1e-4
        error("reqml:AnalyticPointForceSourceZSmokeFailed", ...
            "SOURCE-Z did not exhibit the expected mirror symmetry.");
    end
    smoke.(label) = struct("design_id",row.design_id, ...
        "source_xyz_m",source,"node_z_m",z(nodeIndex), ...
        "node_amplitude_ratio",nodeRatio, ...
        "mirrored_phase_difference_rad",phaseDifference, ...
        "phase_mask_relative_tolerance",1e-8);
end
writeJson(paths.physicsSmokeJson,smoke);
end

function validateResolvedDesign(runs,design,config)
if numel(runs)~=8 || height(design)~=8
    error("reqml:AnalyticPointForceDesignCount","Expected exactly 8 runs.");
end
for index = 1:8
    cfg = runs(index).config; row = design(index,:);
    assert(string(cfg.propagation.model)=="spherical_wave");
    assert(string(cfg.propagation.phase_model)=="local_k_distance");
    assert(string(cfg.sources.radiation.model)== ...
        "point_force_shear_far_field");
    assert(norm(double(cfg.sources.radiation.force_direction_xyz(:)')- ...
        [row.force_x,row.force_y,row.force_z])<1e-12);
    assert(cfg.amplitude.geometric_decay_exponent== ...
        row.geometric_decay_exponent);
    assert(all(abs(double(cfg.sources.radius_range_m)-.05)<eps));
    assert(cfg.seed==row.seed);
    assert(cfg.medium.background_cs_m_s==row.cs_true_m_s);
    assert(cfg.wavefield.frequency_hz==400);
    assert(cfg.sources.amplitude_jitter_fraction==0);
    assert(cfg.noise.snr_db==1000);
end
assert(config.M==2 && config.step_pixels==1);
end

function verifySmokeInference(smokeDesign,paths)
for index = 1:height(smokeDesign)
    file = fullfile(paths.casesDirectory,smokeDesign.design_id(index), ...
        "result.mat");
    if ~isfile(file)
        error("reqml:AnalyticPointForceQ0SmokeFailed", ...
            "Smoke inference result is missing: %s",file);
    end
    value = load(file,"valid_mask");
    if ~any(value.valid_mask,"all")
        error("reqml:AnalyticPointForceQ0SmokeFailed", ...
            "Smoke inference has no valid Q0 predictions.");
    end
end
end

function summary = buildSummary(caseData,design,config,frameworkCommit)
rows = cell(height(design),1);
for index = 1:height(design)
    value = caseData(index); predictions = value.patch_predictions;
    valid = logical(predictions.sws_valid) & ...
        isfinite(predictions.cs_pred_m_s);
    predicted = double(predictions.cs_pred_m_s(valid));
    truth = double(design.cs_true_m_s(index));
    errorPercent = 100*(predicted-truth)/truth;
    rows{index} = struct("design_id",design.design_id(index), ...
        "cs_true_m_s",truth,"frequency_hz",double(config.frequency_hz), ...
        "force_label",design.force_label(index), ...
        "force_x",design.force_x(index),"force_y",design.force_y(index), ...
        "force_z",design.force_z(index), ...
        "radiation_model",design.radiation_model(index), ...
        "geometric_decay_exponent",design.geometric_decay_exponent(index), ...
        "source_x_m",value.source_xyz_m(1), ...
        "source_y_m",value.source_xyz_m(2), ...
        "source_z_m",value.source_xyz_m(3), ...
        "patch_count",height(predictions),"valid_patch_count",nnz(valid), ...
        "invalid_fraction",1-nnz(valid)/height(predictions), ...
        "mean_predicted_cs_m_s",mean(predicted), ...
        "median_predicted_cs_m_s",median(predicted), ...
        "RMSE_m_s",sqrt(mean((predicted-truth).^2)), ...
        "MAPE_percent",mean(abs(errorPercent)), ...
        "bias_percent",mean(errorPercent), ...
        "median_absolute_error_percent",median(abs(errorPercent)), ...
        "p90_absolute_error_percent",prctile(abs(errorPercent),90), ...
        "framework_commit",frameworkCommit, ...
        "reqml_commit",string(value.metadata.reqml_commit), ...
        "model_provenance_id", ...
            string(value.metadata.model.model_provenance_id));
end
summary = struct2table(vertcat(rows{:}));
end

function output = buildNodeSummary(caseData,design)
edges = [0 .5 1 2 Inf]; labels = ["<0.5","0.5-1","1-2",">2"];
rows = cell(height(design)*4,1); ordinal = 0;
for caseIndex = 1:height(design)
    value = caseData(caseIndex); predictions = value.patch_predictions;
    truth = double(design.cs_true_m_s(caseIndex));
    for bandIndex = 1:4
        ordinal = ordinal+1;
        selected = value.normalized_node_distance>=edges(bandIndex) & ...
            value.normalized_node_distance<edges(bandIndex+1);
        valid = selected & logical(predictions.sws_valid) & ...
            isfinite(predictions.cs_pred_m_s);
        predicted = double(predictions.cs_pred_m_s(valid));
        errors = 100*(predicted-truth)/truth;
        rows{ordinal} = struct("design_id",design.design_id(caseIndex), ...
            "normalized_node_distance_band",labels(bandIndex), ...
            "patch_count",nnz(selected),"valid_patch_count",nnz(valid), ...
            "invalid_fraction",safeFraction(nnz(selected)-nnz(valid),nnz(selected)), ...
            "median_predicted_cs_m_s",safeMedian(predicted), ...
            "median_q",safeMedian(double(predictions.q_pred(valid))), ...
            "MAPE_percent",safeMean(abs(errors)), ...
            "bias_percent",safeMean(errors), ...
            "median_absolute_error_percent",safeMedian(abs(errors)));
    end
end
output = struct2table(vertcat(rows{:}));
end

function output = buildSpectralSummary(caseData,design)
rows=cell(4,1); ordinal=0;
for cs=[2 3]
    for decay=[0 1]
        ordinal=ordinal+1; selected=design.cs_true_m_s==cs & ...
            design.geometric_decay_exponent==decay;
        group=caseData(selected); groupDesign=design(selected,:);
        [group,~]=orderForceGroup(group,groupDesign);
        rows{ordinal}=struct("cs_true_m_s",cs, ...
            "geometric_decay_exponent",decay, ...
            "near_node_radial_L1",spectralL1(group,0), ...
            "mid_radial_L1",spectralL1(group,.75), ...
            "maximum_normalized_node_distance", ...
                max(group(2).normalized_node_distance));
    end
end
output=struct2table(vertcat(rows{:}));
end

function value=spectralL1(group,target)
sourceX=group(2); valid=find(sourceX.patch_predictions.sws_valid & ...
    isfinite(sourceX.normalized_node_distance));
[~,which]=min(abs(sourceX.normalized_node_distance(valid)-target));
indexX=valid(which); centerX=sourceX.patch_examples.x_center_m(indexX);
centerZ=sourceX.patch_examples.z_center_m(indexX);
indexZ=nearestPatch(group(1),centerX,centerZ);
[~,pZ]=radialIncrement(group(1).patch_examples.req_mapping{indexZ});
[~,pX]=radialIncrement(group(2).patch_examples.req_mapping{indexX});
count=min(numel(pZ),numel(pX)); value=sum(abs(pZ(1:count)-pX(1:count)));
end

function makeAllFigures(caseData,design,paths,config)
for index = 1:height(design)
    makePerCaseFigure(design.design_id(index),paths);
end
for cs = [2 3]
    for decay = [0 1]
        selected = design.cs_true_m_s==cs & ...
            design.geometric_decay_exponent==decay;
        group = caseData(selected); groupDesign = design(selected,:);
        tag = "cs"+compose("%g",cs)+"_"+spreadTag(decay);
        makeMatchedFigure(group,groupDesign, ...
            fullfile(paths.figuresDirectory,tag+"_sourcez_vs_sourcex.png"));
        makeProfilesFigure(group,groupDesign, ...
            fullfile(paths.figuresDirectory,tag+"_node_profiles.png"));
        makeNormalizedDistanceFigure(group,groupDesign, ...
            fullfile(paths.figuresDirectory,tag+"_normalized_node_error.png"));
        makeSpectralFigure(group,groupDesign,config, ...
            fullfile(paths.figuresDirectory,tag+"_local_spectra.png"));
    end
end
end

function makePerCaseFigure(designId,paths)
s = load(fullfile(paths.casesDirectory,designId,"result.mat"));
phase = angle(s.wavefield_zx);
phase(abs(s.wavefield_zx)<1e-8*max(abs(s.wavefield_zx),[],"all")) = NaN;
f = figure(Visible="off",Color="w",Position=[50 50 1700 950]);
cleanup = onCleanup(@() close(f)); tiledlayout(2,3,Padding="compact");
plotMap(s.wavefield_x_mm,s.wavefield_z_mm,abs(s.wavefield_zx),"|U_z|");
plotMap(s.wavefield_x_mm,s.wavefield_z_mm,real(s.wavefield_zx),"real(U_z)");
plotMap(s.wavefield_x_mm,s.wavefield_z_mm,phase,"phase(U_z)",[-pi pi]);
plotMap(s.x_mm,s.z_mm,s.cs_pred_map,"Frozen Q0 SWS (m/s)",[1 4]);
plotMap(s.x_mm,s.z_mm,s.q_map,"predicted q",[0 1]);
limit = max(5,prctile(abs(s.signed_error_percent(:)),99));
plotMap(s.x_mm,s.z_mm,s.signed_error_percent,"signed error (%)",[-limit limit]);
axesHandles = findobj(f,Type="axes");
for axisHandle = axesHandles(:)'
    yline(axisHandle,1e3*s.source_xyz_m(3),"w--",LineWidth=1.2);
end
sgtitle(strrep(designId,"_"," "));
exportgraphics(f,fullfile(paths.figuresDirectory, ...
    designId+"_diagnostic.png"),Resolution=180); clear cleanup
end

function makeMatchedFigure(group,groupDesign,file)
[group,groupDesign] = orderForceGroup(group,groupDesign);
truth = groupDesign.cs_true_m_s(1); errorLimit = 5;
for index=1:2
    errorLimit=max(errorLimit,prctile(abs(group(index).signed_error_percent(:)),99));
end
f=figure(Visible="off",Color="w",Position=[50 50 1200 1500]);
cleanup=onCleanup(@() close(f)); tiledlayout(4,2,Padding="compact");
for index=1:2
    plotMap(group(index).wavefield_x_mm,group(index).wavefield_z_mm, ...
        abs(group(index).wavefield_zx),groupDesign.force_label(index)+" |U_z|");
end
for index=1:2
    phase=angle(group(index).wavefield_zx);
    phase(abs(group(index).wavefield_zx)<1e-8*max(abs(group(index).wavefield_zx),[],"all"))=NaN;
    plotMap(group(index).wavefield_x_mm,group(index).wavefield_z_mm,phase, ...
        groupDesign.force_label(index)+" phase",[-pi pi]);
end
for index=1:2
    plotMap(group(index).x_mm,group(index).z_mm,group(index).cs_pred_map, ...
        groupDesign.force_label(index)+" SWS",[1 4]);
end
for index=1:2
    plotMap(group(index).x_mm,group(index).z_mm, ...
        group(index).signed_error_percent,groupDesign.force_label(index)+ ...
        " signed error",[-errorLimit errorLimit]);
end
for axisHandle=findobj(f,Type="axes")'
    yline(axisHandle,1e3*group(1).source_xyz_m(3),"w--",LineWidth=1.1);
end
sgtitle(sprintf("cs=%.1f m/s; %s",truth,spreadLabel( ...
    groupDesign.geometric_decay_exponent(1))));
exportgraphics(f,file,Resolution=180); clear cleanup
end

function makeProfilesFigure(group,groupDesign,file)
[group,groupDesign]=orderForceGroup(group,groupDesign);
colors=[.1 .35 .75;.85 .2 .1]; labels=["|U_z|","q","SWS (m/s)", ...
    "signed error (%)","absolute error (%)"];
allDistance=vertcat(group.node_distance_m); edges=linspace(min(allDistance), ...
    max(allDistance),13);
f=figure(Visible="off",Color="w",Position=[50 50 1700 700]);
cleanup=onCleanup(@() close(f)); tiledlayout(2,3,Padding="compact");
for panel=1:5
    nexttile; hold on;
    for index=1:2
        values=profileValues(group(index),panel,groupDesign.cs_true_m_s(index));
        [centers,med,q1,q3]=binnedSummary(group(index).node_distance_m,values,edges);
        fill([centers;flipud(centers)]*1e3,[q1;flipud(q3)],colors(index,:), ...
            FaceAlpha=.12,EdgeColor="none",HandleVisibility="off");
        plot(centers*1e3,med,LineWidth=2,Color=colors(index,:));
    end
    xline(0,"k--"); grid on; xlabel("z-z_{source} (mm)"); ylabel(labels(panel));
    if panel==1, legend("SOURCE-Z","SOURCE-X",Location="best"); end
end
sgtitle(sprintf("Node profiles: cs=%.1f; %s",groupDesign.cs_true_m_s(1), ...
    spreadLabel(groupDesign.geometric_decay_exponent(1))));
exportgraphics(f,file,Resolution=180); clear cleanup
end

function makeNormalizedDistanceFigure(group,groupDesign,file)
[group,groupDesign]=orderForceGroup(group,groupDesign); edges=[0 .5 1 2 4 8 Inf];
colors=[.1 .35 .75;.85 .2 .1];
f=figure(Visible="off",Color="w",Position=[50 50 1100 480]);
cleanup=onCleanup(@() close(f)); tiledlayout(1,2,Padding="compact");
for panel=1:2
    nexttile; hold on;
    for index=1:2
        truth=groupDesign.cs_true_m_s(index);
        errors=100*(double(group(index).patch_predictions.cs_pred_m_s)-truth)/truth;
        if panel==2, errors=abs(errors); end
        [centers,med,q1,q3]=binnedSummary(group(index).normalized_node_distance,errors,edges);
        fill([centers;flipud(centers)],[q1;flipud(q3)],colors(index,:), ...
            FaceAlpha=.12,EdgeColor="none",HandleVisibility="off");
        plot(centers,med,LineWidth=2,Color=colors(index,:));
    end
    xline(.5,"k--"); grid on; xlabel("|d_{node}|/L_{win,normal}");
    if panel==1, ylabel("signed error (%)"); else, ylabel("absolute error (%)"); end
end
legend("SOURCE-Z","SOURCE-X",Location="best");
sgtitle(sprintf("Normalized node distance: cs=%.1f; %s", ...
    groupDesign.cs_true_m_s(1),spreadLabel(groupDesign.geometric_decay_exponent(1))));
exportgraphics(f,file,Resolution=180); clear cleanup
end

function makeSpectralFigure(group,groupDesign,config,file)
[group,groupDesign]=orderForceGroup(group,groupDesign);
sourceX=group(2); valid=find(sourceX.patch_predictions.sws_valid & ...
    isfinite(sourceX.normalized_node_distance));
ranges={[0 .2],[.5 1],[2 Inf]}; labels=["near node","0.5-1 Lwin",">2 Lwin"];
colors=[.1 .35 .75;.85 .2 .1];
f=figure(Visible="off",Color="w",Position=[50 50 1300 1150]);
cleanup=onCleanup(@() close(f)); tiledlayout(3,2,Padding="compact");
for region=1:3
    candidates=valid(sourceX.normalized_node_distance(valid)>=ranges{region}(1) & ...
        sourceX.normalized_node_distance(valid)<ranges{region}(2));
    if isempty(candidates)
        for panel=1:2
            nexttile; axis off;
            text(.5,.5,labels(region)+": no supported patches", ...
                HorizontalAlignment="center",FontWeight="bold");
        end
        continue
    end
    [~,which]=min(abs(sourceX.normalized_node_distance(candidates)- ...
        meanFinite(ranges{region}))); indexX=candidates(which);
    centerX=sourceX.patch_examples.x_center_m(indexX);
    centerZ=sourceX.patch_examples.z_center_m(indexX);
    nexttile; hold on;
    for forceIndex=1:2
        patchIndex=nearestPatch(group(forceIndex),centerX,centerZ);
        mapping=group(forceIndex).patch_examples.req_mapping{patchIndex};
        [k,p]=radialIncrement(mapping); plot(k,p,LineWidth=2,Color=colors(forceIndex,:));
        xline(group(forceIndex).patch_predictions.k_pred_rad_m(patchIndex), ...
            ":",Color=colors(forceIndex,:),HandleVisibility="off");
    end
    trueK=2*pi*double(config.frequency_hz)/groupDesign.cs_true_m_s(1);
    xline(trueK,"k--","true k"); grid on; xlim([0 2.2*trueK]);
    ylabel("normalized P(k)");
    title(labels(region)); if region==1,legend("SOURCE-Z","SOURCE-X","true k");end
    nexttile; hold on;
    for forceIndex=1:2
        patchIndex=nearestPatch(group(forceIndex),centerX,centerZ);
        mapping=group(forceIndex).patch_examples.req_mapping{patchIndex};
        plot(double(mapping.k_cent),double(mapping.Ecum),LineWidth=2, ...
            Color=colors(forceIndex,:));
        yline(group(forceIndex).patch_predictions.q_pred(patchIndex), ...
            ":",Color=colors(forceIndex,:),HandleVisibility="off");
    end
    xline(trueK,"k--"); grid on; ylim([0 1]); xlim([0 2.2*trueK]);
    ylabel("E_{cum}(k)");
end
sgtitle(sprintf("Local radial spectra: cs=%.1f; %s", ...
    groupDesign.cs_true_m_s(1),spreadLabel(groupDesign.geometric_decay_exponent(1))));
exportgraphics(f,file,Resolution=180); clear cleanup
end

function plotMap(x,z,value,titleText,limits)
nexttile; imagesc(x,z,value); axis image; set(gca,YDir="normal"); colorbar;
title(titleText); xlabel("x (mm)"); ylabel("z (mm)");
if nargin>=5 && all(isfinite(limits)), clim(limits); end
end

function values=profileValues(value,panel,truth)
switch panel
    case 1, values=value.patch_center_magnitude;
    case 2, values=double(value.patch_predictions.q_pred);
    case 3, values=double(value.patch_predictions.cs_pred_m_s);
    case 4, values=100*(double(value.patch_predictions.cs_pred_m_s)-truth)/truth;
    case 5, values=abs(100*(double(value.patch_predictions.cs_pred_m_s)-truth)/truth);
end
end

function values=sampleAtPatchCenters(data,examples)
x=double(data.axes.x_m(:)); z=double(data.axes.z_m(:)); U=data.wavefield_zx;
values=nan(height(examples),1);
for index=1:height(examples)
    [~,ix]=min(abs(x-double(examples.x_center_m(index))));
    [~,iz]=min(abs(z-double(examples.z_center_m(index))));
    values(index)=abs(U(iz,ix));
end
end

function [group,groupDesign]=orderForceGroup(group,groupDesign)
order=[find(groupDesign.force_label=="sourcez",1), ...
    find(groupDesign.force_label=="sourcex",1)];
group=group(order); groupDesign=groupDesign(order,:);
end

function index=nearestPatch(value,x,z)
distance=(double(value.patch_examples.x_center_m)-double(x)).^2 + ...
    (double(value.patch_examples.z_center_m)-double(z)).^2;
[~,index]=min(distance);
end

function [k,p]=radialIncrement(mapping)
k=double(mapping.k_cent(:));
p=max(0,diff([0;double(mapping.Ecum(:))])); p=p/max(sum(p),eps);
end

function [centers,med,q1,q3]=binnedSummary(x,y,edges)
x=double(x(:)); y=double(y(:)); bins=discretize(x,edges);
finiteEdges=edges; if isinf(finiteEdges(end)), finiteEdges(end)=max(x(isfinite(x)))+eps; end
centers=(finiteEdges(1:end-1)+finiteEdges(2:end))'/2;
med=nan(size(centers)); q1=med; q3=med;
for index=1:numel(centers)
    values=y(bins==index & isfinite(y));
    if ~isempty(values)
        med(index)=median(values); q1(index)=prctile(values,25); q3(index)=prctile(values,75);
    end
end
end

function writeReadme(file,summary,nodeSummary,smoke,spectralSummary)
fid=fopen(file,"w");
if fid<0, error("reqml:DiagnosticSummaryWriteFailed","Cannot write %s",file); end
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,"Analytic point-force Frozen Q0 diagnostic\n\n");
fprintf(fid,"Measured diagnostic results; these are not causal proof.\n");
fprintf(fid,"SOURCE-X node amplitude ratio: %.3e; phase reversal: %.6f rad.\n", ...
    smoke.sourcex.node_amplitude_ratio,smoke.sourcex.mirrored_phase_difference_rad);
fprintf(fid,"SOURCE-Z mirrored phase difference: %.6f rad.\n\n", ...
    smoke.sourcez.mirrored_phase_difference_rad);
for cs=[2 3]
    for decay=[0 1]
        subset=summary(summary.cs_true_m_s==cs & ...
            summary.geometric_decay_exponent==decay,:);
        z=subset(subset.force_label=="sourcez",:); x=subset(subset.force_label=="sourcex",:);
        fprintf(fid,"cs %.1f, %s: SOURCE-X minus SOURCE-Z dMAPE=%+.4f pp, dBias=%+.4f pp, dMedianSWS=%+.5f m/s.\n", ...
            cs,spreadLabel(decay),x.MAPE_percent-z.MAPE_percent, ...
            x.bias_percent-z.bias_percent, ...
            x.median_predicted_cs_m_s-z.median_predicted_cs_m_s);
        near=nodeSummary(nodeSummary.design_id==x.design_id & ...
            nodeSummary.normalized_node_distance_band=="<0.5",:);
        far=nodeSummary(nodeSummary.design_id==x.design_id & ...
            nodeSummary.normalized_node_distance_band==">2",:);
        fprintf(fid,"  SOURCE-X near-node MAPE %.4f%%; far MAPE %.4f%%.\n", ...
            near.MAPE_percent,far.MAPE_percent);
        spectral=spectralSummary(spectralSummary.cs_true_m_s==cs & ...
            spectralSummary.geometric_decay_exponent==decay,:);
        fprintf(fid,"  Representative radial-spectrum L1 difference: near %.5f; 0.5-1 Lwin %.5f.\n", ...
            spectral.near_node_radial_L1,spectral.mid_radial_L1);
        fprintf(fid,"  Maximum supported normalized node distance: %.4f.\n", ...
            spectral.maximum_normalized_node_distance);
    end
end
fprintf(fid,"\nLwin_normal=(patch_width_pixels-1)*dz; node distance is |z-z_source|/Lwin_normal.\n");
fprintf(fid,"Patch complex coherence omitted because exact public inference-window samples are not exposed.\n");
fprintf(fid,"The >2 Lwin band and corresponding far spectral patch have no support in this fixed 50 mm domain; no values were extrapolated.\n");
fprintf(fid,"\nExcluded physics: finite aperture, full near-field elastodynamics, P waves, reflections, boundaries, material interfaces, and mode conversion.\n");
clear cleanup
end

function writeManifest(file,configFile,config,paths,frameworkRoot, ...
        frameworkCommit,reqmlCommit,modelFile,modelResolution,summary)
casePaths=arrayfun(@(id)fullfile(paths.casesDirectory,id,"result.mat"), ...
    summary.design_id,UniformOutput=false);
manifest=struct("schema_name","reqml_analytic_point_force_q0_results", ...
    "schema_version","1.0","created_utc",string(datetime("now",TimeZone="UTC")), ...
    "diagnostic_config_path",string(configFile), ...
    "generated_campaign_path",paths.campaignFile, ...
    "simulation_framework_repository",frameworkRoot, ...
    "required_framework_commit",string(config.required_simulation_framework_commit), ...
    "actual_framework_commit",frameworkCommit, ...
    "reporting_reqml_commit",reqmlCommit, ...
    "inference_reqml_commit",unique(summary.reqml_commit), ...
    "model_bundle_path",string(modelFile), ...
    "model_provenance",string(config.expected_model_provenance), ...
    "model_resolution",string(modelResolution.source), ...
    "matlab_version",string(version),"case_count",height(summary), ...
    "simulation_output_directory",fullfile(paths.root,"simulations"), ...
    "result_paths",{casePaths},"figure_directory",paths.figuresDirectory, ...
    "summary_csv",paths.summaryCsv, ...
    "node_distance_summary_csv",paths.nodeSummaryCsv, ...
    "simulation_or_training","8 clean swsynth simulations; frozen inference; no training");
writeJson(file,manifest);
end

function data=loadCaseResults(design,paths)
first=load(fullfile(paths.casesDirectory,design.design_id(1),"result.mat"));
data=repmat(first,height(design),1);
for index=2:height(design)
    file=fullfile(paths.casesDirectory,design.design_id(index),"result.mat");
    if ~isfile(file), error("reqml:DiagnosticResultMissing","Missing %s",file); end
    data(index)=orderfields(load(file),first);
end
end

function source=actualSourceXYZ(data)
required=["x_m","y_m","z_m","radius_m","radiation_model", ...
    "force_direction_xyz","observed_direction_xyz"];
if ~all(isfield(data.sources,cellstr(required)))
    error("reqml:MissingPointForceSourceMetadata", ...
        "Sample lacks point-force source metadata.");
end
source=[double(data.sources.x_m(1)),double(data.sources.y_m(1)), ...
    double(data.sources.z_m(1))];
end

function paths=outputPaths(root)
paths=struct("root",string(root));
paths.batchDirectory=fullfile(root,"batch");
paths.campaignFile=fullfile(paths.batchDirectory, ...
    "simulation_campaign_analytic_point_force_q0_v1.json");
paths.casesDirectory=fullfile(root,"cases");
paths.figuresDirectory=fullfile(root,"figures");
paths.designCsv=fullfile(root,"design.csv");
paths.designJson=fullfile(root,"design.json");
paths.physicsSmokeJson=fullfile(root,"physics_smoke.json");
paths.summaryCsv=fullfile(root,"summary.csv");
paths.nodeSummaryCsv=fullfile(root,"node_distance_summary.csv");
paths.readme=fullfile(root,"README.txt");
paths.manifest=fullfile(root,"manifest.json");
end

function ensureDirectories(paths)
for directory=[paths.root,paths.batchDirectory,paths.casesDirectory, ...
        paths.figuresDirectory]
    if ~isfolder(directory), mkdir(directory); end
end
end

function value=resolvePath(value,root)
value=replace(string(value),"${REPOSITORY_ROOT}",string(root));
end

function provenance=verifyFrozenModelProvenance(modelFile,expected)
manifestFile=fullfile(fileparts(modelFile),"training_manifest.json");
if ~isfile(manifestFile)
    error("reqml:Q0ModelProvenanceMissing", ...
        "Frozen Q0 training manifest was not found: %s",manifestFile);
end
manifest=jsondecode(fileread(manifestFile));
if ~isfield(manifest,"model_id")
    error("reqml:Q0ModelProvenanceMissing", ...
        "Frozen Q0 training manifest does not contain model_id.");
end
provenance=string(manifest.model_id);
if provenance~=string(expected)
    error("reqml:Q0ModelProvenanceMismatch", ...
        "Frozen Q0 provenance is %s; expected %s.",provenance,expected);
end
end

function pathValue=campaignCsvPath(simulationOutput,diagnosticId)
pathValue=fullfile(simulationOutput,string(diagnosticId),"campaign_runs.csv");
end

function commit=gitCommit(root)
[status,output]=system(sprintf('git -C "%s" rev-parse HEAD',root));
if status~=0, error("reqml:GitCommitUnavailable","Cannot resolve %s",root); end
commit=strtrim(string(output));
end

function writeJson(file,value)
fid=fopen(file,"w");
if fid<0, error("reqml:DiagnosticJsonWriteFailed","Cannot write %s",file); end
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,"%s",jsonencode(value,PrettyPrint=true)); clear cleanup
end

function tf=containsPath(value)
tf=any(string(strsplit(path,pathsep))==string(value));
end

function restorePath(value,wasAdded)
if wasAdded, rmpath(value); rehash; end
end

function value=spreadLabel(decay)
if decay==0, value="no spreading"; else, value="1/R spreading"; end
end

function value=spreadTag(decay)
if decay==0, value="nospread"; else, value="spread"; end
end

function value=safeFraction(numerator,denominator)
if denominator==0, value=NaN; else, value=numerator/denominator; end
end

function value=safeMean(values)
if isempty(values), value=NaN; else, value=mean(values); end
end

function value=safeMedian(values)
if isempty(values), value=NaN; else, value=median(values); end
end

function value=meanFinite(range)
if isinf(range(2)), value=2.5; else, value=mean(range); end
end
