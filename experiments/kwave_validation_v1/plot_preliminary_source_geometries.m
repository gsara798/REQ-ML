function plot_preliminary_source_geometries()

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
sim_root = string(getenv("SWSIM_ROOT"));
addpath(fullfile(sim_root,"src"));

search_root = fullfile( ...
    repo_root, ...
    "outputs","validation","kwave_validation_v1", ...
    "simulations","preliminary");

out_root = fullfile( ...
    repo_root, ...
    "outputs","validation","kwave_validation_v1", ...
    "analysis","source_geometry");

if ~isfolder(out_root)
    mkdir(out_root);
end

files = dir(fullfile(search_root,"**","resolved_config.json"));
assert(~isempty(files),"No resolved configs found.");

found_directional = false;
found_intermediate = false;
found_diffuse = false;

rows = {};

for i = 1:numel(files)

    cfg_file = fullfile(files(i).folder,files(i).name);
    cfg = jsondecode(fileread(cfg_file));

    N = double(cfg.source.vibrator_count);
    P = double(cfg.source.exact_in_plane_sources);
    omega = double(cfg.source.angular_support_solid_angle_sr);

    regime = "";

    if N == 1 && P == 1 && abs(omega-0.01) < 1e-8
        regime = "directional";
        if found_directional, continue; end

    elseif N == 16 && P == 4 && abs(omega-pi) < 1e-6
        regime = "intermediate";
        if found_intermediate, continue; end

    elseif N == 32 && P == 8 && abs(omega-4*pi) < 1e-6
        regime = "diffuse_like";
        if found_diffuse, continue; end

    else
        continue
    end

    % resolved_config.json already contains the exact realized source
    % geometry used by the completed simulation. Do not regenerate it.
    %
    % MATLAB jsondecode represents a single XYZ vector as 3x1, whereas
    % plotSourceGeometry3D expects source_count-by-3 arrays.
    g = cfg.source.geometry_metrics;

    if double(g.source_count) == 1
        if numel(g.propagation_directions_xyz) == 3
            g.propagation_directions_xyz = ...
                reshape(double(g.propagation_directions_xyz), 1, 3);
        end

        if numel(g.centers_index_xyz) == 3
            g.centers_index_xyz = ...
                reshape(double(g.centers_index_xyz), 1, 3);
        end
    end

    cfg.source.geometry_metrics = g;

    handles = kwsim.viz.plotSourceGeometry3D( ...
        cfg, ...
        Title=replace(regime,"_"," "), ...
        FigureVisible="off", ...
        ShowContactNodes=false, ...
        ShowDirectionArrows=true);

    png_file = fullfile(out_root, regime + "_source_geometry.png");

    exportgraphics( ...
        handles.figure, ...
        png_file, ...
        "Resolution",250);

    close(handles.figure);

    g = cfg.source.geometry_metrics;

    row = struct();
    row.regime = regime;
    row.config_file = string(cfg_file);
    row.N = g.source_count;
    row.P = g.in_plane_contact_count;
    row.unique_faces = g.unique_face_count;
    row.effective_angular_dimension = g.effective_angular_dimension;
    row.directional_bias = g.directional_bias;

    if isfield(g,"pairwise_axis_angle_p10_deg")
        row.axis_p10_deg = g.pairwise_axis_angle_p10_deg;
    else
        row.axis_p10_deg = NaN;
    end

    if isfield(g,"pairwise_axis_angle_median_deg")
        row.axis_median_deg = g.pairwise_axis_angle_median_deg;
    else
        row.axis_median_deg = NaN;
    end

    rows{end+1,1} = row; %#ok<AGROW>

    if regime == "directional"
        found_directional = true;
    elseif regime == "intermediate"
        found_intermediate = true;
    elseif regime == "diffuse_like"
        found_diffuse = true;
    end

    fprintf("\n%s\n",upper(regime));
    fprintf("  N=%d\n",g.source_count);
    fprintf("  P=%d\n",g.in_plane_contact_count);
    fprintf("  faces=%d\n",g.unique_face_count);
    fprintf("  Deff=%.4f\n",g.effective_angular_dimension);
    fprintf("  bias=%.4f\n",g.directional_bias);
    fprintf("  saved: %s\n",png_file);

end

assert(found_directional, "Directional regime not found.");
assert(found_intermediate, "Intermediate regime not found.");
assert(found_diffuse, "Diffuse-like regime not found.");

summary = struct2table(vertcat(rows{:}));
writetable(summary,fullfile(out_root,"source_geometry_summary.csv"));

disp(summary);

fprintf("\nOutput directory:\n%s\n",out_root);

end
