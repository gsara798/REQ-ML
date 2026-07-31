function map = reconstruct_sws_map(predictions, run_id, options)
%RECONSTRUCT_SWS_MAP Reconstruct one local SWS map from patch predictions.
%
% The returned matrices have one value per REQ patch center. No spatial
% interpolation is performed.

arguments
    predictions table
    run_id (1,1) string

    options.ModelId (1,1) string = "bagged_full"
    options.Partition (1,1) string = "test"
end

required = [
    "model_id"
    "partition"
    "campaign_run_id"
    "x_center_m"
    "z_center_m"
    "q_true"
    "q_pred"
    "cs_true_m_s"
    "cs_pred_m_s"
    "cs_error_percent"
    "cs_absolute_error_percent"
    "sws_valid"
    ];

missing = setdiff( ...
    required, ...
    string(predictions.Properties.VariableNames));

if ~isempty(missing)
    error("reqml:MissingMapVariable", ...
        "Prediction table is missing variables: %s", ...
        strjoin(missing, ", "));
end

mask = ...
    string(predictions.model_id) == options.ModelId & ...
    string(predictions.partition) == options.Partition & ...
    string(predictions.campaign_run_id) == run_id & ...
    logical(predictions.sws_valid);

data = predictions(mask, :);

if isempty(data)
    error("reqml:EmptyMapSelection", ...
        "No valid predictions found for run '%s'.", ...
        run_id);
end

x = unique(double(data.x_center_m), "sorted");
z = unique(double(data.z_center_m), "sorted");

nx = numel(x);
nz = numel(z);

expected_count = nx * nz;

if height(data) ~= expected_count
    error("reqml:IncompleteMapGrid", ...
        ["Run '%s' contains %d patches but its coordinate grid " ...
         "requires %d."], ...
        run_id, ...
        height(data), ...
        expected_count);
end

[~, x_index] = ismember(double(data.x_center_m), x);
[~, z_index] = ismember(double(data.z_center_m), z);

linear_index = sub2ind( ...
    [nz, nx], ...
    z_index, ...
    x_index);

if numel(unique(linear_index)) ~= height(data)
    error("reqml:DuplicateMapCoordinate", ...
        "Run '%s' contains duplicate patch coordinates.", ...
        run_id);
end

map = struct();
map.schema_name = "reqml_local_sws_map";
map.schema_version = "1.0";

map.model_id = options.ModelId;
map.partition = options.Partition;
map.campaign_run_id = run_id;

map.x_center_m = x;
map.z_center_m = z;

map.q_true = fill_grid( ...
    data.q_true, linear_index, nz, nx);

map.q_pred = fill_grid( ...
    data.q_pred, linear_index, nz, nx);

map.cs_true_m_s = fill_grid( ...
    data.cs_true_m_s, linear_index, nz, nx);

map.cs_pred_m_s = fill_grid( ...
    data.cs_pred_m_s, linear_index, nz, nx);

map.cs_error_percent = fill_grid( ...
    data.cs_error_percent, linear_index, nz, nx);

map.cs_absolute_error_percent = fill_grid( ...
    data.cs_absolute_error_percent, ...
    linear_index, ...
    nz, ...
    nx);

map.patch_count = height(data);

map.frequency_hz = unique_scalar( ...
    data.campaign_frequency_hz, ...
    "campaign_frequency_hz");

map.background_cs_m_s = unique_scalar( ...
    data.campaign_background_cs_m_s, ...
    "campaign_background_cs_m_s");

map.direction_count = unique_scalar( ...
    data.campaign_direction_count, ...
    "campaign_direction_count");

end

function grid = fill_grid(values, linear_index, nz, nx)

grid = nan(nz, nx);
grid(linear_index) = double(values);

end

function value = unique_scalar(values, variable_name)

values = unique(double(values));

if numel(values) ~= 1
    error("reqml:NonUniqueMapMetadata", ...
        "Map metadata '%s' is not unique.", ...
        variable_name);
end

value = values;

end
