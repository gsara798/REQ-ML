function regime = resolveFieldRegime(value)
%RESOLVEFIELDREGIME Map public angular aliases to validated field anchors.

arguments
    value {mustBeTextScalar}
end

alias = lower(strtrim(string(value)));
switch alias
    case {"directional", "low"}
        regime = struct("name", "directional", "direction_count", 1, ...
            "in_plane_count", 1, "solid_angle_sr", 0.01);
    case {"intermediate", "mid"}
        regime = struct("name", "intermediate", "direction_count", 16, ...
            "in_plane_count", 4, "solid_angle_sr", pi);
    case {"diffuse", "high"}
        regime = struct("name", "diffuse", "direction_count", 32, ...
            "in_plane_count", 8, "solid_angle_sr", 4*pi);
    otherwise
        error("reqml:UnknownFieldRegime", ...
            "FieldRegime must be directional, intermediate, or diffuse.");
end
end
