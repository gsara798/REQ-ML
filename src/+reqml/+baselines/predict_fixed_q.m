function result = predict_fixed_q(target, train_mask, options)
%PREDICT_FIXED_Q Predict one robust q value estimated from training rows only.

arguments
    target (:,1) double
    train_mask (:,1) logical

    options.Estimator (1,1) string = "median"
    options.ClipRange (1,2) double = [0.001, 0.999]
end

if numel(target) ~= numel(train_mask)
    error("reqml:BaselineMaskSizeMismatch", ...
        "Target and training mask must have equal length.");
end

valid_train = train_mask & isfinite(target);

if ~any(valid_train)
    error("reqml:NoValidBaselineTrainingRows", ...
        "No finite training targets are available.");
end

switch lower(options.Estimator)
    case "median"
        fitted_value = median(target(valid_train), "omitnan");

    case "mean"
        fitted_value = mean(target(valid_train), "omitnan");

    otherwise
        error("reqml:UnknownFixedQEstimator", ...
            "Unknown fixed-q estimator: %s", options.Estimator);
end

fitted_value = min( ...
    max(fitted_value, options.ClipRange(1)), ...
    options.ClipRange(2));

result = struct();
result.baseline_id = "fixed_q";
result.estimator = lower(options.Estimator);
result.fitted_value = fitted_value;
result.training_row_count = nnz(valid_train);
result.q_pred = repmat(fitted_value, numel(target), 1);

end
