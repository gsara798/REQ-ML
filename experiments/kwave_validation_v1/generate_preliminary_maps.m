function generate_preliminary_maps()

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));

sim_root = fullfile( ...
    repo_root, ...
    "outputs","validation","kwave_validation_v1", ...
    "simulations","preliminary");

out_root = fullfile( ...
    repo_root, ...
    "outputs","validation","kwave_validation_v1", ...
    "analysis","preliminary_maps_M2");

model_file = fullfile( ...
    repo_root, ...
    "outputs","homogeneous_cartesian_q0_v2", ...
    "training","final_frozen_q0_v2","model_bundle.mat");

assert(isfolder(sim_root), "Missing simulation root: %s", sim_root);
assert(isfile(model_file), "Missing model file: %s", model_file);

if ~isfolder(out_root)
    mkdir(out_root);
end

M = 2;
step_pixels = 2;

files = dir(fullfile(sim_root, "**", "wavefield_sample.mat"));
assert(~isempty(files), "No wavefield_sample.mat files found under %s", sim_root);

fprintf("\nGenerating preliminary k-Wave maps\n");
fprintf("==================================\n");
fprintf("Runs found : %d\n", numel(files));
fprintf("Model      : %s\n", model_file);
fprintf("M          : %d\n", M);
fprintf("StepPixels : %d\n\n", step_pixels);

summary_rows = cell(numel(files),1);

for i = 1:numel(files)

    sample_file = fullfile(files(i).folder, files(i).name);
    [run_id, geometry, campaign_name] = infer_run_metadata(sample_file);

    fprintf("[%02d/%02d] %s | %s\n", i, numel(files), geometry, run_id);

    run_out = fullfile(out_root, geometry, run_id);
    if ~isfolder(run_out)
        mkdir(run_out);
    end

    t0 = tic;
    data = reqml.io.load_wavefield_sample(sample_file);
    fprintf("    sample loaded in %.2f s\n", toc(t0));

    t1 = tic;
    pred = reqml.predictSWS( ...
        sample_file, ...
        Model=model_file, ...
        M=M, ...
        StepPixels=step_pixels);
    fprintf("    predictSWS finished in %.2f s\n", toc(t1));

    wavefield = double(data.wavefield_zx);
    amplitude = abs(wavefield);
    phase = angle(wavefield);

    [x_m, z_m] = resolve_axes(data, size(wavefield));
    xg_mm = double(pred.x_mm);
    zg_mm = double(pred.z_mm);
    sws_map = double(pred.cs_map);
    valid_map = logical(pred.valid_mask);
    sws_map(~valid_map) = NaN;

    % Save raw numeric outputs for later use
    save(fullfile(run_out, "maps.mat"), ...
        "sample_file", "geometry", "campaign_name", "run_id", ...
        "x_m", "z_m", "amplitude", "phase", ...
        "xg_mm", "zg_mm", "sws_map", "valid_map", "M", "step_pixels");

    % Separate figures
    save_single_map( ...
        x_m, z_m, amplitude, ...
        fullfile(run_out, "amplitude_map.png"), ...
        "Amplitude", "Amplitude (a.u.)", "turbo", [], false);

    save_single_map( ...
        x_m, z_m, phase, ...
        fullfile(run_out, "phase_map.png"), ...
        "Phase", "Phase (rad)", blue_red_map(256), [-pi pi], true);

    save_single_map( ...
        xg_mm*1e-3, zg_mm*1e-3, sws_map, ...
        fullfile(run_out, "sws_map.png"), ...
        sprintf("Predicted SWS (M=%d, step=%d)", M, step_pixels), ...
        "c_s (m/s)", "turbo", [], false);

    % Combined figure
    save_combined_figure( ...
        x_m, z_m, amplitude, phase, ...
        xg_mm*1e-3, zg_mm*1e-3, sws_map, ...
        fullfile(run_out, "overview.png"), ...
        sprintf("%s | %s", geometry, run_id), ...
        M, step_pixels);

    % Small summary
    T = pred.patch_examples;
    cs_pred = double(pred.patch_predictions.cs_pred_m_s);
    valid = logical(pred.patch_predictions.sws_valid);

    freq_hz = double(data.frequency_hz);

    summary_rows{i} = struct( ...
        "geometry", string(geometry), ...
        "campaign_name", string(campaign_name), ...
        "run_id", string(run_id), ...
        "sample_file", string(sample_file), ...
        "frequency_hz", freq_hz, ...
        "patch_count", height(T), ...
        "valid_patch_count", nnz(valid), ...
        "valid_fraction", nnz(valid)/height(T), ...
        "cs_pred_median_m_s", median(cs_pred(valid), "omitnan"), ...
        "cs_pred_mean_m_s", mean(cs_pred(valid), "omitnan"), ...
        "cs_pred_std_m_s", std(cs_pred(valid), 0, "omitnan"), ...
        "elapsed_s", toc(t0));

    fprintf("    done | patches=%d | median cs=%.3f m/s | total %.2f s\n\n", ...
        height(T), median(cs_pred(valid),"omitnan"), toc(t0));
end

summary = struct2table(vertcat(summary_rows{:}));
writetable(summary, fullfile(out_root, "run_summary.csv"));

fprintf("All done.\n");
fprintf("Output root:\n  %s\n", out_root);

end


function [run_id, geometry, campaign_name] = infer_run_metadata(sample_file)

sample_file = string(sample_file);
parts = split(sample_file, filesep);

run_id = "";
geometry = "";
campaign_name = "";

for i = 1:numel(parts)
    token = string(parts(i));

    if startsWith(token, "run_")
        run_id = token;
    end

    if token == "homogeneous" || token == "bilayer" || token == "inclusion"
        geometry = token;
    end

    if contains(token, "kwave_validation_v1_preliminary_")
        campaign_name = token;
    end
end

if strlength(run_id) == 0
    run_id = "unknown_run";
end
if strlength(geometry) == 0
    geometry = "unknown_geometry";
end
if strlength(campaign_name) == 0
    campaign_name = "unknown_campaign";
end

end


function [x_m, z_m] = resolve_axes(data, sz)

if isfield(data, "axes")
    ax = data.axes;
    if isfield(ax, "x_m")
        x_m = double(ax.x_m(:));
    else
        x_m = (0:sz(2)-1)' * double(data.dx_m);
    end

    if isfield(ax, "z_m")
        z_m = double(ax.z_m(:));
    else
        z_m = (0:sz(1)-1)' * double(data.dz_m);
    end
else
    x_m = (0:sz(2)-1)' * double(data.dx_m);
    z_m = (0:sz(1)-1)' * double(data.dz_m);
end

x_m = x_m(:);
z_m = z_m(:);

end


function [xg_m, zg_m, sws_map] = build_sws_map(T)

x_name = resolve_variable_name(T, ["x_center_m"]);
z_name = resolve_variable_name(T, ["z_center_m"]);
cs_name = resolve_variable_name(T, ["cs_pred","cs_pred_m_s"]);

x = double(T.(x_name));
z = double(T.(z_name));
cs = double(T.(cs_name));

xg_m = unique(x);
zg_m = unique(z);

[~, ix] = ismember(x, xg_m);
[~, iz] = ismember(z, zg_m);

sws_map = nan(numel(zg_m), numel(xg_m));
for k = 1:numel(cs)
    sws_map(iz(k), ix(k)) = cs(k);
end

end


function name = resolve_variable_name(T, candidates)

names = string(T.Properties.VariableNames);
name = "";

for i = 1:numel(candidates)
    if ismember(candidates(i), names)
        name = candidates(i);
        return
    end
end

error("Could not resolve variable name. Candidates: %s", strjoin(candidates, ", "));

end


function save_single_map(x_m, z_m, img, out_file, plot_title, cb_label, cmap, clim, is_phase)

fig = figure("Visible","off","Color","w","Position",[100 100 850 650]);
ax = axes(fig);

imagesc(ax, x_m*1e3, z_m*1e3, img);
set(ax, "YDir", "normal");
axis(ax, "image");
xlabel(ax, "x (mm)");
ylabel(ax, "z (mm)");
title(ax, plot_title, "Interpreter","none");

if ischar(cmap) || isstring(cmap)
    colormap(ax, cmap);
else
    colormap(ax, cmap);
end

if ~isempty(clim)
    caxis(ax, clim);
end

cb = colorbar(ax);
ylabel(cb, cb_label);

if is_phase
    cb.Ticks = [-pi, -pi/2, 0, pi/2, pi];
    cb.TickLabels = {'-\pi','-\pi/2','0','\pi/2','\pi'};
end

grid(ax, "on");
exportgraphics(fig, out_file, "Resolution", 250);
close(fig);

end


function save_combined_figure(x_m, z_m, amplitude, phase, xg_m, zg_m, sws_map, out_file, title_prefix, M, step_pixels)

fig = figure("Visible","off","Color","w","Position",[100 100 1600 500]);
tl = tiledlayout(fig, 1, 3, "TileSpacing", "compact", "Padding", "compact");

ax1 = nexttile(tl);
imagesc(ax1, x_m*1e3, z_m*1e3, amplitude);
set(ax1, "YDir", "normal");
axis(ax1, "image");
xlabel(ax1, "x (mm)");
ylabel(ax1, "z (mm)");
title(ax1, "Amplitude", "Interpreter","none");
colormap(ax1, "turbo");
cb1 = colorbar(ax1);
ylabel(cb1, "Amplitude (a.u.)");
grid(ax1, "on");

ax2 = nexttile(tl);
imagesc(ax2, x_m*1e3, z_m*1e3, phase);
set(ax2, "YDir", "normal");
axis(ax2, "image");
xlabel(ax2, "x (mm)");
ylabel(ax2, "z (mm)");
title(ax2, "Phase", "Interpreter","none");
colormap(ax2, blue_red_map(256));
caxis(ax2, [-pi pi]);
cb2 = colorbar(ax2);
ylabel(cb2, "Phase (rad)");
cb2.Ticks = [-pi, -pi/2, 0, pi/2, pi];
cb2.TickLabels = {'-\pi','-\pi/2','0','\pi/2','\pi'};
grid(ax2, "on");

ax3 = nexttile(tl);
imagesc(ax3, xg_m*1e3, zg_m*1e3, sws_map);
set(ax3, "YDir", "normal");
axis(ax3, "image");
xlabel(ax3, "x (mm)");
ylabel(ax3, "z (mm)");
title(ax3, sprintf("Predicted SWS (M=%d, step=%d)", M, step_pixels), "Interpreter","none");
colormap(ax3, "turbo");
cb3 = colorbar(ax3);
ylabel(cb3, "c_s (m/s)");
grid(ax3, "on");

sgtitle(fig, title_prefix, "Interpreter","none");
exportgraphics(fig, out_file, "Resolution", 250);
close(fig);

end


function cmap = blue_red_map(n)

if nargin < 1
    n = 256;
end

anchors = [
    0.00  0.05 0.20 0.80
    0.50  1.00 1.00 1.00
    1.00  0.80 0.15 0.10
];

xi = linspace(0,1,n)';
cmap = zeros(n,3);

for k = 1:3
    cmap(:,k) = interp1(anchors(:,1), anchors(:,k+1), xi, "linear");
end

cmap = max(0, min(1, cmap));

end
