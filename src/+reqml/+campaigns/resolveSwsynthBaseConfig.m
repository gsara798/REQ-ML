function base_config = resolveSwsynthBaseConfig( ...
    geometry_family, mapping)
%RESOLVESWSYNTHBASECONFIG Resolve the swsynth base config for one geometry.
%
% The physical condition remains backend neutral. Backend-specific base
% configuration paths are supplied through an explicit mapping.

arguments
    geometry_family (1,1) string
    mapping (1,1) struct
end

required_fields = [
    "homogeneous"
    "bilayer"
    "circular_inclusion"
    ];

missing = setdiff( ...
    required_fields, ...
    string(fieldnames(mapping)));

if ~isempty(missing)
    error("reqml:InvalidSwsynthBaseConfigMapping", ...
        "Base-config mapping is missing field '%s'.", ...
        missing(1));
end

switch geometry_family
    case "homogeneous"
        base_config = string(mapping.homogeneous);

    case "bilayer"
        base_config = string(mapping.bilayer);

    case "circular_inclusion"
        base_config = string(mapping.circular_inclusion);

    otherwise
        error("reqml:UnsupportedSwsynthGeometryFamily", ...
            "Unsupported swsynth geometry family '%s'.", ...
            geometry_family);
end

if ~isscalar(base_config) || strlength(base_config) == 0
    error("reqml:InvalidSwsynthBaseConfigMapping", ...
        "Resolved base config for '%s' must be non-empty.", ...
        geometry_family);
end

end
