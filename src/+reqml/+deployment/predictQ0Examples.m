function prediction = predictQ0Examples(examples, model, predictor_names)
%PREDICTQ0EXAMPLES Apply the validated frozen-Q0 deployment contract.

arguments
    examples table
    model (1,1) struct
    predictor_names (:,1) string
end

predictor_names = string(predictor_names(:));
contract = reqml.training.validate_predictor_contract( ...
    examples, predictor_names, reqml.training.q0_predictor_registry());
structurally_valid = isempty(contract.duplicate_names) && ...
    isempty(contract.missing_names) && isempty(contract.forbidden_names) && ...
    isempty(contract.nonnumeric_names) && ...
    isempty(contract.invalid_shape_names);
if ~structurally_valid
    error("reqml:InvalidQ0PredictorContract", "%s", contract.summary);
end

X = nan(height(examples), numel(predictor_names));
for index = 1:numel(predictor_names)
    X(:, index) = double(examples.(predictor_names(index)));
end
valid_predictor_mask = all(isfinite(X), 2);
q_pred = nan(height(examples), 1);
if any(valid_predictor_mask)
    q_pred(valid_predictor_mask) = ...
        reqml.training.predict_regression_model( ...
            model, X(valid_predictor_mask, :), ClipRange=[0.001 0.999]);
end

sws = reqml.evaluation.convert_q_predictions_to_sws(examples, q_pred);
prediction = struct();
prediction.q_pred = q_pred;
prediction.sws = sws;
prediction.valid_predictor_mask = valid_predictor_mask;
prediction.contract = contract;
end
