function predictor_names = select_predictors_from_registry(registry, mode)
%SELECT_PREDICTORS_FROM_REGISTRY Select predictors using registry semantics.
%
% Modes:
%   context_only : trainable operational-context variables
%   full         : all trainable variables

arguments
    registry table
    mode (1,1) string
end

required = ["variable_name", "group", "trainable"];

missing = setdiff( ...
    required, ...
    string(registry.Properties.VariableNames));

if ~isempty(missing)
    error("reqml:InvalidVariableRegistry", ...
        "Variable registry is missing columns: %s", ...
        strjoin(missing, ", "));
end

variable_name = string(registry.variable_name);
group = string(registry.group);
trainable = logical(registry.trainable);

switch lower(mode)
    case "context_only"
        mask = trainable & group == "operational_context";

    case "full"
        mask = trainable;

    otherwise
        error("reqml:UnknownPredictorSelectionMode", ...
            "Unknown predictor selection mode: %s", mode);
end

predictor_names = variable_name(mask);

if isempty(predictor_names)
    error("reqml:NoTrainablePredictors", ...
        "Predictor selection '%s' returned no variables.", mode);
end

if numel(unique(predictor_names)) ~= numel(predictor_names)
    error("reqml:DuplicateRegistryVariable", ...
        "Variable registry contains duplicate trainable names.");
end

end
