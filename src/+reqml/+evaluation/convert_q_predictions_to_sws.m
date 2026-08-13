function result = convert_q_predictions_to_sws( ...
    examples, q_pred, options)
%CONVERT_Q_PREDICTIONS_TO_SWS Convert predicted REQ quantiles to k and SWS.
%
% Each example must contain its compact req_mapping with:
%   Ecum
%   k_cent
%
% The conversion is performed independently for every local patch.

arguments
    examples table
    q_pred (:,1) double

    options.TruthColumn (1,1) string = "truth_cs_center_m_s"
    options.FrequencyColumn (1,1) string = "campaign_frequency_hz"
    options.MappingColumn (1,1) string = "req_mapping"
end

n = height(examples);

if numel(q_pred) ~= n
    error("reqml:PredictionSizeMismatch", ...
        "q_pred must contain one value per example.");
end

required = [
    options.FrequencyColumn
    options.MappingColumn
    ];

names = string(examples.Properties.VariableNames);

missing = setdiff(required, names);

if ~isempty(missing)
    error("reqml:MissingSwsConversionVariable", ...
        "Examples are missing SWS conversion variables: %s", ...
        strjoin(missing, ", "));
end

frequency_hz = double( ...
    examples.(char(options.FrequencyColumn)));

has_truth = ismember(options.TruthColumn, names);

if has_truth
    cs_true_m_s = double( ...
        examples.(char(options.TruthColumn)));
else
    cs_true_m_s = nan(height(examples), 1);
end

mapping_values = examples.(char(options.MappingColumn));

k_pred_rad_m = nan(n, 1);

for index = 1:n
    if iscell(mapping_values)
        mapping = mapping_values{index};
    else
        mapping = mapping_values(index);
    end

    k_pred_rad_m(index) = ...
        reqml.quantile.quantile_to_k( ...
            mapping, ...
            q_pred(index));
end

cs_pred_m_s = ...
    2*pi*frequency_hz ./ k_pred_rad_m;

prediction_valid = ...
    isfinite(q_pred) & ...
    isfinite(k_pred_rad_m) & ...
    k_pred_rad_m > 0 & ...
    isfinite(cs_pred_m_s) & ...
    cs_pred_m_s > 0;

if has_truth
    truth_valid = ...
        isfinite(cs_true_m_s) & ...
        cs_true_m_s > 0;

    valid = prediction_valid & truth_valid;

    cs_error_m_s = cs_pred_m_s - cs_true_m_s;
    cs_error_percent = 100 * cs_error_m_s ./ cs_true_m_s;
    cs_absolute_error_percent = abs(cs_error_percent);

    cs_error_m_s(~truth_valid) = NaN;
    cs_error_percent(~truth_valid) = NaN;
    cs_absolute_error_percent(~truth_valid) = NaN;
else
    valid = prediction_valid;
    cs_error_m_s = nan(n, 1);
    cs_error_percent = nan(n, 1);
    cs_absolute_error_percent = nan(n, 1);
end

result = table();
result.q_pred = double(q_pred(:));
result.k_pred_rad_m = k_pred_rad_m;
result.cs_true_m_s = cs_true_m_s;
result.cs_pred_m_s = cs_pred_m_s;
result.cs_error_m_s = cs_error_m_s;
result.cs_error_percent = cs_error_percent;
result.cs_absolute_error_percent = ...
    cs_absolute_error_percent;
result.sws_valid = valid;
result.has_truth = repmat(has_truth, n, 1);

end
