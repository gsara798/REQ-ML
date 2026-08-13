function report = validate_predictor_contract( ...
    examples, predictor_names, registry, options)
%VALIDATE_PREDICTOR_CONTRACT Validate an explicit predictor set.
%
% By default, every predictor must already exist in examples. For the
% composition-augmented q model, RequireExisting=false may be used before
% out-of-fold composition columns are appended.

arguments
    examples table
    predictor_names (:,1) string
    registry (1,1) struct

    options.RequireExisting (1,1) logical = true
end

predictor_names = string(predictor_names(:));
available = string(examples.Properties.VariableNames);

duplicate_names = predictor_names( ...
    duplicated_mask(predictor_names));

missing_names = predictor_names( ...
    ~ismember(predictor_names, available));

forbidden_names = strings(0, 1);

for index = 1:numel(predictor_names)
    name = predictor_names(index);

    exact_forbidden = ismember( ...
        name, ...
        string(registry.forbidden_exact_names));

    prefix_forbidden = any(startsWith( ...
        name, ...
        string(registry.forbidden_prefixes)));

    suffix_forbidden = any(endsWith( ...
        name, ...
        string(registry.forbidden_suffixes)));

    if exact_forbidden || prefix_forbidden || suffix_forbidden
        forbidden_names(end + 1, 1) = name; %#ok<AGROW>
    end
end

nonnumeric_names = strings(0, 1);
nonfinite_names = strings(0, 1);
invalid_shape_names = strings(0, 1);

existing_names = intersect( ...
    predictor_names, ...
    available, ...
    "stable");

for index = 1:numel(existing_names)
    name = existing_names(index);
    values = examples.(char(name));

    if ~isnumeric(values) && ~islogical(values)
        nonnumeric_names(end + 1, 1) = name; %#ok<AGROW>
        continue
    end

    if ~isvector(values) || numel(values) ~= height(examples)
        invalid_shape_names(end + 1, 1) = name; %#ok<AGROW>
        continue
    end

    if any(~isfinite(double(values(:))))
        nonfinite_names(end + 1, 1) = name; %#ok<AGROW>
    end
end

missing_is_valid = ...
    ~options.RequireExisting || isempty(missing_names);

report = struct();

report.schema_name = ...
    "reqml_predictor_contract_validation";
report.schema_version = "1.0";

report.predictor_count = numel(predictor_names);
report.duplicate_names = unique(duplicate_names);
report.missing_names = missing_names;
report.forbidden_names = unique(forbidden_names);
report.nonnumeric_names = unique(nonnumeric_names);
report.nonfinite_names = unique(nonfinite_names);
report.invalid_shape_names = unique(invalid_shape_names);

report.valid = ...
    isempty(duplicate_names) && ...
    missing_is_valid && ...
    isempty(forbidden_names) && ...
    isempty(nonnumeric_names) && ...
    isempty(nonfinite_names) && ...
    isempty(invalid_shape_names);

if report.valid
    report.summary = compose( ...
        "Predictor contract valid with %d predictors.", ...
        numel(predictor_names));
else
    report.summary = string(sprintf( ...
        ['Predictor contract invalid: duplicates=%d, missing=%d, ' ...
         'forbidden=%d, nonnumeric=%d, nonfinite=%d, ' ...
         'invalid_shape=%d.'], ...
        numel(report.duplicate_names), ...
        numel(report.missing_names), ...
        numel(report.forbidden_names), ...
        numel(report.nonnumeric_names), ...
        numel(report.nonfinite_names), ...
        numel(report.invalid_shape_names)));
end

end

function mask = duplicated_mask(values)

[~, first_index] = unique(values, "stable");

mask = true(size(values));
mask(first_index) = false;

end
