function comparison = compareAdaptivePilotProgress(v2_progress, v3_progress, options)
%COMPAREADAPTIVEPILOTPROGRESS Compare campaigns at equal iteration count.

arguments
    v2_progress table
    v3_progress table
    options.MaximumIterations (1,1) double = 10
end

required = [ ...
    "iteration_index"
    "accumulated_run_count"
    "example_count"
    "observed_coverage_cell_count"
    "deficient_cell_count"
    "requested_cell_hit_rate"
    "median_absolute_predicted_purity_error"
    "maximum_absolute_predicted_purity_error"
    ];
validate_columns(v2_progress, required, "V2 progress");
validate_columns(v3_progress, required, "V3 progress");

v2 = v2_progress(v2_progress.iteration_index <= ...
    options.MaximumIterations, required);
v3 = v3_progress(v3_progress.iteration_index <= ...
    options.MaximumIterations, required);

v2.Properties.VariableNames(2:end) = "v2_" + ...
    string(v2.Properties.VariableNames(2:end));
v3.Properties.VariableNames(2:end) = "v3_" + ...
    string(v3.Properties.VariableNames(2:end));

comparison = innerjoin(v2, v3, Keys="iteration_index");

if height(comparison) ~= min([height(v2), height(v3), ...
        options.MaximumIterations])
    error("reqml:AdaptivePilotComparisonIterationMismatch", ...
        "V2 and V3 do not contain the same contiguous comparison iterations.");
end

comparison.observed_cell_count_difference_v3_minus_v2 = ...
    comparison.v3_observed_coverage_cell_count - ...
    comparison.v2_observed_coverage_cell_count;
comparison.deficient_cell_count_difference_v3_minus_v2 = ...
    comparison.v3_deficient_cell_count - ...
    comparison.v2_deficient_cell_count;
comparison.requested_hit_rate_difference_v3_minus_v2 = ...
    comparison.v3_requested_cell_hit_rate - ...
    comparison.v2_requested_cell_hit_rate;

end


function validate_columns(table_value, required, description)

missing = setdiff(string(required), ...
    string(table_value.Properties.VariableNames));
if ~isempty(missing)
    error("reqml:AdaptivePilotComparisonColumnsMissing", ...
        "%s is missing required column(s): %s", ...
        description, strjoin(missing, ", "));
end

end
