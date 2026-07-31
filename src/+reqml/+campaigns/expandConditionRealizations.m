function runs = expandConditionRealizations(conditions)
%EXPANDCONDITIONREALIZATIONS Expand physical conditions into run designs.
%
% Each condition must define:
%
%   condition_id
%   realization_count
%   overrides
%
% The function generates deterministic:
%
%   realization_id
%   design_id
%
% Example:
%
%   condition.condition_id = "cond_000001";
%   condition.realization_count = 3;
%   condition.overrides = struct( ...
%       "path", "wavefield.frequency_hz", ...
%       "value", 400);
%
%   runs = reqml.campaigns.expandConditionRealizations(condition);

arguments
    conditions (:,1) struct
end

if isempty(conditions)
    error("reqml:EmptyAdaptiveConditions", ...
        "At least one adaptive campaign condition is required.");
end

validate_conditions(conditions);

total_runs = sum(arrayfun( ...
    @(value) double(value.realization_count), ...
    conditions));

empty_run = struct( ...
    "condition_id", "", ...
    "realization_id", 0, ...
    "design_id", "", ...
    "overrides", struct([]));

runs = repmat(empty_run, total_runs, 1);

run_index = 0;

for condition_index = 1:numel(conditions)
    condition = conditions(condition_index);

    condition_id = string(condition.condition_id);
    realization_count = double(condition.realization_count);

    for realization_id = 1:realization_count
        run_index = run_index + 1;

        runs(run_index).condition_id = condition_id;
        runs(run_index).realization_id = realization_id;

        runs(run_index).design_id = sprintf( ...
            "%s_r%03d", ...
            condition_id, ...
            realization_id);

        runs(run_index).overrides = ...
            condition.overrides;
    end
end

design_ids = string({runs.design_id})';

if numel(unique(design_ids)) ~= numel(design_ids)
    error("reqml:DuplicateAdaptiveDesignId", ...
        "Expanded adaptive design IDs must be unique.");
end

end


function validate_conditions(conditions)

required_fields = [
    "condition_id"
    "realization_count"
    "overrides"
    ];

condition_ids = strings(numel(conditions), 1);

for index = 1:numel(conditions)
    condition = conditions(index);

    missing = setdiff( ...
        required_fields, ...
        string(fieldnames(condition)));

    if ~isempty(missing)
        error("reqml:InvalidAdaptiveCondition", ...
            "Adaptive condition is missing field '%s'.", ...
            missing(1));
    end

    if ~is_text_scalar(condition.condition_id)
        error("reqml:InvalidAdaptiveConditionId", ...
            "condition_id must be a non-empty text scalar.");
    end

    condition_id = string(condition.condition_id);

    if strlength(condition_id) == 0 || ...
            isempty(regexp( ...
                char(condition_id), ...
                '^[A-Za-z0-9_-]+$', ...
                'once'))

        error("reqml:InvalidAdaptiveConditionId", ...
            ["condition_id must contain only letters, numbers, " ...
             "underscores, and hyphens."]);
    end

    realization_count = double( ...
        condition.realization_count);

    if ~isscalar(realization_count) || ...
            ~isfinite(realization_count) || ...
            realization_count < 1 || ...
            realization_count ~= fix(realization_count)

        error("reqml:InvalidRealizationCount", ...
            "realization_count must be a positive integer.");
    end

    validate_overrides(condition.overrides);

    condition_ids(index) = condition_id;
end

if numel(unique(condition_ids)) ~= numel(condition_ids)
    error("reqml:DuplicateAdaptiveConditionId", ...
        "Each adaptive condition must have a unique condition_id.");
end

end


function validate_overrides(overrides)

if ~isstruct(overrides) || isempty(overrides)
    error("reqml:InvalidAdaptiveOverrides", ...
        "overrides must be a non-empty struct array.");
end

for index = 1:numel(overrides)
    override = overrides(index);

    if ~all(isfield(override, ["path", "value"]))
        error("reqml:InvalidAdaptiveOverrides", ...
            "Each override must contain path and value.");
    end

    if ~is_text_scalar(override.path) || ...
            strlength(string(override.path)) == 0

        error("reqml:InvalidAdaptiveOverrides", ...
            "Each override path must be a non-empty text scalar.");
    end
end

end


function result = is_text_scalar(value)

result = ...
    (ischar(value) && isrow(value)) || ...
    (isstring(value) && isscalar(value));

end
