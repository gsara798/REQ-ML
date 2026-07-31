function q_pred = predict_regression_model(model, X, options)
%PREDICT_REGRESSION_MODEL Apply a fitted q-regression model.

arguments
    model struct
    X double

    options.ClipRange (1,2) double = [0.001, 0.999]
end

required = ["model_type", "mu", "sigma"];

missing = required(~isfield(model, cellstr(required)));

if ~isempty(missing)
    error("reqml:InvalidRegressionModel", ...
        "Regression model is missing fields: %s", ...
        strjoin(missing, ", "));
end

if size(X, 2) ~= numel(model.mu)
    error("reqml:PredictorCountMismatch", ...
        "Model expects %d predictors but received %d.", ...
        numel(model.mu), size(X, 2));
end

if any(~isfinite(X), "all")
    error("reqml:NonFinitePredictionInput", ...
        "Prediction matrix contains non-finite values.");
end

Xstandardized = (X - model.mu) ./ model.sigma;

switch lower(string(model.model_type))
    case "ridge"
        design = [ones(size(Xstandardized, 1), 1), Xstandardized];
        q_pred = design * model.coefficients;

    case "bagged_trees"
        q_pred = predict(model.ensemble, Xstandardized);

    otherwise
        error("reqml:UnknownRegressionModelType", ...
            "Prediction is not implemented for: %s", ...
            string(model.model_type));
end

q_pred = min( ...
    max(double(q_pred(:)), options.ClipRange(1)), ...
    options.ClipRange(2));

end
