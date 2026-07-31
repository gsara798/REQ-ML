function model = load_frozen_model(model_file, model_id)
%LOAD_FROZEN_MODEL Load one named persisted regression model.

arguments
    model_file {mustBeTextScalar}
    model_id (1,1) string
end

if ~isfile(model_file)
    error("reqml:MissingFrozenModelFile", ...
        "Frozen model file not found: %s", ...
        string(model_file));
end

loaded = load(model_file);

if ~isfield(loaded, "model_metadata")
    error("reqml:MissingFrozenModelMetadata", ...
        "Frozen model file does not contain model_metadata.");
end

metadata = loaded.model_metadata;

if isfield(loaded, "model_names")
    model_names = string(loaded.model_names(:));
else
    model_names = strings(numel(metadata), 1);

    for index = 1:numel(metadata)
        if iscell(metadata)
            candidate = metadata{index};
        else
            candidate = metadata(index);
        end

        if isfield(candidate, "model_id")
            model_names(index) = string(candidate.model_id);
        elseif isfield(candidate, "baseline_id")
            model_names(index) = string(candidate.baseline_id);
        else
            error("reqml:UnnamedFrozenModel", ...
                "Persisted model %d has no identifier.", index);
        end
    end
end

match = find(model_names == model_id);

if isempty(match)
    error("reqml:FrozenModelNotFound", ...
        "Model '%s' was not found.", model_id);
end

if numel(match) ~= 1
    error("reqml:DuplicateFrozenModel", ...
        "Model '%s' appears %d times.", ...
        model_id, numel(match));
end

if iscell(metadata)
    model = metadata{match};
else
    model = metadata(match);
end

end
