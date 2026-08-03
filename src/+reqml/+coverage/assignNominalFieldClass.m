function field_class = assignNominalFieldClass(examples, options)
%ASSIGNNOMINALFIELDCLASS Classify the prescribed angular field geometry.
%
% Classes:
%   1 directional
%   2 intermediate
%   3 broad
%
% Classification uses controlled simulation variables, not the angular
% entropy measured after propagation through the medium.

arguments
    examples table

    options.DirectionCountVariable (1,1) string = ...
        "campaign_direction_count"

    options.SolidAngleVariable (1,1) string = ...
        "campaign_solid_angle_sr"

    options.DirectionalMaximumDirections (1,1) double = 1
    options.DirectionalMaximumSolidAngleSr (1,1) double = 0.1

    options.BroadMinimumDirections (1,1) double = 32
    options.BroadMinimumSolidAngleSr (1,1) double = 2*pi
end

required = [
    options.DirectionCountVariable
    options.SolidAngleVariable
    ];

available = string(examples.Properties.VariableNames);
missing = setdiff(required, available);

if ~isempty(missing)
    error("reqml:MissingNominalFieldVariable", ...
        "Example table is missing nominal field variable '%s'.", ...
        missing(1));
end

direction_count = double( ...
    examples.(options.DirectionCountVariable));

solid_angle_sr = double( ...
    examples.(options.SolidAngleVariable));

field_class = zeros(height(examples), 1);

valid = ...
    isfinite(direction_count) & ...
    isfinite(solid_angle_sr) & ...
    direction_count >= 1 & ...
    solid_angle_sr >= 0;

directional = valid & ...
    direction_count <= ...
        options.DirectionalMaximumDirections & ...
    solid_angle_sr <= ...
        options.DirectionalMaximumSolidAngleSr;

broad = valid & ...
    direction_count >= ...
        options.BroadMinimumDirections & ...
    solid_angle_sr >= ...
        options.BroadMinimumSolidAngleSr;

intermediate = valid & ~directional & ~broad;

field_class(directional) = 1;
field_class(intermediate) = 2;
field_class(broad) = 3;

end
