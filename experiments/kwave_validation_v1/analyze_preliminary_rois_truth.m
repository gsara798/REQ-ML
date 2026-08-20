function analyze_preliminary_rois_truth()

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));

sim_root = fullfile( ...
    repo_root, ...
    "outputs","validation","kwave_validation_v1", ...
    "simulations","preliminary");

maps_root = fullfile( ...
    repo_root, ...
    "outputs","validation","kwave_validation_v1", ...
    "analysis","preliminary_maps_M2");

out_root = fullfile( ...
    repo_root, ...
    "outputs","validation","kwave_validation_v1", ...
    "analysis","preliminary_roi_truth_M2");

if ~isfolder(out_root)
    mkdir(out_root);
end

files = dir(fullfile(maps_root, "**", "maps.mat"));
assert(~isempty(files), "No maps.mat files found.");

bulk_margin_mm = 6.0;
interface_halfwidth_mm = 1.0;

rows = {};

fprintf("\nTruth-based ROI analysis\n");
fprintf("========================\n\n");

for fi = 1:numel(files)

    map_file = fullfile(files(fi).folder, files(fi).name);
    S = load(map_file);

    geometry = string(S.geometry);
    run_id = string(S.run_id);

    fprintf("[%02d/%02d] %s | %s\n", ...
        fi, numel(files), geometry, run_id);

    data = reqml.io.load_wavefield_sample(S.sample_file);

    assert(data.has_truth, ...
        "Sample has no truth: %s", S.sample_file);

    truth_native = double(data.truth.cs_m_s_zx);
    truth_valid_native = logical(data.truth.valid_mask_zx);

    x_native_mm = 1e3 * double(data.axes.x_m(:).');
    z_native_mm = 1e3 * double(data.axes.z_m(:));

    x_map_mm = double(S.xg_mm(:).');
    z_map_mm = double(S.zg_mm(:));

    cs_pred = double(S.sws_map);

    if isfield(S,"valid_map")
        valid_pred = logical(S.valid_map);
    else
        valid_pred = isfinite(cs_pred);
    end

    [Xmap,Zmap] = meshgrid(x_map_mm,z_map_mm);

    % Sample truth at REQ patch centers.
    truth_map = interp2( ...
        x_native_mm, ...
        z_native_mm, ...
        truth_native, ...
        Xmap, Zmap, ...
        "nearest", NaN);

    truth_valid_map = interp2( ...
        x_native_mm, ...
        z_native_mm, ...
        double(truth_valid_native), ...
        Xmap, Zmap, ...
        "nearest", 0) > 0.5;

    valid = valid_pred & truth_valid_map & isfinite(truth_map);

    materials = unique(truth_map(valid));
    materials = materials(isfinite(materials));

    fprintf("  materials:");
    fprintf(" %.3g", materials);
    fprintf("\n");

    % Distance to nearest material boundary on the REQ grid.
    boundary_mask = find_material_boundary(truth_map, valid);

    dx_mm = median(diff(x_map_mm));
    dz_mm = median(diff(z_map_mm));

    distance_to_boundary_mm = ...
        distance_to_mask(boundary_mask, dx_mm, dz_mm);

    % Define regions directly from truth.
    roi_defs = {};

    if geometry == "homogeneous"

        truth_cs = median(truth_map(valid));

        roi_bulk = ...
            valid & ...
            distance_to_domain_edge(size(valid), dx_mm, dz_mm) ...
                >= bulk_margin_mm;

        roi_defs = {
            "bulk", roi_bulk, truth_cs
        };

    else

        for mi = 1:numel(materials)

            truth_cs = materials(mi);

            material_mask = valid & abs(truth_map-truth_cs) < 1e-9;

            bulk_mask = ...
                material_mask & ...
                distance_to_boundary_mm >= bulk_margin_mm;

            roi_name = ...
                "bulk_cs_" + replace(sprintf("%.3g",truth_cs),".","p");

            roi_defs(end+1,:) = {roi_name, bulk_mask, truth_cs}; %#ok<AGROW>
        end

        roi_interface = ...
            valid & ...
            distance_to_boundary_mm <= interface_halfwidth_mm;

        roi_defs(end+1,:) = ...
            {"interface_1mm", roi_interface, NaN};

    end

    save_roi_figure( ...
        Xmap,Zmap,cs_pred,truth_map,roi_defs, ...
        fullfile(out_root, geometry + "_" + run_id + "_rois.png"), ...
        geometry + " | " + run_id);

    for ri = 1:size(roi_defs,1)

        roi_name = string(roi_defs{ri,1});
        mask = logical(roi_defs{ri,2});
        truth_cs = double(roi_defs{ri,3});

        values = cs_pred(mask);
        values = values(isfinite(values));

        row = struct();

        row.geometry = geometry;
        row.run_id = run_id;
        row.roi = roi_name;
        row.N = numel(values);

        if isempty(values)

            row.mean_cs_m_s = NaN;
            row.median_cs_m_s = NaN;
            row.std_cs_m_s = NaN;
            row.iqr_cs_m_s = NaN;

        else

            row.mean_cs_m_s = mean(values);
            row.median_cs_m_s = median(values);
            row.std_cs_m_s = std(values);
            row.iqr_cs_m_s = iqr(values);

        end

        row.truth_cs_m_s = truth_cs;

        if isfinite(truth_cs) && ~isempty(values)

            err_pct = ...
                100*(values-truth_cs)/truth_cs;

            row.bias_percent = mean(err_pct);
            row.mape_percent = mean(abs(err_pct));

            row.median_error_percent = ...
                100*(median(values)-truth_cs)/truth_cs;

        else

            row.bias_percent = NaN;
            row.mape_percent = NaN;
            row.median_error_percent = NaN;

        end

        rows{end+1,1} = row; %#ok<AGROW>

        fprintf( ...
            "  %-16s N=%4d median=%6.3f", ...
            roi_name, row.N, row.median_cs_m_s);

        if isfinite(truth_cs)
            fprintf( ...
                " truth=%.1f MAPE=%5.2f%% bias=%+5.2f%%", ...
                truth_cs, row.mape_percent, row.bias_percent);
        end

        fprintf("\n");

    end

    fprintf("\n");

end

results = struct2table(vertcat(rows{:}));

writetable( ...
    results, ...
    fullfile(out_root,"roi_results.csv"));

disp(results);

fprintf("\nSaved:\n%s\n", ...
    fullfile(out_root,"roi_results.csv"));

end


function boundary = find_material_boundary(truth_map, valid)

boundary = false(size(truth_map));

% Horizontal transitions
d = ...
    valid(:,1:end-1) & valid(:,2:end) & ...
    truth_map(:,1:end-1) ~= truth_map(:,2:end);

boundary(:,1:end-1) = boundary(:,1:end-1) | d;
boundary(:,2:end)   = boundary(:,2:end)   | d;

% Vertical transitions
d = ...
    valid(1:end-1,:) & valid(2:end,:) & ...
    truth_map(1:end-1,:) ~= truth_map(2:end,:);

boundary(1:end-1,:) = boundary(1:end-1,:) | d;
boundary(2:end,:)   = boundary(2:end,:)   | d;

end


function D = distance_to_mask(mask, dx_mm, dz_mm)

[nz,nx] = size(mask);

[iz0,ix0] = find(mask);

D = inf(nz,nx);

if isempty(ix0)
    return
end

for iz = 1:nz
    for ix = 1:nx

        dx = (ix0-ix)*dx_mm;
        dz = (iz0-iz)*dz_mm;

        D(iz,ix) = min(hypot(dx,dz));

    end
end

end


function D = distance_to_domain_edge(sz, dx_mm, dz_mm)

nz = sz(1);
nx = sz(2);

[ix,iz] = meshgrid(1:nx,1:nz);

left   = (ix-1)*dx_mm;
right  = (nx-ix)*dx_mm;
top    = (iz-1)*dz_mm;
bottom = (nz-iz)*dz_mm;

D = min(cat(3,left,right,top,bottom),[],3);

end


function save_roi_figure(X,Z,cs,truth,roi_defs,out_file,ttl)

fig = figure( ...
    "Visible","off", ...
    "Color","w", ...
    "Position",[100 100 1050 750]);

ax = axes(fig);

imagesc(ax,X(1,:),Z(:,1),cs);
set(ax,"YDir","normal");
axis(ax,"image");

xlabel(ax,"x (mm)");
ylabel(ax,"z (mm)");
title(ax,ttl,"Interpreter","none");

colormap(ax,"turbo");
cb = colorbar(ax);
ylabel(cb,"c_s (m/s)");

hold(ax,"on");

% Physical material boundary from truth.
contour( ...
    ax,X,Z,truth, ...
    "LineColor","k", ...
    "LineWidth",2);

styles = ["w","m","c","y"];

for i = 1:size(roi_defs,1)

    mask = roi_defs{i,2};

    if any(mask(:))
        contour( ...
            ax,X,Z,double(mask), ...
            [0.5 0.5], ...
            "LineWidth",1.5, ...
            "LineColor", ...
            styles(mod(i-1,numel(styles))+1));
    end

end

hold(ax,"off");

exportgraphics(fig,out_file,"Resolution",250);
close(fig);

end
