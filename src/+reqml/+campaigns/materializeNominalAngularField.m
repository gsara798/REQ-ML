function field = materializeNominalAngularField( ...
    stream, target_range, options)
%MATERIALIZENOMINALANGULARFIELD Materialize N and Omega from target Dnom.
%
%   Dnom = (N / Nmax) * (Omega / (4*pi))
%
% The function samples Dnom inside the requested interval, samples a
% feasible integer direction count, and solves analytically for Omega.

arguments
    stream (1,1) RandStream
    target_range (1,2) double

    options.MaximumDirectionCount (1,1) double = 128
    options.MinimumSolidAngleSr (1,1) double = 0.01
    options.MaximumSolidAngleSr (1,1) double = 4*pi
end

validate_inputs(target_range, options);

maximum_count = double(options.MaximumDirectionCount);
maximum_angle = double(options.MaximumSolidAngleSr);
minimum_angle = double(options.MinimumSolidAngleSr);

% Smallest exactly representable positive Dnom under the configured
% minimum source count and minimum solid angle.
minimum_representable = ...
    (1 / maximum_count) * ...
    (minimum_angle / maximum_angle);

lower = max(target_range(1), minimum_representable);
upper = target_range(2);

if lower > upper
    error("reqml:UnreachableNominalAngularCoverageRange", ...
        ["Requested Dnom range [%g,%g] is not reachable under " ...
         "the configured N and solid-angle limits."], ...
        target_range(1), target_range(2));
end

target_dnom = sample_uniform(stream, [lower upper]);

minimum_count = max( ...
    1, ...
    ceil( ...
        target_dnom * maximum_count * ...
        maximum_angle / options.MaximumSolidAngleSr));

maximum_feasible_count = min( ...
    maximum_count, ...
    floor( ...
        target_dnom * maximum_count * ...
        maximum_angle / minimum_angle));

if maximum_feasible_count < minimum_count
    error("reqml:UnreachableNominalAngularCoverageTarget", ...
        ["Sampled Dnom=%g has no feasible integer direction count " ...
         "under the configured solid-angle limits."], ...
        target_dnom);
end

direction_count = randi( ...
    stream, ...
    [minimum_count, maximum_feasible_count]);

solid_angle_sr = ...
    maximum_angle * ...
    target_dnom * ...
    maximum_count / direction_count;

achieved_dnom = ...
    (direction_count / maximum_count) * ...
    (solid_angle_sr / maximum_angle);

tolerance = 1e-12;

if abs(achieved_dnom - target_dnom) > tolerance
    error("reqml:NominalAngularCoverageMaterializationMismatch", ...
        "Materialized angular field does not reproduce the target " + ...
        "Dnom. Target=%g, achieved=%g.", ...
        target_dnom, achieved_dnom);
end

field = struct();

field.nominal_angular_coverage = target_dnom;
field.direction_count = direction_count;
field.solid_angle_sr = solid_angle_sr;
field.maximum_direction_count = maximum_count;
field.maximum_solid_angle_sr = maximum_angle;

end


function validate_inputs(target_range, options)

if any(~isfinite(target_range)) || ...
        target_range(1) < 0 || ...
        target_range(2) > 1 || ...
        target_range(2) < target_range(1)

    error("reqml:InvalidNominalAngularCoverageRange", ...
        "Target Dnom range must be ordered and contained in [0,1].");
end

if options.MaximumDirectionCount < 1 || ...
        options.MaximumDirectionCount ~= ...
            fix(options.MaximumDirectionCount)

    error("reqml:InvalidMaximumDirectionCount", ...
        "MaximumDirectionCount must be a positive integer.");
end

if options.MinimumSolidAngleSr <= 0 || ...
        options.MaximumSolidAngleSr > 4*pi || ...
        options.MaximumSolidAngleSr <= ...
            options.MinimumSolidAngleSr

    error("reqml:InvalidNominalSolidAngleLimits", ...
        ["Solid-angle limits must satisfy " ...
         "0 < minimum < maximum <= 4*pi."]);
end

end


function value = sample_uniform(stream, range)

if range(1) == range(2)
    value = range(1);
else
    value = range(1) + ...
        (range(2) - range(1)) * rand(stream);
end

end
