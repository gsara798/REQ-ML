function result = generate_experimental_multifrequency_q0_sws_maps()
%GENERATE_EXPERIMENTAL_MULTIFREQUENCY_Q0_SWS_MAPS Save frozen-Q0 SWS maps.
% Reuses historical 400-Hz Q0 results when available and otherwise runs
% frozen Q0 only on the wavefield samples prepared by the pre-IUS analysis.

repo_root = fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(fullfile(repo_root, "src"));
analysis_root = fullfile(repo_root, "outputs", "diagnostics", ...
    "experimental_multifrequency_q0_pre_ius_v1");
summary_file = fullfile(analysis_root, "experimental_q0_frequency_summary.mat");
model_file = fullfile(repo_root, "outputs", "homogeneous_cartesian_q0_v2", ...
    "training", "final_frozen_q0_v2", "model_bundle.mat");
map_root = fullfile(analysis_root, "sws_maps");
map_data_dir = fullfile(map_root, "mat");
individual_dir = fullfile(map_root, "individual");
group_dir = fullfile(map_root, "groups");
ensure_dir(map_data_dir); ensure_dir(individual_dir); ensure_dir(group_dir);

assert(isfile(summary_file), "reqml:diagnostics:MissingFrequencySummary", ...
    "Missing frequency summary: %s", summary_file);
assert(isfile(model_file), "reqml:diagnostics:MissingFrozenModel", ...
    "Missing frozen Q0 model: %s", model_file);
loaded = load(summary_file, "inventory");
inventory = loaded.inventory;
required = ["phantom", "field_type", "acquisition_id", "test_id", ...
    "frequency_hz", "sample_file_used", "existing_q0_file"];
assert(all(ismember(required, string(inventory.Properties.VariableNames))), ...
    "reqml:diagnostics:InvalidFrequencySummary", ...
    "Frequency summary inventory is missing required variables.");

map_files = strings(height(inventory), 1);
map_source = strings(height(inventory), 1);
reused_saved_map = false(height(inventory), 1);
for i = 1:height(inventory)
    stem = safe_stem(inventory(i, :));
    map_file = fullfile(map_data_dir, stem + "_q0_map.mat");
    map_files(i) = map_file;
    if isfile(map_file)
        reused_saved_map(i) = true;
        saved_map = load(map_file, "map_result");
        map_source(i) = string(saved_map.map_result.metadata.prediction_source);
        fprintf("[%d/%d] reuse saved map %s\n", i, height(inventory), stem);
        continue
    end

    historical_file = string(inventory.existing_q0_file(i));
    if strlength(historical_file) > 0 && isfile(historical_file)
        fprintf("[%d/%d] reuse historical Q0 %s\n", i, height(inventory), stem);
        prediction = load_historical_prediction(historical_file);
        map_source(i) = "historical_q0";
    else
        sample_file = string(inventory.sample_file_used(i));
        assert(isfile(sample_file), "reqml:diagnostics:MissingWavefieldSample", ...
            "Missing wavefield sample: %s", sample_file);
        fprintf("[%d/%d] frozen Q0 inference %s\n", i, height(inventory), stem);
        prediction = reqml.predictSWS(sample_file, Model=model_file, M=2, ...
            StepPixels=1, UseParallel=true);
        map_source(i) = "frozen_q0_inference";
    end
    map_result = compact_prediction(prediction, inventory(i, :), map_source(i));
    save(map_file, "map_result", "-v7.3");
end

inventory.map_file = map_files;
inventory.map_source = map_source;
writetable(inventory, fullfile(map_root, "sws_map_inventory.csv"));
save(fullfile(map_root, "sws_map_inventory.mat"), "inventory");

for i = 1:height(inventory)
    loaded_map = load(inventory.map_file(i), "map_result");
    output_file = fullfile(individual_dir, safe_stem(inventory(i, :)) + "_sws.png");
    plot_individual_map(loaded_map.map_result, output_file);
end

groups = unique(inventory(:, ["phantom", "field_type"]), "rows", "stable");
group_figures = strings(height(groups), 1);
for i = 1:height(groups)
    mask = inventory.phantom == groups.phantom(i) & ...
        inventory.field_type == groups.field_type(i);
    rows = inventory(mask, :);
    output_file = fullfile(group_dir, lower(groups.phantom(i)) + "_" + ...
        replace(groups.field_type(i), "-", "_") + "_sws_maps.png");
    plot_group_maps(rows, output_file);
    group_figures(i) = output_file;
end
groups.figure_file = group_figures;
writetable(groups, fullfile(map_root, "sws_map_group_figures.csv"));

manifest = struct;
manifest.schema_name = "reqml_experimental_multifrequency_q0_sws_maps";
manifest.schema_version = "1.0";
manifest.model_file = model_file;
manifest.M = 2;
manifest.StepPixels = 1;
manifest.cs_guess_m_s = 3;
manifest.global_individual_clim_m_s = [1, 4];
manifest.group_clim_m_s = struct("H5", [1.3, 2.2], ...
    "H10", [2.0, 4.0], "BILAYER", [1.0, 4.0]);
manifest.condition_count = height(inventory);
manifest.historical_q0_reused_count = sum(map_source == "historical_q0");
manifest.frozen_q0_inference_count = sum(map_source == "frozen_q0_inference");
manifest.saved_map_reused_count = sum(reused_saved_map);
manifest.created_utc = char(datetime("now", "TimeZone", "UTC"));
write_json(fullfile(map_root, "manifest.json"), manifest);

result = struct("output_root", map_root, "inventory", inventory, ...
    "groups", groups, "manifest", manifest);
fprintf("Saved SWS maps under:\n%s\n", map_root);
end

function prediction = load_historical_prediction(file)
loaded = load(file);
names = fieldnames(loaded);
prediction = [];
for i = 1:numel(names)
    candidate = loaded.(names{i});
    if isstruct(candidate) && isfield(candidate, "cs_map") && ...
            isfield(candidate, "valid_mask")
        prediction = candidate;
        break
    end
end
assert(~isempty(prediction), "reqml:diagnostics:InvalidHistoricalQ0", ...
    "No Q0 prediction struct found in %s", file);
end

function map_result = compact_prediction(prediction, row, source)
needed = ["cs_map", "q_map", "valid_mask", "x_mm", "z_mm"];
assert(all(isfield(prediction, needed)), "reqml:diagnostics:InvalidPrediction", ...
    "Q0 prediction does not contain the required map fields.");
map_result = struct;
for name = needed
    map_result.(name) = prediction.(name);
end
map_result.metadata = struct("phantom", row.phantom, ...
    "field_type", row.field_type, "acquisition_id", row.acquisition_id, ...
    "test_id", row.test_id, "frequency_hz", row.frequency_hz, ...
    "prediction_source", source, "M", 2, "StepPixels", 1, ...
    "cs_guess_m_s", 3);
end

function plot_individual_map(map_result, output_file)
f = figure("Visible", "off", "Color", "w", "Position", [100 100 820 660]);
cleanup = onCleanup(@() close(f));
cs = map_result.cs_map;
cs(~map_result.valid_mask) = NaN;
imagesc(map_result.x_mm, map_result.z_mm, cs);
set(gca, "YDir", "normal"); axis image; colormap(turbo); clim([1 4]);
cb = colorbar; cb.Label.String = "SWS (m/s)";
xlabel("x (mm)"); ylabel("z (mm)");
m = map_result.metadata;
title(sprintf("%s | %s | %s | %d Hz | frozen Q0 M=2", ...
    m.phantom, m.field_type, m.acquisition_id, m.frequency_hz), ...
    "Interpreter", "none");
exportgraphics(f, output_file, "Resolution", 180);
end

function plot_group_maps(rows, output_file)
frequencies = [300 400 500 600];
acquisitions = unique(rows.acquisition_id, "stable");
n_rows = numel(acquisitions);
f = figure("Visible", "off", "Color", "w", ...
    "Position", [50 50 1500 max(540, 360*n_rows + 130)]);
cleanup = onCleanup(@() close(f));
t = tiledlayout(n_rows, numel(frequencies), "TileSpacing", "compact", ...
    "Padding", "loose");
limits = group_limits(rows.phantom(1));
for r = 1:n_rows
    for c = 1:numel(frequencies)
        ax = nexttile(t);
        match = rows.acquisition_id == acquisitions(r) & ...
            rows.frequency_hz == frequencies(c);
        if ~any(match)
            axis(ax, "off");
            text(ax, 0.5, 0.5, "not available", "HorizontalAlignment", "center");
            title(ax, sprintf("%d Hz", frequencies(c)));
            continue
        end
        one = rows(find(match, 1), :);
        loaded_map = load(one.map_file, "map_result");
        map_result = loaded_map.map_result;
        cs = map_result.cs_map;
        cs(~map_result.valid_mask) = NaN;
        imagesc(ax, map_result.x_mm, map_result.z_mm, cs);
        set(ax, "YDir", "normal"); axis(ax, "image"); clim(ax, limits);
        colormap(ax, turbo);
        title(ax, sprintf("%d Hz", frequencies(c)));
        if c == 1
            ylabel(ax, acquisitions(r), "Interpreter", "none");
        else
            ax.YTickLabel = [];
        end
        if r == n_rows
            xlabel(ax, "x (mm)");
        else
            ax.XTickLabel = [];
        end
    end
end
cb = colorbar(t.Children(end));
cb.Layout.Tile = "east"; cb.Label.String = "SWS (m/s)";
if n_rows > 1
    title(t, sprintf("%s %s | frozen Q0 M=2 | fixed scale %.1f–%.1f m/s", ...
        rows.phantom(1), rows.field_type(1), limits(1), limits(2)), ...
        "Interpreter", "none", "FontSize", 16);
end
exportgraphics(f, output_file, "Resolution", 180);
end

function limits = group_limits(phantom)
switch string(phantom)
    case "H5"
        limits = [1.3 2.2];
    case "H10"
        limits = [2.0 4.0];
    otherwise
        limits = [1.0 4.0];
end
end

function stem = safe_stem(row)
stem = lower(row.phantom) + "_" + row.acquisition_id + "_" + ...
    string(row.frequency_hz) + "Hz";
stem = regexprep(stem, "[^A-Za-z0-9_-]", "_");
end

function ensure_dir(folder)
if ~isfolder(folder), mkdir(folder); end
end

function write_json(file, value)
fid = fopen(file, "w");
assert(fid >= 0, "reqml:diagnostics:CannotWriteFile", ...
    "Cannot write %s", file);
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(value, PrettyPrint=true));
end
