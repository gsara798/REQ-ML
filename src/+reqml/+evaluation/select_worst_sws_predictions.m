function worst = select_worst_sws_predictions( ...
    predictions, options)
%SELECT_WORST_SWS_PREDICTIONS Return the largest SWS prediction errors.

arguments
    predictions table

    options.ModelId (1,1) string = "bagged_full"
    options.Partition (1,1) string = "test"
    options.Count (1,1) double = 25
end

required = [
    "model_id"
    "partition"
    "q_true"
    "q_pred"
    "k_pred_rad_m"
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
    error("reqml:MissingDiagnosticVariable", ...
        "Prediction table is missing variables: %s", ...
        strjoin(missing, ", "));
end

mask = ...
    string(predictions.model_id) == options.ModelId & ...
    string(predictions.partition) == options.Partition & ...
    logical(predictions.sws_valid);

worst = predictions(mask, :);

if isempty(worst)
    error("reqml:EmptyDiagnosticSelection", ...
        "No valid predictions matched the requested selection.");
end

worst = sortrows( ...
    worst, ...
    "cs_absolute_error_percent", ...
    "descend");

count = min( ...
    height(worst), ...
    max(1, round(options.Count)));

worst = worst(1:count, :);

preferred = [
    "model_id"
    "partition"
    "campaign_run_id"
    "campaign_frequency_hz"
    "campaign_background_cs_m_s"
    "campaign_direction_count"
    "patch_idx"
    "cx"
    "cz"
    "x_center_m"
    "z_center_m"
    "q_true"
    "q_pred"
    "k_pred_rad_m"
    "cs_true_m_s"
    "cs_pred_m_s"
    "cs_error_percent"
    "cs_absolute_error_percent"
    ];

available = string(worst.Properties.VariableNames);
preferred = preferred(ismember(preferred, available));

worst = worst(:, preferred);

end
