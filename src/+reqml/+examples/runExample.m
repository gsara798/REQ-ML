function output = runExample(geometry, options)
%RUNEXAMPLE Run one public REQ Q0 simulation-to-SWS example.
%
% output = reqml.examples.runExample("homogeneous")
% output = reqml.examples.runExample("inclusion", Verbose=true)
%
% The simulation backend generates the wavefield. REQ-ML then estimates
% the local SWS map using the released REQ Q0 model.

arguments
    geometry {mustBeTextScalar}

    options.Cs (1,1) double {mustBePositive} = 2
    options.CsBackground (1,1) double {mustBePositive} = 2
    options.CsInclusion (1,1) double {mustBePositive} = 3
    options.InclusionRadiusMm (1,1) double {mustBePositive} = 15

    options.FrequencyHz (1,1) double {mustBePositive} = 400
    options.FieldRegime {mustBeTextScalar} = "directional"
    options.M (1,1) double {mustBeMember(options.M,[2 3])} = 2

    % Controls sampling density of overlapping REQ windows.
    % This does not change the physical REQ window size.
    options.StepPixels (1,1) double ...
        {mustBeInteger,mustBePositive} = 4

    options.Verbose (1,1) logical = true
    options.SaveFigure (1,1) logical = true
    options.ShowFigure (1,1) logical = false
    options.OutputDirectory {mustBeTextScalar} = ""
end

geometry = lower(string(geometry));

if ~ismember(geometry, ["homogeneous","inclusion"])
    error("reqml:UnknownExampleGeometry", ...
        "Geometry must be homogeneous or inclusion.");
end

function_root = fileparts(mfilename("fullpath"));
reqml_root = fileparts(fileparts(fileparts(function_root)));

simulation_root = string(getenv("SWSIM_ROOT"));
if strlength(simulation_root) == 0
    simulation_root = fullfile( ...
        fileparts(reqml_root), ...
        "shear-wave-simulation-framework");
end

if ~isfolder(fullfile(simulation_root,"src"))
    error("reqml:SimulationFrameworkNotFound", ...
        ["The shear-wave-simulation-framework was not found. " + ...
         "Place it beside REQ-ML or set SWSIM_ROOT."]);
end

addpath(fullfile(simulation_root,"src"));

output_root = string(options.OutputDirectory);
if strlength(output_root) == 0
    output_root = fullfile(reqml_root,"outputs","examples");
end

if ~isfolder(output_root)
    mkdir(output_root);
end

%% Describe case
if options.Verbose
    fprintf("\nREQ Q0 example: %s\n", geometry);

    if geometry == "homogeneous"
        fprintf("  Medium\n");
        fprintf("    SWS             : %.2f m/s\n", options.Cs);
    else
        fprintf("  Medium\n");
        fprintf("    Background SWS  : %.2f m/s\n", ...
            options.CsBackground);
        fprintf("    Inclusion SWS   : %.2f m/s\n", ...
            options.CsInclusion);
        fprintf("    Inclusion radius: %.1f mm\n", ...
            options.InclusionRadiusMm);
    end

    fprintf("  Wavefield\n");
    fprintf("    Frequency       : %.0f Hz\n", ...
        options.FrequencyHz);
    fprintf("    Field regime    : %s\n", ...
        string(options.FieldRegime));

    fprintf("  REQ\n");
    fprintf("    M               : %d\n", options.M);
    fprintf("    Step            : %d pixels\n", ...
        options.StepPixels);
end

%% Build simulation
if options.Verbose
    fprintf("\n  [1/3] Building simulation configuration...\n");
end

campaign_file = fullfile( ...
    output_root, ...
    geometry + "_campaign.json");

if geometry == "homogeneous"
    campaign = reqml.examples.buildSimulationCampaign( ...
        geometry, ...
        OutputDirectory=output_root, ...
        Cs=options.Cs, ...
        FrequencyHz=options.FrequencyHz, ...
        FieldRegime=options.FieldRegime);
else
    campaign = reqml.examples.buildSimulationCampaign( ...
        geometry, ...
        OutputDirectory=output_root, ...
        CsBackground=options.CsBackground, ...
        CsInclusion=options.CsInclusion, ...
        InclusionRadiusMm=options.InclusionRadiusMm, ...
        FrequencyHz=options.FrequencyHz, ...
        FieldRegime=options.FieldRegime);
end

reqml.examples.writeCampaignJson(campaign_file,campaign);

%% Run simulation
if options.Verbose
    fprintf("  [2/3] Simulating wavefield...\n");
end

simulation_timer = tic;

report = simcampaigns.runCampaign( ...
    campaign_file, ...
    Resume=true, ...
    ContinueOnError=false);

simulation_seconds = toc(simulation_timer);

sample_file = fullfile( ...
    report.runs(1).run_directory, ...
    "data", ...
    "wavefield_sample.mat");

if options.Verbose
    fprintf("        completed in %.2f s\n",simulation_seconds);
    fprintf("        sample: %s\n",sample_file);
end

wavefield = reqml.io.load_wavefield_sample(sample_file);

%% Run REQ
if options.Verbose
    fprintf("  [3/3] Estimating SWS with REQ Q0 model...\n");
end

prediction_timer = tic;

result = reqml.predictSWS( ...
    sample_file, ...
    M=options.M, ...
    StepPixels=options.StepPixels);

prediction_seconds = toc(prediction_timer);

if options.Verbose
    fprintf("        completed in %.2f s\n",prediction_seconds);
end

%% Metrics
metrics = compute_metrics(geometry,result,options);

if options.Verbose
    print_metrics(geometry,metrics);
end

%% Figures
wavefield_figure_files = create_wavefield_figures( ...
    wavefield, ...
    geometry, ...
    options, ...
    output_root);

figure_file = "";

visibility = "off";
if options.ShowFigure
    visibility = "on";
end

fig = figure("Visible",visibility);

imagesc(result.x_mm,result.z_mm,result.cs_map);
axis image;
xlabel("x (mm)");
ylabel("z (mm)");
cb = colorbar;
ylabel(cb,"SWS (m/s)");

if geometry == "homogeneous"
    title(sprintf( ...
        "REQ Q0 homogeneous SWS, M=%d", ...
        options.M));

    clim([options.Cs-0.5 options.Cs+0.5]);
else
    title(sprintf( ...
        "REQ Q0 inclusion SWS, M=%d", ...
        options.M));

    clim([ ...
        min(options.CsBackground,options.CsInclusion)-0.25, ...
        max(options.CsBackground,options.CsInclusion)+0.25]);

    hold on;

    center_mm = [40 40];
    theta = linspace(0,2*pi,400);

    plot( ...
        center_mm(1) + ...
            options.InclusionRadiusMm*cos(theta), ...
        center_mm(2) + ...
            options.InclusionRadiusMm*sin(theta), ...
        "w--", ...
        LineWidth=1.2);

    hold off;
end

if options.SaveFigure
    figure_dir = fullfile(output_root,"figures");

    if ~isfolder(figure_dir)
        mkdir(figure_dir);
    end

    figure_file = fullfile( ...
        figure_dir, ...
        geometry + "_sws.png");

    exportgraphics(fig,figure_file,Resolution=180);

    if options.Verbose
        fprintf("  Figure saved: %s\n",figure_file);
    end
end

if ~options.ShowFigure
    close(fig);
end

%% Return
output = struct();

output.geometry = geometry;
output.result = result;
output.metrics = metrics;
output.sample_file = string(sample_file);
output.figure_file = string(figure_file);
output.wavefield_figure_files = wavefield_figure_files;

output.runtime = struct( ...
    "simulation_seconds",simulation_seconds, ...
    "prediction_seconds",prediction_seconds);

end


function files = create_wavefield_figures( ...
        wavefield,geometry,options,output_root)

U = wavefield.wavefield_zx;

x_mm = 1e3*wavefield.axes.x_m;
z_mm = 1e3*wavefield.axes.z_m;

amplitude = abs(U);
phase = angle(U);
real_part = real(U);

files = struct( ...
    "amplitude","", ...
    "phase","", ...
    "real","");

visibility = "off";
if options.ShowFigure
    visibility = "on";
end

figure_dir = fullfile(output_root,"figures");

if options.SaveFigure && ~isfolder(figure_dir)
    mkdir(figure_dir);
end

component_label = string(wavefield.component);
quantity_label = string(wavefield.quantity);

%% Amplitude
fig = figure("Visible",visibility);

imagesc(x_mm,z_mm,amplitude);
axis image;
xlabel("x (mm)");
ylabel("z (mm)");

cb = colorbar;
ylabel(cb,"|U|");

title(sprintf( ...
    "%s %s %s amplitude, %.0f Hz", ...
    upper_first(geometry), ...
    quantity_label, ...
    component_label, ...
    options.FrequencyHz));

overlay_geometry(geometry,options);

if options.SaveFigure
    files.amplitude = fullfile( ...
        figure_dir, ...
        geometry+"_amplitude.png");

    exportgraphics(fig,files.amplitude,Resolution=180);
end

if ~options.ShowFigure
    close(fig);
end

%% Phase
fig = figure("Visible",visibility);

imagesc(x_mm,z_mm,phase);
axis image;
xlabel("x (mm)");
ylabel("z (mm)");

cb = colorbar;
ylabel(cb,"Phase (rad)");

clim([-pi pi]);

title(sprintf( ...
    "%s %s %s phase, %.0f Hz", ...
    upper_first(geometry), ...
    quantity_label, ...
    component_label, ...
    options.FrequencyHz));

overlay_geometry(geometry,options);

if options.SaveFigure
    files.phase = fullfile( ...
        figure_dir, ...
        geometry+"_phase.png");

    exportgraphics(fig,files.phase,Resolution=180);
end

if ~options.ShowFigure
    close(fig);
end

%% Real part
fig = figure("Visible",visibility);

imagesc(x_mm,z_mm,real_part);
axis image;
xlabel("x (mm)");
ylabel("z (mm)");

cb = colorbar;
ylabel(cb,"Re(U)");

limit = max(abs(real_part),[],"all");

if isfinite(limit) && limit > 0
    clim([-limit limit]);
end

title(sprintf( ...
    "%s real(%s %s), %.0f Hz", ...
    upper_first(geometry), ...
    quantity_label, ...
    component_label, ...
    options.FrequencyHz));

overlay_geometry(geometry,options);

if options.SaveFigure
    files.real = fullfile( ...
        figure_dir, ...
        geometry+"_real.png");

    exportgraphics(fig,files.real,Resolution=180);
end

if ~options.ShowFigure
    close(fig);
end

if options.Verbose && options.SaveFigure
    fprintf("\n  Wavefield figures\n");
    fprintf("    amplitude       : %s\n",files.amplitude);
    fprintf("    phase           : %s\n",files.phase);
    fprintf("    real(U)         : %s\n",files.real);
end

end


function overlay_geometry(geometry,options)

if geometry ~= "inclusion"
    return
end

hold on;

center_mm = [40 40];
theta = linspace(0,2*pi,400);

plot( ...
    center_mm(1) + options.InclusionRadiusMm*cos(theta), ...
    center_mm(2) + options.InclusionRadiusMm*sin(theta), ...
    "w--", ...
    LineWidth=1.1);

hold off;

end


function value = upper_first(value)

value = char(string(value));

if isempty(value)
    value = "";
    return
end

value = string([upper(value(1)) value(2:end)]);

end


function metrics = compute_metrics(geometry,result,options)

valid = result.valid_mask;

metrics = struct();
metrics.valid_fraction = mean(valid(:));

if geometry == "homogeneous"

    values = result.cs_map(valid);

    metrics.truth_sws_m_s = options.Cs;
    metrics.mean_sws_m_s = mean(values,"omitnan");
    metrics.median_sws_m_s = median(values,"omitnan");

    metrics.mape_pct = ...
        mean( ...
        abs(values-options.Cs)/options.Cs, ...
        "omitnan") * 100;

    return
end

[Xmm,Zmm] = meshgrid(result.x_mm,result.z_mm);

center_mm = [40 40];
distance_mm = hypot( ...
    Xmm-center_mm(1), ...
    Zmm-center_mm(2));

% Exclude a conservative interface band.
interface_margin_mm = min(3, 0.25 * options.InclusionRadiusMm);

core_mask = ...
    distance_mm <= ...
    (options.InclusionRadiusMm-interface_margin_mm) & ...
    valid;

background_mask = ...
    distance_mm >= ...
    (options.InclusionRadiusMm+interface_margin_mm) & ...
    valid;

background_values = result.cs_map(background_mask);
core_values = result.cs_map(core_mask);

metrics.background = roi_metrics( ...
    background_values, ...
    options.CsBackground);

metrics.inclusion_core = roi_metrics( ...
    core_values, ...
    options.CsInclusion);

metrics.interface_margin_mm = interface_margin_mm;
metrics.background_patch_count = nnz(background_mask);
metrics.inclusion_core_patch_count = nnz(core_mask);

end


function metrics = roi_metrics(values,truth)

metrics = struct();

metrics.truth_sws_m_s = truth;
metrics.mean_sws_m_s = mean(values,"omitnan");
metrics.median_sws_m_s = median(values,"omitnan");
metrics.mape_pct = ...
    mean(abs(values-truth)/truth,"omitnan")*100;

end


function print_metrics(geometry,metrics)

fprintf("\n  Results\n");
fprintf("    valid fraction : %.4f\n", ...
    metrics.valid_fraction);

if geometry == "homogeneous"

    fprintf("    truth SWS      : %.4f m/s\n", ...
        metrics.truth_sws_m_s);
    fprintf("    median SWS     : %.4f m/s\n", ...
        metrics.median_sws_m_s);
    fprintf("    mean SWS       : %.4f m/s\n", ...
        metrics.mean_sws_m_s);
    fprintf("    MAPE           : %.3f %%\n", ...
        metrics.mape_pct);

else

    fprintf("    background ROI\n");
    fprintf("      truth SWS    : %.4f m/s\n", ...
        metrics.background.truth_sws_m_s);
    fprintf("      median SWS   : %.4f m/s\n", ...
        metrics.background.median_sws_m_s);
    fprintf("      mean SWS     : %.4f m/s\n", ...
        metrics.background.mean_sws_m_s);
    fprintf("      MAPE         : %.3f %%\n", ...
        metrics.background.mape_pct);

    fprintf("    inclusion-core ROI\n");
    fprintf("      truth SWS    : %.4f m/s\n", ...
        metrics.inclusion_core.truth_sws_m_s);
    fprintf("      median SWS   : %.4f m/s\n", ...
        metrics.inclusion_core.median_sws_m_s);
    fprintf("      mean SWS     : %.4f m/s\n", ...
        metrics.inclusion_core.mean_sws_m_s);
    fprintf("      MAPE         : %.3f %%\n", ...
        metrics.inclusion_core.mape_pct);

end

end
