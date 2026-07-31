function interpolated = interpolate_sws_map(map, options)
%INTERPOLATE_SWS_MAP Interpolate a native patch-center SWS map.
%
% Native REQ values remain unchanged. The interpolated grid is intended for
% visualization and spatial overlays, not for primary model evaluation.

arguments
    map (1,1) struct

    options.QuerySpacingM (1,1) double = NaN
    options.Method (1,1) string = "linear"
end

required = [
    "x_center_m"
    "z_center_m"
    "cs_pred_m_s"
    "cs_true_m_s"
    ];

for name = required.'
    if ~isfield(map, name)
        error("reqml:InvalidSwsMap", ...
            "Map is missing field '%s'.", name);
    end
end

supported_methods = ["linear", "nearest", "cubic", "spline"];

if ~ismember(options.Method, supported_methods)
    error("reqml:UnsupportedMapInterpolation", ...
        "Unsupported interpolation method: %s", ...
        options.Method);
end

x_native = double(map.x_center_m(:));
z_native = double(map.z_center_m(:));

if numel(x_native) < 2 || numel(z_native) < 2
    error("reqml:InsufficientMapGrid", ...
        "At least two native centers are required per axis.");
end

native_dx = median(diff(x_native));
native_dz = median(diff(z_native));

query_spacing = options.QuerySpacingM;

if ~isfinite(query_spacing)
    query_spacing = min(native_dx, native_dz) / 4;
end

if query_spacing <= 0
    error("reqml:InvalidMapQuerySpacing", ...
        "Query spacing must be positive.");
end

x_query = ...
    (x_native(1):query_spacing:x_native(end)).';

z_query = ...
    (z_native(1):query_spacing:z_native(end)).';

[X_native, Z_native] = meshgrid(x_native, z_native);
[X_query, Z_query] = meshgrid(x_query, z_query);

cs_pred_interpolated = interp2( ...
    X_native, ...
    Z_native, ...
    double(map.cs_pred_m_s), ...
    X_query, ...
    Z_query, ...
    options.Method);

cs_true_interpolated = interp2( ...
    X_native, ...
    Z_native, ...
    double(map.cs_true_m_s), ...
    X_query, ...
    Z_query, ...
    options.Method);

cs_error_percent_interpolated = ...
    100 * ...
    (cs_pred_interpolated - cs_true_interpolated) ./ ...
    cs_true_interpolated;

interpolated = struct();
interpolated.schema_name = "reqml_interpolated_sws_map";
interpolated.schema_version = "1.0";

interpolated.model_id = map.model_id;
interpolated.partition = map.partition;
interpolated.campaign_run_id = map.campaign_run_id;

interpolated.x_m = x_query;
interpolated.z_m = z_query;

interpolated.cs_pred_m_s = cs_pred_interpolated;
interpolated.cs_true_m_s = cs_true_interpolated;
interpolated.cs_error_percent = ...
    cs_error_percent_interpolated;

interpolated.native_spacing_x_m = native_dx;
interpolated.native_spacing_z_m = native_dz;
interpolated.query_spacing_m = query_spacing;
interpolated.interpolation_method = options.Method;

end
