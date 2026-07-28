function field_class = resolve_field_class( ...
    direction_count, mapping)
%RESOLVE_FIELD_CLASS Resolve a configured theory class for one campaign run.

arguments
    direction_count (1,1) double
    mapping (:,1) struct
end

required_fields = [
    "direction_count"
    "field_class"
    ];

for field_name = required_fields.'
    if ~isfield(mapping, field_name)
        error("reqml:InvalidTheoryClassMapping", ...
            "Theory class mapping is missing '%s'.", ...
            field_name);
    end
end

counts = arrayfun( ...
    @(entry) double(entry.direction_count), ...
    mapping);

matches = find(counts == direction_count);

if isempty(matches)
    error("reqml:MissingTheoryClassMapping", ...
        "No theory class is configured for direction_count=%g.", ...
        direction_count);
end

if numel(matches) > 1
    error("reqml:DuplicateTheoryClassMapping", ...
        "Multiple theory classes are configured for direction_count=%g.", ...
        direction_count);
end

field_class = string(mapping(matches).field_class);

valid_classes = [
    "SingleWave"
    "PartialDiffuse3D"
    "Diffuse3D"
    ];

if ~ismember(field_class, valid_classes)
    error("reqml:InvalidTheoryFieldClass", ...
        "Unsupported configured theory class '%s'.", ...
        field_class);
end

end
