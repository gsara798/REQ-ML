function plot_run_maps(data, T, output_file, title_text)

U = data.wavefield_zx;

amplitude = abs(U);
phase = angle(U);

% Normalize amplitude only for visualization.
amp_max = max(amplitude, [], "all", "omitnan");
if amp_max > 0
    amplitude_display = amplitude ./ amp_max;
else
    amplitude_display = amplitude;
end

iz = unique(T.map_iz);
ix = unique(T.map_ix);

sws_map = nan(numel(iz), numel(ix));
ape_map = nan(numel(iz), numel(ix));

[~, zi] = ismember(T.map_iz, iz);
[~, xi] = ismember(T.map_ix, ix);
lin = sub2ind(size(sws_map), zi, xi);

valid = T.sws_valid;

sws_map(lin(valid)) = T.cs_pred_m_s(valid);
ape_map(lin(valid)) = T.cs_absolute_error_percent(valid);

x_wave_mm = 1e3 * double(data.axes.x_m);
z_wave_mm = 1e3 * double(data.axes.z_m);

x_req_mm = 1e3 * unique(T.x_center_m);
z_req_mm = 1e3 * unique(T.z_center_m);

fig = figure( ...
    "Visible","off", ...
    "Color","w", ...
    "Position",[100 100 1500 900]);

tl = tiledlayout(2,2, ...
    "TileSpacing","compact", ...
    "Padding","compact");

title(tl, title_text, "Interpreter","none");

nexttile;
imagesc(x_wave_mm, z_wave_mm, amplitude_display);
axis image;
set(gca,"YDir","normal");
colorbar;
xlabel("x (mm)");
ylabel("z (mm)");
title("Normalized amplitude |U|");

nexttile;
imagesc(x_wave_mm, z_wave_mm, phase);
axis image;
set(gca,"YDir","normal");
colorbar;
clim([-pi pi]);
xlabel("x (mm)");
ylabel("z (mm)");
title("Phase (rad)");

nexttile;
imagesc(x_req_mm, z_req_mm, sws_map);
axis image;
set(gca,"YDir","normal");
colorbar;
xlabel("x (mm)");
ylabel("z (mm)");
title("REQ-ML SWS (m/s)");

nexttile;
imagesc(x_req_mm, z_req_mm, ape_map);
axis image;
set(gca,"YDir","normal");
colorbar;
xlabel("x (mm)");
ylabel("z (mm)");
title("Absolute percentage error (%)");
% Deliberately no clim(): each map uses its own data range.

exportgraphics(fig, output_file, "Resolution", 200);
close(fig);

end
