function report = run_analytic_plane_spherical_q0_v1(options)
%RUN_ANALYTIC_PLANE_SPHERICAL_Q0_V1 Run the fixed 12-case Q0 diagnostic.
%
% The diagnostic uses swsynth only. It never trains a model and always
% applies the frozen model through reqml.predictSWS.

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

repository_root = fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(fullfile(repository_root, "src"));
config_file = string(options.ConfigFile);
if strlength(config_file) == 0
    config_file = fullfile(repository_root, "configs", "validation", ...
        "reqml_analytic_plane_spherical_q0_v1.json");
end
config = jsondecode(fileread(config_file));

output_directory = resolve_path(config.output_directory, repository_root);
if strlength(string(options.OutputDirectory)) > 0
    output_directory = string(options.OutputDirectory);
end
model_file = resolve_path(config.model_file, repository_root);
if strlength(string(options.Model)) > 0
    model_file = string(options.Model);
end
if ~isfile(model_file)
    error("reqml:Q0ModelNotFound", ...
        "Frozen current Q0 model was not found: %s", model_file);
end
[resolved_model, model_resolution] = reqml.models.resolveCurrentQ0Model( ...
    Model=model_file, RepositoryRoot=repository_root);

framework_root = string(config.simulation_framework_root);
framework_src = fullfile(framework_root, "src");
if ~isfolder(framework_src)
    error("reqml:SimulationFrameworkSourceNotFound", ...
        "Simulation framework source was not found: %s", framework_src);
end
framework_commit = git_commit(framework_root);
reqml_commit = git_commit(repository_root);

paths = output_paths(output_directory);
ensure_directories(paths);
simulation_output = fullfile(output_directory, "simulations");
[campaign, design] = reqml.analysis.buildAnalyticPlaneSphericalCampaign( ...
    config, simulation_output);
writetable(design, paths.design_csv);
write_json(paths.design_json, table2struct(design));
write_json(paths.campaign_file, campaign);

fprintf("\nAnalytic plane/spherical diagnostic design (%d runs):\n", ...
    height(design));
disp(design(:, ["design_id","cs_true_m_s","orientation", ...
    "propagation_condition","geometric_decay_exponent", ...
    "source_x_m","source_z_m"]));

path_was_added = ~contains_path(framework_src);
if path_was_added
    addpath(framework_src);
    rehash;
end
cleanup_path = onCleanup(@() restore_path(framework_src, path_was_added));

[expanded_runs, validation] = simcampaigns.validateCampaign(paths.campaign_file);
if ~validation.valid || numel(expanded_runs) ~= 12
    error("reqml:AnalyticPlaneSphericalCampaignInvalid", ...
        "Campaign dry-run validation failed: %s", validation.summary);
end
validate_resolved_pair(expanded_runs, design, config);
fprintf("Validated plane example: %s\n", design.design_id(1));
spherical_index = find(design.propagation_model=="spherical_wave",1);
fprintf("Validated spherical example: %s; source=(%.6f, %.6f) m\n", ...
    design.design_id(spherical_index), design.source_x_m(spherical_index), ...
    design.source_z_m(spherical_index));

if options.RunSimulations
    run_smoke_if_needed(campaign, design, paths, framework_root);
end

smoke_design_id = design.design_id(1);
if options.RunInference
    smoke_csv = campaign_csv_path(simulation_output, config.diagnostic_id);
    process_case(smoke_design_id, design, smoke_csv, paths, config, ...
        resolved_model, model_resolution, framework_commit, reqml_commit, ...
        options.UseParallel, true);
end
if options.MakePlots
    make_per_case_figure(smoke_design_id, paths);
end
verify_smoke_outputs(smoke_design_id, paths);
fprintf("One-case smoke passed: %s\n", smoke_design_id);

if options.SmokeOnly
    report = final_report(paths, design(1,:), framework_commit, ...
        reqml_commit, resolved_model, true);
    clear cleanup_path
    return
end

write_json(paths.campaign_file, campaign);
if options.RunSimulations
    reqml.campaigns.executeAdaptiveBatch(paths.batch_directory, ...
        framework_root, Resume=true, ContinueOnError=false);
end
campaign_csv = campaign_csv_path(simulation_output, config.diagnostic_id);
if ~isfile(campaign_csv)
    error("reqml:AnalyticPlaneSphericalCampaignCsvNotFound", ...
        "Campaign CSV was not found: %s", campaign_csv);
end

if options.RunInference
    for index = 1:height(design)
        process_case(design.design_id(index), design, campaign_csv, paths, ...
            config, resolved_model, model_resolution, framework_commit, ...
            reqml_commit, options.UseParallel, false);
    end
end

case_data = load_all_case_results(design, paths);
summary = build_summary(case_data, design, config, framework_commit, ...
    reqml_commit);
writetable(summary, paths.summary_csv);
write_text_summary(paths.readme, summary);
if options.MakePlots
    make_all_figures(case_data, design, paths, config);
end
write_manifest(paths.manifest, config, paths, framework_commit, ...
    reqml_commit, resolved_model, model_resolution, summary);
report = final_report(paths, summary, framework_commit, reqml_commit, ...
    resolved_model, false);
fprintf("\nDiagnostic complete. Summary: %s\n", paths.summary_csv);
disp(summary(:, ["design_id","MAPE_percent","bias_percent", ...
    "median_predicted_cs_m_s","invalid_fraction"]));
clear cleanup_path
end

function run_smoke_if_needed(campaign, design, paths, framework_root)
smoke_campaign = campaign;
smoke_campaign.runs = campaign.runs(1);
write_json(paths.campaign_file, smoke_campaign);
fprintf("\nRunning/resuming one-case smoke: %s\n", design.design_id(1));
reqml.campaigns.executeAdaptiveBatch(paths.batch_directory, framework_root, ...
    Resume=true, ContinueOnError=false);
end

function process_case(design_id, design, campaign_csv, paths, config, ...
        model_file, model_resolution, framework_commit, reqml_commit, ...
        use_parallel, force)
case_directory = fullfile(paths.cases_directory, design_id);
result_file = fullfile(case_directory, "result.mat");
if isfile(result_file) && ~force
    return
end
if ~isfolder(case_directory)
    mkdir(case_directory);
end
runs = readtable(campaign_csv, TextType="string");
run_index = find(runs.design_id==design_id,1);
if isempty(run_index) || ~isfile(runs.wavefield_sample_path(run_index))
    error("reqml:AnalyticPlaneSphericalSampleNotFound", ...
        "Completed wavefield sample was not found for %s.", design_id);
end
sample_file = runs.wavefield_sample_path(run_index);
prediction = reqml.predictSWS(sample_file, Model=model_file, M=config.M, ...
    StepPixels=config.step_pixels, UseParallel=use_parallel);
data = reqml.io.load_wavefield_sample(sample_file);
row = design(design.design_id==design_id,:);

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

source_xyz = [NaN NaN NaN];
if row.propagation_model == "spherical_wave"
    source_xyz = actual_source_xyz(data);
    expected = [row.source_x_m row.source_y_m row.source_z_m];
    if norm(source_xyz-expected) > 5e-7
        error("reqml:AnalyticSphericalSourceMismatch", ...
            "Resolved source for %s does not match the designed source.", ...
            design_id);
    end
end
distance_from_source_m = nan(height(patch_examples),1);
if all(isfinite(source_xyz))
    distance_from_source_m = sqrt( ...
        (double(patch_examples.x_center_m)-source_xyz(1)).^2 + ...
        (double(patch_examples.z_center_m)-source_xyz(3)).^2 + ...
        source_xyz(2).^2);
end
window_side_m = (double(prediction.metadata.patch_width_pixels)-1) * ...
    max(data.dx_m, data.dz_m);
curvature_ratio = window_side_m ./ distance_from_source_m;

metadata = struct();
metadata.design = table2struct(row);
metadata.sample_file = sample_file;
metadata.resolved_config_path = runs.resolved_config_path(run_index);
metadata.framework_commit = framework_commit;
metadata.reqml_commit = reqml_commit;
metadata.model = prediction.metadata;
metadata.model_resolution = model_resolution.source;
metadata.actual_source_xyz_m = source_xyz;
metadata.nominal_center_propagation_direction_xyz = ...
    [row.direction_x row.direction_y row.direction_z];
metadata.window_side_definition = ...
    "(patch_width_pixels - 1) * max(dx_m,dz_m)";
metadata.window_side_m = window_side_m;
metadata.simulation_provenance = data.provenance;
metadata.simulation_sources = data.sources;

wavefield_zx = data.wavefield_zx;
wavefield_x_mm = 1e3*data.axes.x_m(:)';
wavefield_z_mm = 1e3*data.axes.z_m(:);
save(result_file, "cs_pred_map", "q_map", "valid_mask", ...
    "cs_truth_map", "signed_error_percent", "absolute_error_percent", ...
    "x_mm", "z_mm", "patch_predictions", "patch_examples", ...
    "distance_from_source_m", "curvature_ratio", "wavefield_zx", ...
    "wavefield_x_mm", "wavefield_z_mm", "metadata", "-v7.3");
end

function make_all_figures(case_data, design, paths, config)
for index = 1:height(design)
    make_per_case_figure(design.design_id(index), paths);
end
cs_values = unique(design.cs_true_m_s);
orientations = unique(design.orientation, "stable");
for cs_index = 1:numel(cs_values)
    for orientation_index = 1:numel(orientations)
        selector = design.cs_true_m_s==cs_values(cs_index) & ...
            design.orientation==orientations(orientation_index);
        group = case_data(selector);
        tag = "cs" + compose("%g",cs_values(cs_index)) + "_" + ...
            orientations(orientation_index);
        make_matched_figure(group, fullfile(paths.figures_directory, ...
            tag + "_matched_maps.png"));
        make_distance_figure(group, fullfile(paths.figures_directory, ...
            tag + "_distance_from_source.png"));
        make_spectral_figure(group, config, fullfile( ...
            paths.figures_directory, tag + "_local_spectra.png"));
    end
end
make_curvature_figure(case_data, fullfile(paths.figures_directory, ...
    "curvature_ratio_error.png"));
end

function make_per_case_figure(design_id, paths)
result_file = fullfile(paths.cases_directory, design_id, "result.mat");
if ~isfile(result_file)
    return
end
s = load(result_file);
figure_file = fullfile(paths.figures_directory, design_id + "_diagnostic.png");
f = figure(Visible="off",Color="w",Position=[50 50 1800 950]);
cleanup = onCleanup(@() close(f));
tiledlayout(2,3,Padding="compact",TileSpacing="compact");
nexttile; imagesc(s.wavefield_x_mm,s.wavefield_z_mm,abs(s.wavefield_zx));
axis image; set(gca,YDir="normal"); colorbar; title("|U|"); xlabel("x (mm)"); ylabel("z (mm)");
nexttile; imagesc(s.wavefield_x_mm,s.wavefield_z_mm,angle(s.wavefield_zx));
axis image; set(gca,YDir="normal"); colorbar; clim([-pi pi]); title("phase(U) (rad)");
cs_limits = finite_limits([s.cs_truth_map(:);s.cs_pred_map(:)], ...
    double(s.metadata.design.cs_true_m_s));
nexttile; imagesc(s.x_mm,s.z_mm,s.cs_truth_map); axis image; set(gca,YDir="normal");
colorbar; clim(cs_limits); title("truth SWS (m/s)");
nexttile; imagesc(s.x_mm,s.z_mm,s.cs_pred_map); axis image; set(gca,YDir="normal");
colorbar; clim(cs_limits); title("Frozen Q0 SWS (m/s)"); xlabel("x (mm)"); ylabel("z (mm)");
nexttile; imagesc(s.x_mm,s.z_mm,s.q_map); axis image; set(gca,YDir="normal");
colorbar; clim([0 1]); title("predicted q"); xlabel("x (mm)");
nexttile; imagesc(s.x_mm,s.z_mm,s.signed_error_percent); axis image; set(gca,YDir="normal");
colorbar; error_limit=max(5,prctile(abs(s.signed_error_percent(:)),99));
if ~isfinite(error_limit), error_limit=5; end
clim([-error_limit error_limit]); colormap(gca,diverging_map());
title("signed error (%)"); xlabel("x (mm)");
sgtitle(strrep(design_id,"_"," "));
exportgraphics(f,figure_file,Resolution=180);
clear cleanup
end

function make_matched_figure(group, figure_file)
group = order_group(group);
all_cs = vertcat(group.cs_pred_map);
truth = group(1).metadata.design.cs_true_m_s;
cs_limits = finite_limits([all_cs(:);truth],truth);
error_limit = 5;
for index=1:3
    error_limit=max(error_limit,prctile(abs(group(index).signed_error_percent(:)),99));
end
f=figure(Visible="off",Color="w",Position=[50 50 1500 850]);
cleanup=onCleanup(@() close(f));
tiledlayout(2,3,Padding="compact",TileSpacing="compact");
for index=1:3
    nexttile(index); imagesc(group(index).x_mm,group(index).z_mm,group(index).cs_pred_map);
    axis image; set(gca,YDir="normal"); clim(cs_limits); colorbar;
    title(strrep(group(index).metadata.design.propagation_condition,"_"," "));
    if index==1, ylabel("SWS; z (mm)"); end
end
for index=1:3
    nexttile(index+3); imagesc(group(index).x_mm,group(index).z_mm,group(index).signed_error_percent);
    axis image; set(gca,YDir="normal"); clim([-error_limit error_limit]); colorbar;
    colormap(gca,diverging_map()); xlabel("x (mm)");
    if index==1, ylabel("error; z (mm)"); end
end
sgtitle(sprintf("cs=%.1f m/s; %s",truth, ...
    strrep(group(1).metadata.design.orientation,"_"," ")));
exportgraphics(f,figure_file,Resolution=180); clear cleanup
end

function make_distance_figure(group, figure_file)
group=order_group(group); spherical=group(2:3);
distances=vertcat(spherical.distance_from_source_m);
edges=linspace(min(distances),max(distances),8);
colors=[0.15 0.45 0.8;0.85 0.25 0.1];
f=figure(Visible="off",Color="w",Position=[50 50 1500 480]);
cleanup=onCleanup(@() close(f)); tiledlayout(1,3,Padding="compact");
labels=["SWS (m/s)","q","signed error (%)"];
for panel=1:3
    nexttile; hold on;
    for index=1:2
        values=patch_values(spherical(index),panel);
        [centers,med,q1,q3]=binned_summary(spherical(index).distance_from_source_m,values,edges);
        fill([centers;flipud(centers)]*1e3,[q1;flipud(q3)],colors(index,:), ...
            FaceAlpha=0.15,EdgeColor="none");
        plot(centers*1e3,med,LineWidth=2,Color=colors(index,:));
    end
    grid on; xlabel("distance from source R (mm)"); ylabel(labels(panel));
    if panel==1
        legend("nospread IQR","nospread median","spread IQR", ...
            "spread median",Location="best");
    end
end
sgtitle(sprintf("cs=%.1f m/s; %s", ...
    group(1).metadata.design.cs_true_m_s,group(1).metadata.design.orientation));
exportgraphics(f,figure_file,Resolution=180); clear cleanup
end

function make_curvature_figure(case_data, figure_file)
f=figure(Visible="off",Color="w",Position=[50 50 1400 900]);
cleanup=onCleanup(@() close(f)); tiledlayout(2,2,Padding="compact");
cs_values=unique(arrayfun(@(s)s.metadata.design.cs_true_m_s,case_data));
orientations=unique(string(arrayfun(@(s)s.metadata.design.orientation, ...
    case_data,UniformOutput=false)),"stable");
panel=0;
for cs_index=1:numel(cs_values)
    c=cs_values(cs_index);
    for orientation_index=1:numel(orientations)
        orientation=orientations(orientation_index);
        panel=panel+1; nexttile; hold on;
        selector=arrayfun(@(s)s.metadata.design.cs_true_m_s==c && ...
            string(s.metadata.design.orientation)==orientation && ...
            string(s.metadata.design.propagation_model)=="spherical_wave",case_data);
        subset=case_data(selector);
        subset_names=string(arrayfun(@(s) ...
            s.metadata.design.propagation_condition,subset, ...
            UniformOutput=false));
        subset=subset([find(subset_names=="spherical_nospread",1), ...
            find(subset_names=="spherical_spread",1)]);
        colors=[0.15 0.45 0.8;0.85 0.25 0.1];
        for index=1:2
            x=subset(index).curvature_ratio;
            y=patch_values(subset(index),3);
            edges=linspace(min(x),max(x),8);
            [centers,med,q1,q3]=binned_summary(x,y,edges);
            fill([centers;flipud(centers)],[q1;flipud(q3)],colors(index,:), ...
                FaceAlpha=.15,EdgeColor="none");
            plot(centers,med,LineWidth=2,Color=colors(index,:));
        end
        yline(0,"k--"); grid on; xlabel("L_{win}/R"); ylabel("signed error (%)");
        title(sprintf("cs=%.1f; %s",c,orientation));
    end
end
sgtitle("Curvature ratio using L_{win}=(N_{win}-1) max(dx,dz)");
exportgraphics(f,figure_file,Resolution=180); clear cleanup
end

function make_spectral_figure(group, config, figure_file)
group=order_group(group); reference=group(2);
valid=find(isfinite(reference.distance_from_source_m) & ...
    reference.patch_predictions.sws_valid);
[~,order]=sort(reference.distance_from_source_m(valid)); valid=valid(order);
positions=round([.1 .5 .9]*(numel(valid)-1)+1);
chosen=valid(positions); labels=["near","mid","far"];
colors=[0.1 0.1 0.1;0.15 0.45 0.8;0.85 0.25 0.1];
f=figure(Visible="off",Color="w",Position=[50 50 1500 1100]);
cleanup=onCleanup(@() close(f)); tiledlayout(3,2,Padding="compact");
for row=1:3
    center_x=reference.patch_examples.x_center_m(chosen(row));
    center_z=reference.patch_examples.z_center_m(chosen(row));
    nexttile; hold on;
    for index=1:3
        patch_index=nearest_patch(group(index),center_x,center_z);
        mapping=group(index).patch_examples.req_mapping{patch_index};
        [k,p]=radial_increment(mapping);
        plot(k,p,LineWidth=1.8,Color=colors(index,:));
        kq=group(index).patch_predictions.k_pred_rad_m(patch_index);
        xline(kq,":",Color=colors(index,:),HandleVisibility="off");
    end
    true_k=2*pi*double(config.frequency_hz)/ ...
        reference.metadata.design.cs_true_m_s;
    xline(true_k,"k--","true k"); grid on; xlim(spectral_xlim(group,chosen(row)));
    ylabel("normalized P(k)"); title(labels(row)+" radial energy");
    if row==1, legend("plane","curvature","spreading","true k",Location="best"); end
    nexttile; hold on;
    for index=1:3
        patch_index=nearest_patch(group(index),center_x,center_z);
        mapping=group(index).patch_examples.req_mapping{patch_index};
        plot(double(mapping.k_cent),double(mapping.Ecum),LineWidth=1.8,Color=colors(index,:));
        q=group(index).patch_predictions.q_pred(patch_index);
        yline(q,":",Color=colors(index,:),HandleVisibility="off");
    end
    xline(true_k,"k--","true k"); grid on; ylim([0 1]);
    xlim(spectral_xlim(group,chosen(row))); ylabel("E_{cum}(k)");
    title(labels(row)+" cumulative energy");
end
xlabel(tiledlayout_handle(f),"wavenumber k (rad/m)");
sgtitle(sprintf("Local spectra: cs=%.1f m/s; %s", ...
    reference.metadata.design.cs_true_m_s,reference.metadata.design.orientation));
exportgraphics(f,figure_file,Resolution=180); clear cleanup
end

function handle=tiledlayout_handle(f)
handle=findobj(f,Type="tiledlayout");
end

function x_limits=spectral_xlim(group,reference_index)
kmax=0;
for index=1:3
    mapping=group(index).patch_examples.req_mapping{min(reference_index, ...
        height(group(index).patch_examples))};
    p=diff([0;double(mapping.Ecum(:))]);
    cumulative=cumsum(max(p,0)); cumulative=cumulative/max(cumulative(end),eps);
    qindex=find(cumulative>=.995,1);
    if ~isempty(qindex), kmax=max(kmax,double(mapping.k_cent(qindex))); end
end
x_limits=[0 max(1,1.15*kmax)];
end

function [k,p]=radial_increment(mapping)
k=double(mapping.k_cent(:));
p=max(0,diff([0;double(mapping.Ecum(:))]));
p=p/max(sum(p),eps);
end

function index=nearest_patch(value,x,z)
distance=(double(value.patch_examples.x_center_m)-double(x)).^2 + ...
    (double(value.patch_examples.z_center_m)-double(z)).^2;
[~,index]=min(distance);
end

function values=patch_values(value,kind)
switch kind
    case 1, values=double(value.patch_predictions.cs_pred_m_s);
    case 2, values=double(value.patch_predictions.q_pred);
    case 3
        truth=double(value.metadata.design.cs_true_m_s);
        values=100*(double(value.patch_predictions.cs_pred_m_s)-truth)/truth;
end
end

function [centers,med,q1,q3]=binned_summary(x,y,edges)
x=double(x(:)); y=double(y(:)); bins=discretize(x,edges);
centers=(edges(1:end-1)+edges(2:end))'/2; n=numel(centers);
med=nan(n,1);q1=med;q3=med;
for index=1:n
    values=y(bins==index & isfinite(y));
    if ~isempty(values)
        med(index)=median(values); q1(index)=prctile(values,25); q3(index)=prctile(values,75);
    end
end
end

function summary=build_summary(case_data,design,config,framework_commit,reqml_commit)
rows=repmat(struct(),height(design),1);
for index=1:height(design)
    value=case_data(index); valid=value.valid_mask;
    predicted=value.cs_pred_map(valid); truth=value.cs_truth_map(valid);
    error_pct=value.signed_error_percent(valid);
    d=value.metadata.design;
    rows(index).design_id=string(d.design_id);
    rows(index).cs_true_m_s=double(d.cs_true_m_s);
    rows(index).frequency_hz=double(config.frequency_hz);
    rows(index).orientation=string(d.orientation);
    rows(index).propagation_condition=string(d.propagation_condition);
    rows(index).geometric_decay_exponent=double(d.geometric_decay_exponent);
    rows(index).source_radius_m=double(d.source_radius_m);
    rows(index).source_x_m=double(d.source_x_m);
    rows(index).source_z_m=double(d.source_z_m);
    rows(index).patch_count=numel(valid);
    rows(index).valid_patch_count=nnz(valid);
    rows(index).invalid_fraction=1-nnz(valid)/numel(valid);
    rows(index).mean_predicted_cs_m_s=mean(predicted);
    rows(index).median_predicted_cs_m_s=median(predicted);
    rows(index).RMSE_m_s=sqrt(mean((predicted-truth).^2));
    rows(index).MAPE_percent=mean(abs(error_pct));
    rows(index).bias_percent=mean(error_pct);
    rows(index).median_absolute_error_percent=median(abs(error_pct));
    rows(index).simulation_framework_commit=framework_commit;
    rows(index).reqml_commit=reqml_commit;
    rows(index).model_provenance_id=string(value.metadata.model.model_provenance_id);
end
summary=struct2table(rows);
end

function write_text_summary(path_value,summary)
file_id=fopen(path_value,"w");
if file_id<0, error("reqml:DiagnosticSummaryWriteFailed","Cannot write %s",path_value); end
cleanup=onCleanup(@() fclose(file_id));
fprintf(file_id,"Analytic plane/spherical Frozen Q0 diagnostic\n\n");
fprintf(file_id,"All differences below are measured, not causal conclusions.\n");
cs_values=unique(summary.cs_true_m_s); orientations=unique(summary.orientation,"stable");
for cs_index=1:numel(cs_values)
    cs=cs_values(cs_index);
    fprintf(file_id,"\ncs = %.1f m/s\n",cs);
    for orientation_index=1:numel(orientations)
        orientation=orientations(orientation_index);
        base=summary(summary.cs_true_m_s==cs & summary.orientation==orientation,:);
        plane=base(base.propagation_condition=="plane",:);
        curve=base(base.propagation_condition=="spherical_nospread",:);
        spread=base(base.propagation_condition=="spherical_spread",:);
        fprintf(file_id,"  %s\n",orientation);
        print_delta(file_id,"curvature - plane",curve,plane);
        print_delta(file_id,"spreading - curvature",spread,curve);
    end
end
fprintf(file_id,"\nOrientation effect for plane waves (diagonal - horizontal):\n");
for cs_index=1:numel(cs_values)
    cs=cs_values(cs_index);
    horizontal=summary(summary.cs_true_m_s==cs & summary.orientation=="horizontal" & ...
        summary.propagation_condition=="plane",:);
    diagonal=summary(summary.cs_true_m_s==cs & summary.orientation=="diagonal" & ...
        summary.propagation_condition=="plane",:);
    fprintf(file_id,"  cs %.1f: ",cs); print_delta(file_id,"diagonal - horizontal",diagonal,horizontal);
end
clear cleanup
end

function print_delta(file_id,label,a,b)
fprintf(file_id,"    %s: dMAPE=%+.4f pp, dBias=%+.4f pp, dMedianSWS=%+.5f m/s, dInvalid=%+.6f\n", ...
    label,a.MAPE_percent-b.MAPE_percent,a.bias_percent-b.bias_percent, ...
    a.median_predicted_cs_m_s-b.median_predicted_cs_m_s, ...
    a.invalid_fraction-b.invalid_fraction);
end

function data=load_all_case_results(design,paths)
first_file=fullfile(paths.cases_directory,design.design_id(1),"result.mat");
if ~isfile(first_file)
    error("reqml:DiagnosticResultMissing","Missing result: %s",first_file);
end
first=load(first_file);
data=repmat(first,height(design),1);
for index=2:height(design)
    file=fullfile(paths.cases_directory,design.design_id(index),"result.mat");
    if ~isfile(file), error("reqml:DiagnosticResultMissing","Missing result: %s",file); end
    data(index)=orderfields(load(file),first);
end
end

function group=order_group(group)
names=string(arrayfun(@(s)s.metadata.design.propagation_condition,group,UniformOutput=false));
order=zeros(3,1); wanted=["plane","spherical_nospread","spherical_spread"];
for index=1:3, order(index)=find(names==wanted(index),1); end
group=group(order);
end

function source=actual_source_xyz(data)
required=["x_m","y_m","z_m","radius_m"];
if ~all(isfield(data.sources,cellstr(required)))
    error("reqml:MissingSphericalSourceMetadata","Sample has no spherical source metadata.");
end
source=[double(data.sources.x_m(1)),double(data.sources.y_m(1)), ...
    double(data.sources.z_m(1))];
end

function validate_resolved_pair(runs,design,config)
if numel(runs)~=12 || height(design)~=12
    error("reqml:AnalyticPlaneSphericalDesignCount","Expected exactly 12 runs.");
end
indices=[find(design.propagation_model=="plane",1), ...
    find(design.propagation_model=="spherical_wave",1)];
for index=indices
    cfg=runs(index).config; row=design(index,:);
    assert(abs(cfg.medium.background_cs_m_s-row.cs_true_m_s)<eps);
    assert(abs(cfg.wavefield.frequency_hz-config.frequency_hz)<eps);
    assert(string(cfg.propagation.model)==row.propagation_model);
    assert(abs(cfg.sources.radius_range_m(1)-.05)<eps);
    assert(abs(cfg.sources.radius_range_m(2)-.05)<eps);
    assert(cfg.amplitude.geometric_decay_exponent==row.geometric_decay_exponent);
    actual=double(cfg.directions.explicit_xyz(:)');
    expected=[row.explicit_x row.explicit_y row.explicit_z];
    assert(norm(actual-expected)<1e-12);
end
end

function verify_smoke_outputs(design_id,paths)
result_file=fullfile(paths.cases_directory,design_id,"result.mat");
figure_file=fullfile(paths.figures_directory,design_id+"_diagnostic.png");
if ~isfile(result_file) || ~isfile(figure_file)
    error("reqml:AnalyticPlaneSphericalSmokeFailed", ...
        "Smoke did not produce its result MAT and diagnostic figure.");
end
value=load(result_file,"cs_pred_map","q_map","valid_mask", ...
    "signed_error_percent");
if ~isequal(size(value.cs_pred_map),size(value.q_map), ...
        size(value.valid_mask),size(value.signed_error_percent)) || ...
        ~any(value.valid_mask,"all")
    error("reqml:AnalyticPlaneSphericalSmokeFailed", ...
        "Smoke maps are inconsistent or contain no valid predictions.");
end
end

function write_manifest(path_value,config,paths,framework_commit,reqml_commit, ...
        model_file,model_resolution,summary)
manifest=struct("schema_name","reqml_analytic_plane_spherical_q0_results", ...
    "schema_version","1.0","diagnostic_id",string(config.diagnostic_id), ...
    "created_utc",string(datetime("now",TimeZone="UTC")), ...
    "run_count",height(summary),"simulation_framework_commit",framework_commit, ...
    "reqml_commit",reqml_commit,"model_file",string(model_file), ...
    "model_resolution",string(model_resolution.source), ...
    "campaign_file",paths.campaign_file,"summary_csv",paths.summary_csv, ...
    "simulation_or_training","12 clean swsynth simulations; no training");
write_json(path_value,manifest);
end

function report=final_report(paths,table_value,framework_commit,reqml_commit,model_file,smoke_only)
report=struct("output_directory",paths.root,"summary_csv",paths.summary_csv, ...
    "figures_directory",paths.figures_directory,"framework_commit",framework_commit, ...
    "reqml_commit",reqml_commit,"model_file",string(model_file), ...
    "smoke_only",smoke_only,"rows",height(table_value));
end

function paths=output_paths(root)
paths=struct(); paths.root=string(root);
paths.batch_directory=fullfile(root,"batch");
paths.campaign_file=fullfile(paths.batch_directory, ...
    "simulation_campaign_analytic_plane_spherical_q0_v1.json");
paths.cases_directory=fullfile(root,"cases");
paths.figures_directory=fullfile(root,"figures");
paths.design_csv=fullfile(root,"design_table.csv");
paths.design_json=fullfile(root,"design_table.json");
paths.summary_csv=fullfile(root,"summary.csv");
paths.readme=fullfile(root,"README.txt");
paths.manifest=fullfile(root,"manifest.json");
end

function ensure_directories(paths)
directories=[paths.root,paths.batch_directory,paths.cases_directory,paths.figures_directory];
for directory=directories
    if ~isfolder(directory), mkdir(directory); end
end
end

function path_value=campaign_csv_path(simulation_output,diagnostic_id)
path_value=fullfile(simulation_output,string(diagnostic_id),"campaign_runs.csv");
end

function value=resolve_path(value,repository_root)
value=replace(string(value),"${REPOSITORY_ROOT}",string(repository_root));
end

function commit=git_commit(root)
[status,output]=system(sprintf('git -C "%s" rev-parse HEAD',root));
if status~=0, error("reqml:GitCommitUnavailable","Could not resolve commit for %s",root); end
commit=strtrim(string(output));
end

function write_json(path_value,value)
file_id=fopen(path_value,"w");
if file_id<0, error("reqml:DiagnosticJsonWriteFailed","Cannot write %s",path_value); end
cleanup=onCleanup(@() fclose(file_id));
fprintf(file_id,"%s",jsonencode(value,PrettyPrint=true)); clear cleanup
end

function tf=contains_path(path_value)
tf=any(string(strsplit(path,pathsep))==string(path_value));
end

function restore_path(path_value,was_added)
if was_added, rmpath(path_value); rehash; end
end

function limits=finite_limits(values,truth)
values=values(isfinite(values));
if isempty(values), limits=[.5*truth 1.5*truth]; return; end
padding=max(.05,.05*(max(values)-min(values)+eps));
limits=[min(values)-padding,max(values)+padding];
if diff(limits)<.1, limits=truth+[-.1 .1]; end
end

function map=diverging_map()
n=256; half=n/2;
map=[linspace(0.1,1,half)',linspace(0.3,1,half)',ones(half,1); ...
    ones(half,1),linspace(1,0.2,half)',linspace(1,0.1,half)'];
end
