function [X, metadata] = build_numeric_predictor_matrix( ...
    examples, predictor_names)
%BUILD_NUMERIC_PREDICTOR_MATRIX Build an ordered numeric predictor matrix.
%
% Predictor order is preserved exactly. Non-numeric or non-finite columns
% are rejected rather than silently encoded or imputed.

arguments
    examples table
    predictor_names (:,1) string
end

predictor_names = string(predictor_names(:));
available = string(examples.Properties.VariableNames);

missing = setdiff(predictor_names, available);

if ~isempty(missing)
    error("reqml:MissingPredictorVariable", ...
        "Examples table is missing predictors: %s", ...
        strjoin(missing, ", "));
end

if numel(unique(predictor_names)) ~= numel(predictor_names)
    error("reqml:DuplicatePredictorVariable", ...
        "Predictor list contains duplicate variables.");
end

X = zeros(height(examples), numel(predictor_names));

for index = 1:numel(predictor_names)
    name = predictor_names(index);
    values = examples.(char(name));

    if ~isnumeric(values) && ~islogical(values)
        error("reqml:NonNumericPredictor", ...
            "Predictor '%s' has unsupported type '%s'.", ...
            name, class(values));
    end

    if ~isvector(values) || numel(values) ~= height(examples)
        error("reqml:InvalidPredictorShape", ...
            "Predictor '%s' must contain one scalar per example.", name);
    end

    values = double(values(:));

    if any(~isfinite(values))
        error("reqml:NonFinitePredictor", ...
            "Predictor '%s' contains %d non-finite rows.", ...
            name, nnz(~isfinite(values)));
    end

    X(:, index) = values;
end

metadata = struct();
metadata.predictor_names = predictor_names;
metadata.row_count = height(examples);
metadata.predictor_count = numel(predictor_names);

end
