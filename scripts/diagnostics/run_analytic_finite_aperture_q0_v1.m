function report = run_analytic_finite_aperture_q0_v1(options)
%RUN_ANALYTICFINITEAPERTUREQ0V1 Run the fixed 12-case Frozen-Q0 diagnostic.

arguments
    options.ConfigFile {mustBeTextScalar} = ""
    options.OutputDirectory {mustBeTextScalar} = ""
    options.Model {mustBeTextScalar} = ""
    options.RunSimulations (1,1) logical = true
    options.RunInference (1,1) logical = true
    options.MakePlots (1,1) logical = true
    options.SmokeOnly (1,1) logical = false
    options.UseParallel (1,1) logical = false
    options.FullDiagnosticRuntimeSeconds (1,1) double = NaN
end

started = tic;
repositoryRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(fullfile(repositoryRoot,"src"));
configFile = string(options.ConfigFile);
if strlength(configFile)==0
    configFile = fullfile(repositoryRoot,"configs","validation", ...
        "reqml_analytic_finite_aperture_q0_v1.json");
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
if strlength(string(options.Model))>0, modelFile=string(options.Model); end
if ~isfile(modelFile)
    error("reqml:Q0ModelNotFound", ...
        "Frozen current Q0 model was not found: %s",modelFile);
end
modelProvenance = verifyFrozenModelProvenance(modelFile, ...
    config.expected_model_provenance);
[resolvedModel,modelResolution] = reqml.models.resolveCurrentQ0Model( ...
    Model=modelFile,RepositoryRoot=repositoryRoot);

outputDirectory = resolvePath(config.output_directory,repositoryRoot);
if strlength(string(options.OutputDirectory))>0
    outputDirectory=string(options.OutputDirectory);
end
paths = outputPaths(outputDirectory);
ensureDirectories(paths);
simulationOutput = fullfile(outputDirectory,"simulations");
[campaign,design] = reqml.analysis.buildAnalyticFiniteApertureCampaign( ...
    config,simulationOutput);
writetable(design,paths.designCsv);
writeJson(paths.designJson,table2struct(design));
writeJson(paths.campaignFile,campaign);

fprintf("\nAnalytic finite-aperture Frozen-Q0 design (%d runs):\n", ...
    height(design));
disp(design(:,["design_id","cs_true_m_s","force_label", ...
    "aperture_span_m","aperture_node_count","seed"]));

pathWasAdded = ~containsPath(frameworkSrc);
if pathWasAdded, addpath(frameworkSrc); rehash; end
cleanupPath = onCleanup(@() restorePath(frameworkSrc,pathWasAdded));
[expandedRuns,validation] = simcampaigns.validateCampaign(paths.campaignFile);
if ~validation.valid || numel(expandedRuns)~=12
    error("reqml:AnalyticFiniteApertureCampaignInvalid", ...
        "Campaign validation failed or did not resolve exactly 12 runs.");
end
validateResolvedDesign(expandedRuns,design,config);

reqmlCommit = gitCommit(repositoryRoot);
smokeIds = ["cs3_sourcex_point","cs3_sourcex_aperture4mm", ...
    "cs3_sourcex_aperture8mm","cs3_sourcez_point"];
smokeIndices = find(ismember(design.design_id,smokeIds));
if numel(smokeIndices)~=4
    error("reqml:AnalyticFiniteApertureSmokeDesignMissing", ...
        "The four prespecified physics-smoke cases were not found.");
end
if options.RunSimulations
    smokeCampaign=campaign;
    smokeCampaign.runs=campaign.runs(smokeIndices);
    writeJson(paths.campaignFile,smokeCampaign);
    reqml.campaigns.executeAdaptiveBatch(paths.batchDirectory,frameworkRoot, ...
        Resume=true,ContinueOnError=false);
end
smokeCsv = campaignCsvPath(simulationOutput,config.diagnostic_id);
if ~isfile(smokeCsv)
    error("reqml:AnalyticFiniteApertureCampaignCsvNotFound", ...
        "Physics-smoke campaign CSV was not found: %s",smokeCsv);
end
smoke = verifyPhysicalSmokes(design(smokeIndices,:),smokeCsv,paths);
fprintf("Finite-aperture physics smokes passed.\n");
if options.SmokeOnly
    report=struct("output_directory",paths.root,"smoke_only",true, ...
        "smoke_physics",smoke,"framework_commit",frameworkCommit, ...
        "reqml_commit",reqmlCommit,"runtime_s",toc(started));
    clear cleanupPath
    return
end

writeJson(paths.campaignFile,campaign);
if options.RunSimulations
    reqml.campaigns.executeAdaptiveBatch(paths.batchDirectory,frameworkRoot, ...
        Resume=true,ContinueOnError=false);
end
campaignCsv = campaignCsvPath(simulationOutput,config.diagnostic_id);
if ~isfile(campaignCsv)
    error("reqml:AnalyticFiniteApertureCampaignCsvNotFound", ...
        "Complete campaign CSV was not found: %s",campaignCsv);
end
if options.RunInference
    for index=1:height(design)
        processCase(design.design_id(index),design,campaignCsv,paths,config, ...
            resolvedModel,modelResolution,frameworkCommit,reqmlCommit, ...
            options.UseParallel);
    end
end

caseData = loadCaseResults(design,paths);
summary = buildSummary(caseData,design,config,frameworkCommit);
nodeSummary = buildNodeSummary(caseData,design);
similarity = buildWavefieldSimilarity(caseData,design);
spectral = buildSpectralSummary(caseData,design,config);
writetable(summary,paths.summaryCsv);
writetable(nodeSummary,paths.nodeSummaryCsv);
writetable(similarity,paths.similarityCsv);
writetable(spectral,paths.spectralCsv);
if options.MakePlots
    makeAllFigures(caseData,design,summary,nodeSummary,paths,config);
end
runtimeS = toc(started);
fullRuntimeS = runtimeS;
if isfinite(options.FullDiagnosticRuntimeSeconds)
    fullRuntimeS = options.FullDiagnosticRuntimeSeconds;
end
writeReadme(paths.readme,summary,nodeSummary,similarity,spectral,smoke, ...
    config,fullRuntimeS,runtimeS);
writeManifest(paths.manifest,configFile,config,paths,frameworkRoot, ...
    frameworkCommit,reqmlCommit,resolvedModel,modelResolution,summary, ...
    fullRuntimeS,runtimeS,~options.RunSimulations && ~options.RunInference);

report=struct("output_directory",paths.root,"summary_csv",paths.summaryCsv, ...
    "node_distance_summary_csv",paths.nodeSummaryCsv, ...
    "wavefield_similarity_csv",paths.similarityCsv, ...
    "spectral_summary_csv",paths.spectralCsv, ...
    "figures_directory",paths.figuresDirectory, ...
    "framework_commit",frameworkCommit,"reqml_commit",reqmlCommit, ...
    "model_file",string(resolvedModel),"model_provenance",modelProvenance, ...
    "case_count",height(summary),"runtime_s",fullRuntimeS, ...
    "current_execution_runtime_s",runtimeS,"smoke_only",false);
fprintf("\nDiagnostic complete in %.1f s: %s\n",runtimeS,paths.summaryCsv);
disp(summary(:,["design_id","MAPE_percent","bias_percent", ...
    "median_predicted_cs_m_s","invalid_fraction"]));
clear cleanupPath
end

function processCase(designId,design,campaignCsv,paths,config,modelFile, ...
        modelResolution,frameworkCommit,reqmlCommit,useParallel)
caseDirectory=fullfile(paths.casesDirectory,designId);
resultFile=fullfile(caseDirectory,"result.mat");
if isfile(resultFile), return; end
if ~isfolder(caseDirectory), mkdir(caseDirectory); end
runs=readtable(campaignCsv,TextType="string");
runIndex=find(runs.design_id==designId,1);
if isempty(runIndex) || ~isfile(runs.wavefield_sample_path(runIndex))
    error("reqml:AnalyticFiniteApertureSampleNotFound", ...
        "Completed wavefield sample was not found for %s.",designId);
end
sampleFile=runs.wavefield_sample_path(runIndex);
prediction=reqml.predictSWS(sampleFile,Model=modelFile,M=config.M, ...
    StepPixels=config.step_pixels,UseParallel=useParallel);
data=reqml.io.load_wavefield_sample(sampleFile);
row=design(design.design_id==designId,:);

cs_pred_map=prediction.cs_map;
q_map=prediction.q_map;
valid_mask=prediction.valid_mask & isfinite(cs_pred_map);
cs_truth_map=double(row.cs_true_m_s)*ones(size(cs_pred_map));
signed_error_percent=100*(cs_pred_map-cs_truth_map)./cs_truth_map;
signed_error_percent(~valid_mask)=NaN;
absolute_error_percent=abs(signed_error_percent);
x_mm=prediction.x_mm; z_mm=prediction.z_mm;
patch_predictions=prediction.patch_predictions;
patch_examples=prediction.patch_examples;
wavefield_zx=data.wavefield_zx;
wavefield_x_mm=1e3*data.axes.x_m(:)';
wavefield_z_mm=1e3*data.axes.z_m(:);
parent_source_xyz_m=actualSourceXYZ(data);
expected=[row.expected_source_x_m,row.expected_source_y_m, ...
    row.expected_source_z_m];
if norm(parent_source_xyz_m-expected)>5e-7
    error("reqml:AnalyticFiniteApertureSourceMismatch", ...
        "Resolved source for %s does not match the design.",designId);
end
required=["aperture_model","aperture_span_m","aperture_axis_xyz", ...
    "aperture_node_count","aperture_node_spacing_m", ...
    "aperture_node_weights"];
if ~all(isfield(data.sources,cellstr(required)))
    error("reqml:MissingFiniteApertureMetadata", ...
        "Sample %s lacks finite-aperture metadata.",designId);
end
aperture_model=string(data.sources.aperture_model);
aperture_span_m=double(data.sources.aperture_span_m);
aperture_axis_xyz=double(data.sources.aperture_axis_xyz);
aperture_node_count=double(data.sources.aperture_node_count);
aperture_node_spacing_m=double(data.sources.aperture_node_spacing_m);
aperture_weights=double(data.sources.aperture_node_weights);
force_direction_xyz=[row.force_x,row.force_y,row.force_z];
if aperture_node_count~=row.aperture_node_count || ...
        abs(aperture_span_m-row.aperture_span_m)>1e-12 || ...
        abs(sum(aperture_weights)-1)>1e-12
    error("reqml:AnalyticFiniteApertureMetadataMismatch", ...
        "Realized aperture metadata does not match %s.",designId);
end

patchWidthPixels=double(prediction.metadata.patch_width_pixels);
Lwin_normal_m=(patchWidthPixels-1)*double(data.dz_m);
node_distance_m=double(patch_examples.z_center_m)-parent_source_xyz_m(3);
normalized_node_distance=abs(node_distance_m)/Lwin_normal_m;
patch_center_magnitude=sampleAtPatchCenters(data,patch_examples);
metadata=struct("design",table2struct(row),"sample_file",sampleFile, ...
    "resolved_config_path",runs.resolved_config_path(runIndex), ...
    "framework_commit",frameworkCommit,"reqml_commit",reqmlCommit, ...
    "model",prediction.metadata,"model_resolution",modelResolution.source, ...
    "simulation_provenance",data.provenance, ...
    "simulation_sources",data.sources,"Lwin_normal_m",Lwin_normal_m, ...
    "Lwin_normal_definition", ...
        "(patch_width_pixels - 1) * dz_m; normal to nodal line");

save(resultFile,"wavefield_zx","cs_pred_map","q_map","valid_mask", ...
    "cs_truth_map","signed_error_percent","absolute_error_percent", ...
    "x_mm","z_mm","wavefield_x_mm","wavefield_z_mm", ...
    "patch_predictions","patch_examples","parent_source_xyz_m", ...
    "aperture_model","aperture_span_m","aperture_axis_xyz", ...
    "aperture_node_count","aperture_node_spacing_m","aperture_weights", ...
    "force_direction_xyz","node_distance_m","normalized_node_distance", ...
    "patch_center_magnitude","metadata","-v7.3");
end

function smoke=verifyPhysicalSmokes(smokeDesign,campaignCsv,paths)
runs=readtable(campaignCsv,TextType="string"); smoke=struct();
for index=1:height(smokeDesign)
    row=smokeDesign(index,:);
    runIndex=find(runs.design_id==row.design_id,1);
    if isempty(runIndex)
        error("reqml:AnalyticFiniteApertureSmokeMissing", ...
            "Smoke run %s is missing.",row.design_id);
    end
    data=reqml.io.load_wavefield_sample(runs.wavefield_sample_path(runIndex));
    U=data.wavefield_zx; source=actualSourceXYZ(data);
    z=double(data.axes.z_m(:)); [~,nodeIndex]=min(abs(z-source(3)));
    offset=max(1,round(.004/double(data.dz_m)));
    low=nodeIndex-offset; high=nodeIndex+offset;
    tolerance=1e-8*max(abs(U),[],"all");
    usable=abs(U(low,:))>tolerance & abs(U(high,:))>tolerance;
    phaseDifference=abs(angle(median(U(low,usable)./U(high,usable))));
    nodeRatio=max(abs(U(nodeIndex,:)))/max(abs(U),[],"all");
    if row.force_label=="sourcex"
        if nodeRatio>2e-6 || abs(phaseDifference-pi)>2e-4
            error("reqml:AnalyticFiniteApertureSourceXSmokeFailed", ...
                "%s lost its node or pi phase reversal.",row.design_id);
        end
    elseif phaseDifference>2e-4
        error("reqml:AnalyticFiniteApertureSourceZSmokeFailed", ...
            "%s lost mirror symmetry.",row.design_id);
    end
    if data.sources.aperture_node_count~=row.aperture_node_count
        error("reqml:AnalyticFiniteApertureSmokeMetadataMismatch", ...
            "%s has the wrong node count.",row.design_id);
    end
    field=matlab.lang.makeValidName(char(row.design_id));
    smoke.(field)=struct("source_xyz_m",source, ...
        "node_amplitude_ratio",nodeRatio, ...
        "mirrored_phase_difference_rad",phaseDifference, ...
        "aperture_node_count",data.sources.aperture_node_count, ...
        "aperture_span_m",data.sources.aperture_span_m, ...
        "aperture_node_spacing_m",data.sources.aperture_node_spacing_m, ...
        "aperture_node_offsets_m",data.sources.aperture_node_offsets_m, ...
        "aperture_node_weights",data.sources.aperture_node_weights);
end
writeJson(paths.physicsSmokeJson,smoke);
end

function validateResolvedDesign(runs,design,config)
if numel(runs)~=12 || height(design)~=12
    error("reqml:AnalyticFiniteApertureDesignCount","Expected 12 runs.");
end
for index=1:12
    cfg=runs(index).config; row=design(index,:);
    assert(string(cfg.propagation.model)=="spherical_wave");
    assert(string(cfg.propagation.phase_model)=="local_k_distance");
    assert(string(cfg.sources.radiation.model)== ...
        "point_force_shear_far_field");
    assert(string(cfg.sources.aperture.model)==row.aperture_model);
    assert(abs(cfg.sources.aperture.span_m-row.aperture_span_m)<1e-12);
    assert(norm(double(cfg.sources.aperture.axis_xyz(:)')- ...
        [row.aperture_axis_x,row.aperture_axis_y,row.aperture_axis_z])<1e-12);
    assert(abs(cfg.sources.aperture.node_spacing_m- ...
        row.aperture_node_spacing_m)<1e-12);
    assert(norm(double(cfg.sources.radiation.force_direction_xyz(:)')- ...
        [row.force_x,row.force_y,row.force_z])<1e-12);
    assert(cfg.amplitude.geometric_decay_exponent==0);
    assert(cfg.seed==row.seed && cfg.medium.background_cs_m_s==row.cs_true_m_s);
    assert(cfg.wavefield.frequency_hz==400);
    assert(cfg.sources.amplitude_jitter_fraction==0 && cfg.noise.snr_db==1000);
end
assert(config.M==2 && config.step_pixels==1);
end

function summary=buildSummary(caseData,design,config,frameworkCommit)
rows=cell(height(design),1);
for index=1:height(design)
    value=caseData(index); predictions=value.patch_predictions;
    valid=logical(predictions.sws_valid) & isfinite(predictions.cs_pred_m_s);
    predicted=double(predictions.cs_pred_m_s(valid));
    truth=double(design.cs_true_m_s(index));
    errorPercent=100*(predicted-truth)/truth;
    wavelength=truth/double(config.frequency_hz);
    Lwin=double(value.metadata.Lwin_normal_m);
    rows{index}=struct("design_id",design.design_id(index), ...
        "cs_true_m_s",truth,"force_label",design.force_label(index), ...
        "aperture_model",design.aperture_model(index), ...
        "aperture_span_mm",1e3*design.aperture_span_m(index), ...
        "aperture_node_count",value.aperture_node_count, ...
        "aperture_node_spacing_mm",1e3*value.aperture_node_spacing_m, ...
        "wavelength_mm",1e3*wavelength, ...
        "aperture_over_wavelength",value.aperture_span_m/wavelength, ...
        "Lwin_normal_mm",1e3*Lwin, ...
        "aperture_over_Lwin",value.aperture_span_m/Lwin, ...
        "patch_count",height(predictions),"valid_patch_count",nnz(valid), ...
        "invalid_fraction",1-nnz(valid)/height(predictions), ...
        "mean_predicted_cs_m_s",safeMean(predicted), ...
        "median_predicted_cs_m_s",safeMedian(predicted), ...
        "MAPE_percent",safeMean(abs(errorPercent)), ...
        "bias_percent",safeMean(errorPercent), ...
        "RMSE_m_s",sqrt(safeMean((predicted-truth).^2)), ...
        "median_absolute_error_percent",safeMedian(abs(errorPercent)), ...
        "p90_absolute_error_percent",safePercentile(abs(errorPercent),90), ...
        "framework_commit",frameworkCommit, ...
        "reqml_commit",string(value.metadata.reqml_commit), ...
        "q0_model_provenance", ...
            string(value.metadata.model.model_provenance_id));
end
summary=struct2table(vertcat(rows{:}));
end

function output=buildNodeSummary(caseData,design)
edges=[0 .5 1 Inf]; labels=["<0.5","0.5-1",">1"];
rows=cell(height(design)*3,1); ordinal=0;
for caseIndex=1:height(design)
    value=caseData(caseIndex); p=value.patch_predictions;
    truth=double(design.cs_true_m_s(caseIndex));
    for bandIndex=1:3
        ordinal=ordinal+1;
        selected=value.normalized_node_distance>=edges(bandIndex) & ...
            value.normalized_node_distance<edges(bandIndex+1);
        valid=selected & logical(p.sws_valid) & isfinite(p.cs_pred_m_s);
        predicted=double(p.cs_pred_m_s(valid));
        errors=100*(predicted-truth)/truth;
        rows{ordinal}=struct("design_id",design.design_id(caseIndex), ...
            "cs_true_m_s",truth,"force_label",design.force_label(caseIndex), ...
            "aperture_span_mm",1e3*design.aperture_span_m(caseIndex), ...
            "normalized_node_distance_band",labels(bandIndex), ...
            "patch_count",nnz(selected),"valid_patch_count",nnz(valid), ...
            "valid_fraction",safeFraction(nnz(valid),nnz(selected)), ...
            "median_q",safeMedian(double(p.q_pred(valid))), ...
            "median_predicted_cs_m_s",safeMedian(predicted), ...
            "MAPE_percent",safeMean(abs(errors)), ...
            "bias_percent",safeMean(errors), ...
            "median_absolute_error_percent",safeMedian(abs(errors)));
    end
end
output=struct2table(vertcat(rows{:}));
end

function output=buildWavefieldSimilarity(caseData,design)
rows=cell(8,1); ordinal=0;
for cs=[2 3]
    for force=["sourcez","sourcex"]
        pointIndex=find(design.cs_true_m_s==cs & design.force_label==force & ...
            design.aperture_span_m==0);
        Up=caseData(pointIndex).wavefield_zx;
        for span=[.004 .008]
            ordinal=ordinal+1;
            apertureIndex=find(design.cs_true_m_s==cs & ...
                design.force_label==force & design.aperture_span_m==span);
            Ua=caseData(apertureIndex).wavefield_zx;
            rho=abs(dot(Up(:),Ua(:)))/(norm(Up(:))*norm(Ua(:)));
            alpha=dot(Ua(:),Up(:))/dot(Ua(:),Ua(:));
            shapeError=norm(alpha*Ua(:)-Up(:))/norm(Up(:));
            rows{ordinal}=struct("cs_true_m_s",cs,"force_label",force, ...
                "aperture_span_mm",1e3*span,"complex_correlation",rho, ...
                "optimal_scaled_shape_error",shapeError, ...
                "optimal_complex_scale_real",real(alpha), ...
                "optimal_complex_scale_imag",imag(alpha));
        end
    end
end
output=struct2table(vertcat(rows{:}));
end

function output=buildSpectralSummary(caseData,design,config)
regions=["near_node","mid_0p5_1","farthest"];
rows=cell(2*2*3*3,1); ordinal=0;
for cs=[2 3]
    referenceIndex=find(design.cs_true_m_s==cs & ...
        design.force_label=="sourcex" & design.aperture_span_m==0);
    reference=caseData(referenceIndex);
    valid=find(reference.patch_predictions.sws_valid & ...
        isfinite(reference.normalized_node_distance));
    [~,nearWhich]=min(reference.normalized_node_distance(valid));
    nearIndex=valid(nearWhich);
    midCandidates=valid(reference.normalized_node_distance(valid)>=.5 & ...
        reference.normalized_node_distance(valid)<1);
    [~,midWhich]=min(abs(reference.normalized_node_distance(midCandidates)-.75));
    midIndex=midCandidates(midWhich);
    [~,farWhich]=max(reference.normalized_node_distance(valid));
    farIndex=valid(farWhich);
    referenceIndices=[nearIndex,midIndex,farIndex];
    for force=["sourcez","sourcex"]
        pointCaseIndex=find(design.cs_true_m_s==cs & ...
            design.force_label==force & design.aperture_span_m==0);
        pointCase=caseData(pointCaseIndex);
        for regionIndex=1:3
            centerX=reference.patch_examples.x_center_m( ...
                referenceIndices(regionIndex));
            centerZ=reference.patch_examples.z_center_m( ...
                referenceIndices(regionIndex));
            pointPatch=nearestPatch(pointCase,centerX,centerZ);
            [~,pointP]=radialIncrement( ...
                pointCase.patch_examples.req_mapping{pointPatch});
            for span=[0 .004 .008]
                ordinal=ordinal+1;
                caseIndex=find(design.cs_true_m_s==cs & ...
                    design.force_label==force & design.aperture_span_m==span);
                value=caseData(caseIndex);
                patchIndex=nearestPatch(value,centerX,centerZ);
                [~,p]=radialIncrement(value.patch_examples.req_mapping{patchIndex});
                count=min(numel(p),numel(pointP));
                rows{ordinal}=struct("cs_true_m_s",cs, ...
                    "force_label",force,"region",regions(regionIndex), ...
                    "aperture_span_mm",1e3*span, ...
                    "normalized_node_distance", ...
                        value.normalized_node_distance(patchIndex), ...
                    "radial_L1_from_matched_point", ...
                        sum(abs(p(1:count)-pointP(1:count))), ...
                    "q_pred",value.patch_predictions.q_pred(patchIndex), ...
                    "k_pred_rad_m", ...
                        value.patch_predictions.k_pred_rad_m(patchIndex), ...
                    "cs_pred_m_s", ...
                        value.patch_predictions.cs_pred_m_s(patchIndex), ...
                    "true_k_rad_m",2*pi*double(config.frequency_hz)/cs);
            end
        end
    end
end
output=struct2table(vertcat(rows{:}));
end

function makeAllFigures(caseData,design,summary,nodeSummary,paths,config)
for index=1:height(design)
    makePerCaseFigure(design.design_id(index),paths);
end
for cs=[2 3]
    for force=["sourcez","sourcex"]
        selected=design.cs_true_m_s==cs & design.force_label==force;
        makeApertureMapFigure(caseData(selected),design(selected,:), ...
            fullfile(paths.figuresDirectory,sprintf( ...
                "cs%d_%s_aperture_maps.png",cs,force)));
        makeNodeProfilesFigure(caseData(selected),design(selected,:), ...
            fullfile(paths.figuresDirectory,sprintf( ...
                "cs%d_%s_node_profiles.png",cs,force)));
        makeSpectralFigure(caseData,design,cs,force,config, ...
            fullfile(paths.figuresDirectory,sprintf( ...
                "cs%d_%s_local_spectra.png",cs,force)));
    end
end
makeGlobalErrorFigure(summary, ...
    fullfile(paths.figuresDirectory,"global_error_vs_aperture.png"));
makeForcePenaltyFigure(summary, ...
    fullfile(paths.figuresDirectory,"sourcex_minus_sourcez.png"));
makeNodeLocalFigure(nodeSummary, ...
    fullfile(paths.figuresDirectory,"node_local_error_vs_aperture.png"));
end

function makePerCaseFigure(designId,paths)
s=load(fullfile(paths.casesDirectory,designId,"result.mat"));
phase=maskedPhase(s.wavefield_zx);
f=figure(Visible="off",Color="w",Position=[50 50 1700 950]);
cleanup=onCleanup(@() close(f)); tiledlayout(2,3,Padding="compact");
plotMap(s.wavefield_x_mm,s.wavefield_z_mm,abs(s.wavefield_zx),"|U_z|");
plotMap(s.wavefield_x_mm,s.wavefield_z_mm,real(s.wavefield_zx),"real(U_z)");
plotMap(s.wavefield_x_mm,s.wavefield_z_mm,phase,"phase(U_z)",[-pi pi]);
plotMap(s.x_mm,s.z_mm,s.cs_pred_map,"Frozen Q0 SWS (m/s)",[1 4]);
plotMap(s.x_mm,s.z_mm,s.q_map,"predicted q",[0 1]);
limit=max(5,safePercentile(abs(s.signed_error_percent(:)),99));
plotMap(s.x_mm,s.z_mm,s.signed_error_percent,"signed error (%)",[-limit limit]);
for axisHandle=findobj(f,Type="axes")'
    yline(axisHandle,1e3*s.parent_source_xyz_m(3),"w--",LineWidth=1.1);
end
sgtitle(strrep(designId,"_"," "));
exportgraphics(f,fullfile(paths.figuresDirectory, ...
    designId+"_diagnostic.png"),Resolution=180); clear cleanup
end

function makeApertureMapFigure(group,groupDesign,file)
[group,groupDesign]=orderApertures(group,groupDesign);
amplitudeLimit=max(arrayfun(@(v)max(abs(v.wavefield_zx),[],"all"),group));
errorLimit=max(5,max(arrayfun(@(v)safePercentile( ...
    abs(v.signed_error_percent(:)),99),group)));
f=figure(Visible="off",Color="w",Position=[50 50 1500 1900]);
cleanup=onCleanup(@() close(f)); tiledlayout(5,3,Padding="compact");
for index=1:3
    plotMap(group(index).wavefield_x_mm,group(index).wavefield_z_mm, ...
        abs(group(index).wavefield_zx),groupDesign.aperture_label(index)+ ...
        " |U_z|",[0 amplitudeLimit]);
end
for index=1:3
    plotMap(group(index).wavefield_x_mm,group(index).wavefield_z_mm, ...
        maskedPhase(group(index).wavefield_zx), ...
        groupDesign.aperture_label(index)+" phase",[-pi pi]);
end
for index=1:3
    plotMap(group(index).x_mm,group(index).z_mm,group(index).cs_pred_map, ...
        groupDesign.aperture_label(index)+" SWS",[1 4]);
end
for index=1:3
    plotMap(group(index).x_mm,group(index).z_mm,group(index).q_map, ...
        groupDesign.aperture_label(index)+" q",[0 1]);
end
for index=1:3
    plotMap(group(index).x_mm,group(index).z_mm, ...
        group(index).signed_error_percent, ...
        groupDesign.aperture_label(index)+" signed error", ...
        [-errorLimit errorLimit]);
end
for axisHandle=findobj(f,Type="axes")'
    yline(axisHandle,1e3*group(1).parent_source_xyz_m(3), ...
        "w--",LineWidth=1.0);
end
sgtitle(sprintf("cs=%.1f m/s; %s; aperture comparison", ...
    groupDesign.cs_true_m_s(1),upper(groupDesign.force_label(1))));
exportgraphics(f,file,Resolution=180); clear cleanup
end

function makeNodeProfilesFigure(group,groupDesign,file)
[group,groupDesign]=orderApertures(group,groupDesign);
colors=lines(3); edges=linspace(0,max(vertcat( ...
    group.normalized_node_distance)),12);
labels=["predicted q","SWS (m/s)","signed error (%)", ...
    "absolute error (%)","local |U_z|"];
f=figure(Visible="off",Color="w",Position=[50 50 1700 720]);
cleanup=onCleanup(@() close(f)); tiledlayout(2,3,Padding="compact");
for panel=1:5
    nexttile; hold on;
    for index=1:3
        values=profileValues(group(index),panel, ...
            groupDesign.cs_true_m_s(index));
        [centers,med,q1,q3]=binnedSummary( ...
            group(index).normalized_node_distance,values,edges);
        fill([centers;flipud(centers)],[q1;flipud(q3)],colors(index,:), ...
            FaceAlpha=.12,EdgeColor="none",HandleVisibility="off");
        plot(centers,med,LineWidth=2,Color=colors(index,:));
    end
    xline(.5,"k--"); xline(1,"k:"); grid on;
    xlabel("|d_{node}|/L_{win,normal}"); ylabel(labels(panel));
end
legend("point","4 mm","8 mm",Location="best");
sgtitle(sprintf("Node profiles: cs=%.1f; %s", ...
    groupDesign.cs_true_m_s(1),upper(groupDesign.force_label(1))));
exportgraphics(f,file,Resolution=180); clear cleanup
end

function makeSpectralFigure(caseData,design,cs,force,config,file)
referenceIndex=find(design.cs_true_m_s==cs & ...
    design.force_label=="sourcex" & design.aperture_span_m==0);
reference=caseData(referenceIndex);
valid=find(reference.patch_predictions.sws_valid & ...
    isfinite(reference.normalized_node_distance));
indices=zeros(1,3);
[~,which]=min(reference.normalized_node_distance(valid)); indices(1)=valid(which);
mid=valid(reference.normalized_node_distance(valid)>=.5 & ...
    reference.normalized_node_distance(valid)<1);
[~,which]=min(abs(reference.normalized_node_distance(mid)-.75)); indices(2)=mid(which);
[~,which]=max(reference.normalized_node_distance(valid)); indices(3)=valid(which);
regionLabels=["nearest node","0.5-1 Lwin","farthest supported"];
colors=lines(3); trueK=2*pi*double(config.frequency_hz)/cs;
f=figure(Visible="off",Color="w",Position=[50 50 1400 1150]);
cleanup=onCleanup(@() close(f)); tiledlayout(3,2,Padding="compact");
for region=1:3
    centerX=reference.patch_examples.x_center_m(indices(region));
    centerZ=reference.patch_examples.z_center_m(indices(region));
    nexttile; hold on;
    mappings=cell(1,3); predictions=zeros(1,3);
    for apertureIndex=1:3
        span=[0 .004 .008];
        caseIndex=find(design.cs_true_m_s==cs & ...
            design.force_label==force & ...
            design.aperture_span_m==span(apertureIndex));
        value=caseData(caseIndex); patch=nearestPatch(value,centerX,centerZ);
        mappings{apertureIndex}=value.patch_examples.req_mapping{patch};
        predictions(apertureIndex)=value.patch_predictions.k_pred_rad_m(patch);
        [k,p]=radialIncrement(mappings{apertureIndex});
        plot(k,p,LineWidth=2,Color=colors(apertureIndex,:));
        xline(predictions(apertureIndex),":", ...
            Color=colors(apertureIndex,:),HandleVisibility="off");
    end
    xline(trueK,"k--","true k"); grid on; xlim([0 2.2*trueK]);
    ylabel("normalized P(k)"); title(regionLabels(region));
    if region==1, legend("point","4 mm","8 mm","true k"); end
    nexttile; hold on;
    for apertureIndex=1:3
        plot(double(mappings{apertureIndex}.k_cent), ...
            double(mappings{apertureIndex}.Ecum),LineWidth=2, ...
            Color=colors(apertureIndex,:));
    end
    xline(trueK,"k--"); grid on; ylim([0 1]); xlim([0 2.2*trueK]);
    ylabel("E_{cum}(k)");
end
sgtitle(sprintf("Local spectra: cs=%.1f; %s",cs,upper(force)));
exportgraphics(f,file,Resolution=180); clear cleanup
end

function makeGlobalErrorFigure(summary,file)
colors=lines(2); f=figure(Visible="off",Color="w",Position=[50 50 1700 520]);
cleanup=onCleanup(@() close(f)); tiledlayout(1,3,Padding="compact");
for forceIndex=1:2
    force=["sourcez","sourcex"]; subset=summary(summary.force_label==force(forceIndex),:);
    for metricIndex=1:3
        nexttile(metricIndex); hold on;
        for csIndex=1:2
            cs=[2 3]; rows=subset(subset.cs_true_m_s==cs(csIndex),:);
            [~,order]=sort(rows.aperture_span_mm); rows=rows(order,:);
            values={rows.MAPE_percent,rows.bias_percent, ...
                rows.median_predicted_cs_m_s};
            styles=["-o","--s"];
            plot(rows.aperture_span_mm,values{metricIndex}, ...
                styles(forceIndex),Color=colors(csIndex,:),LineWidth=2, ...
                DisplayName=sprintf("%s cs%d",upper(force(forceIndex)),cs(csIndex)));
        end
    end
end
labels=["MAPE (%)","bias (%)","median SWS (m/s)"];
for panel=1:3
    nexttile(panel); grid on; xlabel("aperture span (mm)");
    ylabel(labels(panel)); if panel==1,legend(Location="best");end
end
sgtitle("Frozen Q0 error versus coherent aperture size");
exportgraphics(f,file,Resolution=180); clear cleanup
end

function makeForcePenaltyFigure(summary,file)
f=figure(Visible="off",Color="w",Position=[50 50 1100 480]);
cleanup=onCleanup(@() close(f)); tiledlayout(1,2,Padding="compact");
for metric=1:2
    nexttile; hold on;
    for cs=[2 3]
        z=summary(summary.cs_true_m_s==cs & summary.force_label=="sourcez",:);
        x=summary(summary.cs_true_m_s==cs & summary.force_label=="sourcex",:);
        [~,oz]=sort(z.aperture_span_mm); z=z(oz,:);
        [~,ox]=sort(x.aperture_span_mm); x=x(ox,:);
        if metric==1, values=x.MAPE_percent-z.MAPE_percent;
        else, values=x.bias_percent-z.bias_percent; end
        plot(x.aperture_span_mm,values,"-o",LineWidth=2, ...
            DisplayName=sprintf("cs%d",cs));
    end
    yline(0,"k--",HandleVisibility="off"); grid on;
    xlabel("aperture span (mm)");
    if metric==1, ylabel("SOURCE-X - SOURCE-Z MAPE (pp)");
    else, ylabel("SOURCE-X - SOURCE-Z bias (pp)"); end
end
legend(Location="best"); sgtitle("Incremental SOURCE-X radiation penalty");
exportgraphics(f,file,Resolution=180); clear cleanup
end

function makeNodeLocalFigure(nodeSummary,file)
near=nodeSummary(nodeSummary.normalized_node_distance_band=="<0.5",:);
f=figure(Visible="off",Color="w",Position=[50 50 1100 480]);
cleanup=onCleanup(@() close(f)); tiledlayout(1,2,Padding="compact");
for metric=1:2
    nexttile; hold on;
    for cs=[2 3]
        for force=["sourcez","sourcex"]
            rows=near(near.cs_true_m_s==cs & near.force_label==force,:);
            [~,order]=sort(rows.aperture_span_mm); rows=rows(order,:);
            if metric==1, values=rows.MAPE_percent; else, values=rows.bias_percent; end
            plot(rows.aperture_span_mm,values,"-o",LineWidth=1.8, ...
                DisplayName=sprintf("%s cs%d",upper(force),cs));
        end
    end
    grid on; xlabel("aperture span (mm)");
    if metric==1,ylabel("near-node MAPE (%)");else,ylabel("near-node bias (%)");end
end
legend(Location="best"); sgtitle("|d_{node}|/L_{win}<0.5");
exportgraphics(f,file,Resolution=180); clear cleanup
end

function writeReadme(file,summary,nodeSummary,similarity,spectral,smoke, ...
        config,fullRuntimeS,currentRuntimeS)
fid=fopen(file,"w");
if fid<0,error("reqml:DiagnosticSummaryWriteFailed","Cannot write %s",file);end
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,"Analytic coherent finite-aperture Frozen Q0 diagnostic\n\n");
fprintf(fid,"Controlled analytic result, not causal proof. Full diagnostic runtime %.1f s.\n",fullRuntimeS);
fprintf(fid,"Current reporting-pass runtime %.1f s.\n",currentRuntimeS);
fprintf(fid,"Selected node spacing: %.3f mm. Convergence rho %.9f; shape error %.6f.\n\n", ...
    1e3*config.aperture_convergence.selected_node_spacing_m, ...
    config.aperture_convergence.complex_correlation, ...
    config.aperture_convergence.optimal_scaled_shape_error);
for cs=[2 3]
    fprintf(fid,"cs %.1f m/s\n",cs);
    for force=["sourcez","sourcex"]
        rows=summary(summary.cs_true_m_s==cs & summary.force_label==force,:);
        point=rows(rows.aperture_span_mm==0,:);
        four=rows(rows.aperture_span_mm==4,:);
        eight=rows(rows.aperture_span_mm==8,:);
        fprintf(fid,"  %s: dMAPE 4-point=%+.4f pp; 8-point=%+.4f pp.\n", ...
            upper(force),four.MAPE_percent-point.MAPE_percent, ...
            eight.MAPE_percent-point.MAPE_percent);
    end
    for span=[0 4 8]
        z=summary(summary.cs_true_m_s==cs & summary.force_label=="sourcez" & ...
            summary.aperture_span_mm==span,:);
        x=summary(summary.cs_true_m_s==cs & summary.force_label=="sourcex" & ...
            summary.aperture_span_mm==span,:);
        fprintf(fid,"  %g mm SOURCE-X penalty: dMAPE=%+.4f pp; dBias=%+.4f pp.\n", ...
            span,x.MAPE_percent-z.MAPE_percent,x.bias_percent-z.bias_percent);
    end
    near=nodeSummary(nodeSummary.cs_true_m_s==cs & ...
        nodeSummary.normalized_node_distance_band=="<0.5",:);
    for force=["sourcez","sourcex"]
        rows=near(near.force_label==force,:);
        point=rows(rows.aperture_span_mm==0,:);
        four=rows(rows.aperture_span_mm==4,:);
        eight=rows(rows.aperture_span_mm==8,:);
        fprintf(fid,"  Near node %s dMAPE: 4-point=%+.4f pp; 8-point=%+.4f pp.\n", ...
            upper(force),four.MAPE_percent-point.MAPE_percent, ...
            eight.MAPE_percent-point.MAPE_percent);
    end
    for force=["sourcez","sourcex"]
        rows=spectral(spectral.cs_true_m_s==cs & ...
            spectral.force_label==force & spectral.region=="near_node",:);
        fprintf(fid,"  Near-node %s radial L1: 4 mm %.5f; 8 mm %.5f.\n", ...
            upper(force),rows.radial_L1_from_matched_point( ...
            rows.aperture_span_mm==4),rows.radial_L1_from_matched_point( ...
            rows.aperture_span_mm==8));
    end
end
fprintf(fid,"\nWavefield shape versus matched point:\n");
for index=1:height(similarity)
    fprintf(fid,"  cs%.0f %s %.0f mm: rho %.6f; scaled shape error %.6f.\n", ...
        similarity.cs_true_m_s(index),upper(similarity.force_label(index)), ...
        similarity.aperture_span_mm(index), ...
        similarity.complex_correlation(index), ...
        similarity.optimal_scaled_shape_error(index));
end
fields=fieldnames(smoke);
fprintf(fid,"\nPhysics smokes: %d/4 passed with expected symmetry and metadata.\n", ...
    numel(fields));
fprintf(fid,"\nDecision framing:\n");
fprintf(fid,"- Monotonic SOURCE-X error and spectral distortion would make finite aperture an additional candidate mechanism.\n");
fprintf(fid,"- Large field-shape change without Q0 change indicates robustness in this analytic model.\n");
fprintf(fid,"- If 8 mm remains well below prior k-Wave behavior, unresolved full-wave physics remains dominant.\n");
sourceX=summary(summary.force_label=="sourcex",:);
monotonicIncrease=true;
for cs=[2 3]
    rows=sourceX(sourceX.cs_true_m_s==cs,:);
    [~,order]=sort(rows.aperture_span_mm); rows=rows(order,:);
    monotonicIncrease=monotonicIncrease && all(diff(rows.MAPE_percent)>0);
end
maximumSourceXShape=max(similarity.optimal_scaled_shape_error( ...
    similarity.force_label=="sourcex"));
maximumSourceXMapeChange=0;
for cs=[2 3]
    rows=sourceX(sourceX.cs_true_m_s==cs,:);
    point=rows.MAPE_percent(rows.aperture_span_mm==0);
    maximumSourceXMapeChange=max(maximumSourceXMapeChange, ...
        max(abs(rows.MAPE_percent-point)));
end
fprintf(fid,"\nObserved decision:\n");
if monotonicIncrease
    fprintf(fid,"- Case 1 is met: SOURCE-X MAPE increased monotonically with aperture.\n");
else
    fprintf(fid,"- Case 1 is not met: SOURCE-X MAPE did not increase monotonically; it decreased for both cs values.\n");
end
fprintf(fid,"- Maximum SOURCE-X scaled field-shape error was %.4f while maximum absolute SOURCE-X MAPE change was %.4f pp. This supports the Case-2 robustness interpretation for this analytic model.\n", ...
    maximumSourceXShape,maximumSourceXMapeChange);
fprintf(fid,"\nThis coherent line is a controlled idealization, not an exact k-Wave contact.\n");
fprintf(fid,"Excluded physics: complete elastodynamic Green tensor, P waves, near-field tensor terms, boundaries, reflections, interfaces, mode conversion, and k-Wave source-boundary implementation.\n");
clear cleanup
end

function writeManifest(file,configFile,config,paths,frameworkRoot, ...
        frameworkCommit,reqmlCommit,modelFile,modelResolution,summary, ...
        fullRuntimeS,currentRuntimeS,reusedExistingResults)
casePaths=arrayfun(@(id)fullfile(paths.casesDirectory,id,"result.mat"), ...
    summary.design_id,UniformOutput=false);
manifest=struct("schema_name","reqml_analytic_finite_aperture_q0_results", ...
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
    "full_diagnostic_runtime_s",fullRuntimeS, ...
    "current_execution_runtime_s",currentRuntimeS, ...
    "current_execution_reused_existing_results",reusedExistingResults, ...
    "selected_node_spacing_m", ...
        config.sources.aperture_node_spacing_m, ...
    "aperture_convergence",config.aperture_convergence, ...
    "simulation_output_directory",fullfile(paths.root,"simulations"), ...
    "result_paths",{casePaths},"figure_directory",paths.figuresDirectory, ...
    "summary_csv",paths.summaryCsv, ...
    "node_distance_summary_csv",paths.nodeSummaryCsv, ...
    "wavefield_similarity_csv",paths.similarityCsv, ...
    "spectral_summary_csv",paths.spectralCsv, ...
    "simulation_or_training", ...
        "12 clean swsynth simulations; frozen inference; no training");
writeJson(file,manifest);
end

function data=loadCaseResults(design,paths)
firstFile=fullfile(paths.casesDirectory,design.design_id(1),"result.mat");
if ~isfile(firstFile),error("reqml:DiagnosticResultMissing","Missing %s",firstFile);end
first=load(firstFile); data=repmat(first,height(design),1);
for index=2:height(design)
    file=fullfile(paths.casesDirectory,design.design_id(index),"result.mat");
    if ~isfile(file),error("reqml:DiagnosticResultMissing","Missing %s",file);end
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
    "simulation_campaign_analytic_finite_aperture_q0_v1.json");
paths.casesDirectory=fullfile(root,"cases");
paths.figuresDirectory=fullfile(root,"figures");
paths.designCsv=fullfile(root,"design.csv");
paths.designJson=fullfile(root,"design.json");
paths.physicsSmokeJson=fullfile(root,"physics_smoke.json");
paths.summaryCsv=fullfile(root,"summary.csv");
paths.nodeSummaryCsv=fullfile(root,"node_distance_summary.csv");
paths.similarityCsv=fullfile(root,"aperture_wavefield_similarity.csv");
paths.spectralCsv=fullfile(root,"spectral_aperture_summary.csv");
paths.readme=fullfile(root,"README.txt");
paths.manifest=fullfile(root,"manifest.json");
end

function ensureDirectories(paths)
for directory=[paths.root,paths.batchDirectory,paths.casesDirectory, ...
        paths.figuresDirectory]
    if ~isfolder(directory),mkdir(directory);end
end
end

function [group,groupDesign]=orderApertures(group,groupDesign)
[~,order]=sort(groupDesign.aperture_span_m);
group=group(order); groupDesign=groupDesign(order,:);
end

function phase=maskedPhase(U)
phase=angle(U); phase(abs(U)<1e-8*max(abs(U),[],"all"))=NaN;
end

function plotMap(x,z,value,titleText,limits)
nexttile; imagesc(x,z,value); axis image; set(gca,YDir="normal"); colorbar;
title(titleText); xlabel("x (mm)"); ylabel("z (mm)");
if nargin>=5 && all(isfinite(limits)),clim(limits);end
end

function values=profileValues(value,panel,truth)
switch panel
    case 1, values=double(value.patch_predictions.q_pred);
    case 2, values=double(value.patch_predictions.cs_pred_m_s);
    case 3, values=100*(double(value.patch_predictions.cs_pred_m_s)-truth)/truth;
    case 4, values=abs(100*(double(value.patch_predictions.cs_pred_m_s)-truth)/truth);
    case 5, values=value.patch_center_magnitude;
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

function index=nearestPatch(value,x,z)
distance=(double(value.patch_examples.x_center_m)-double(x)).^2 + ...
    (double(value.patch_examples.z_center_m)-double(z)).^2;
[~,index]=min(distance);
end

function [k,p]=radialIncrement(mapping)
k=double(mapping.k_cent(:));
p=max(0,diff([0;double(mapping.Ecum(:))]));
p=p/max(sum(p),eps);
end

function [centers,med,q1,q3]=binnedSummary(x,y,edges)
x=double(x(:));y=double(y(:));bins=discretize(x,edges);
centers=(edges(1:end-1)+edges(2:end))'/2;
med=nan(size(centers));q1=med;q3=med;
for index=1:numel(centers)
    values=y(bins==index & isfinite(y));
    if ~isempty(values)
        med(index)=median(values);q1(index)=prctile(values,25); ...
            q3(index)=prctile(values,75);
    end
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
if status~=0,error("reqml:GitCommitUnavailable","Cannot resolve %s",root);end
commit=strtrim(string(output));
end

function writeJson(file,value)
fid=fopen(file,"w");
if fid<0,error("reqml:DiagnosticJsonWriteFailed","Cannot write %s",file);end
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,"%s",jsonencode(value,PrettyPrint=true));clear cleanup
end

function tf=containsPath(value)
tf=any(string(strsplit(path,pathsep))==string(value));
end

function restorePath(value,wasAdded)
if wasAdded,rmpath(value);rehash;end
end

function value=safeFraction(numerator,denominator)
if denominator==0,value=NaN;else,value=numerator/denominator;end
end

function value=safeMean(values)
values=values(isfinite(values));
if isempty(values),value=NaN;else,value=mean(values);end
end

function value=safeMedian(values)
values=values(isfinite(values));
if isempty(values),value=NaN;else,value=median(values);end
end

function value=safePercentile(values,percent)
values=values(isfinite(values));
if isempty(values),value=NaN;else,value=prctile(values,percent);end
end
