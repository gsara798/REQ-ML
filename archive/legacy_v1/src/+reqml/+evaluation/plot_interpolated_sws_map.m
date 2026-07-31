function figures = plot_interpolated_sws_map(interpolated)
%PLOT_INTERPOLATED_SWS_MAP Plot explicitly interpolated SWS diagnostics.

arguments
    interpolated (1,1) struct
end

x_mm = 1e3 * double(interpolated.x_m);
z_mm = 1e3 * double(interpolated.z_m);

figures = gobjects(2, 1);

figures(1) = figure( ...
    Name="Interpolated predicted SWS map");

imagesc( ...
    x_mm, ...
    z_mm, ...
    interpolated.cs_pred_m_s);

axis image;
axis xy;
colorbar;

xlabel("x (mm)");
ylabel("z (mm)");

title(sprintf( ...
    "%s | interpolated predicted SWS (%s)", ...
    interpolated.campaign_run_id, ...
    interpolated.interpolation_method), ...
    Interpreter="none");

figures(2) = figure( ...
    Name="Interpolated SWS error map");

imagesc( ...
    x_mm, ...
    z_mm, ...
    interpolated.cs_error_percent);

axis image;
axis xy;
colorbar;

xlabel("x (mm)");
ylabel("z (mm)");

title(sprintf( ...
    "%s | interpolated signed SWS error (%%)", ...
    interpolated.campaign_run_id), ...
    Interpreter="none");

end
