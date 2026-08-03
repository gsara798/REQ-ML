function assigned = assignCoverageBins(examples, options)
%ASSIGNCOVERAGEBINS Assign patch examples to coverage bins.
%
% The primary coverage variables are:
%
%   patch purity
%   measured field diffusivity
%   local true SWS
%   excitation frequency
%
% Usage:
%
%   assigned = reqml.coverage.assignCoverageBins( ...
%       examples, ...
%       PurityEdges=[0.5 0.6 0.7 0.8 0.9 0.98 1.0], ...
%       DiffusivityEdges=0:0.2:1, ...
%       SwsEdges=1.5:0.5:4.0, ...
%       FrequencyEdges=[199 250 350 450 550 601]);

arguments
    examples table

    options.PurityVariable (1,1) string = ...
        "truth_material_purity"

    options.FieldCoverageMode (1,1) string = ...
        "measured_entropy"

    options.DiffusivityVariable (1,1) string = ...
        "campaign_angular_entropy"

    options.SwsVariable (1,1) string = ...
        "truth_cs_center_m_s"

    options.FrequencyVariable (1,1) string = ...
        "campaign_frequency_hz"

    options.PurityEdges (1,:) double
    options.DiffusivityEdges (1,:) double
    options.SwsEdges (1,:) double
    options.FrequencyEdges (1,:) double
end

validate_edges(options.PurityEdges, "PurityEdges");
validate_edges(options.DiffusivityEdges, "DiffusivityEdges");
validate_edges(options.SwsEdges, "SwsEdges");
validate_edges(options.FrequencyEdges, "FrequencyEdges");

required_variables = [
    options.PurityVariable
    options.SwsVariable
    options.FrequencyVariable
    ];

field_mode = lower(string(options.FieldCoverageMode));

switch field_mode
    case "nominal"
        required_variables = [
            required_variables
            "campaign_direction_count"
            "campaign_solid_angle_sr"
            ];

    case "measured_entropy"
        required_variables = [
            required_variables
            options.DiffusivityVariable
            ];

    otherwise
        error("reqml:InvalidFieldCoverageMode", ...
            ["FieldCoverageMode must be 'nominal' or " ...
             "'measured_entropy'."]);
end

validate_variables(examples, required_variables);

assigned = examples;

assigned.coverage_purity_bin = assign_numeric_bin( ...
    examples.(options.PurityVariable), ...
    options.PurityEdges);

switch field_mode
    case "nominal"
        assigned.nominal_angular_coverage = ...
            reqml.coverage.computeNominalAngularCoverage( ...
                examples.campaign_direction_count, ...
                examples.campaign_solid_angle_sr, ...
                MaximumDirectionCount=128);

        assigned.coverage_diffusivity_bin = ...
            assign_numeric_bin( ...
                assigned.nominal_angular_coverage, ...
                options.DiffusivityEdges);

    case "measured_entropy"
        assigned.coverage_diffusivity_bin = ...
            assign_numeric_bin( ...
                examples.(options.DiffusivityVariable), ...
                options.DiffusivityEdges);
end

assigned.coverage_sws_bin = assign_numeric_bin( ...
    examples.(options.SwsVariable), ...
    options.SwsEdges);

assigned.coverage_frequency_bin = assign_numeric_bin( ...
    examples.(options.FrequencyVariable), ...
    options.FrequencyEdges);

assigned.coverage_purity_label = make_labels( ...
    assigned.coverage_purity_bin, ...
    options.PurityEdges);

assigned.coverage_diffusivity_label = ...
    make_labels( ...
        assigned.coverage_diffusivity_bin, ...
        options.DiffusivityEdges);

assigned.coverage_sws_label = make_labels( ...
    assigned.coverage_sws_bin, ...
    options.SwsEdges);

assigned.coverage_frequency_label = make_labels( ...
    assigned.coverage_frequency_bin, ...
    options.FrequencyEdges);

assigned.coverage_valid = ...
    assigned.coverage_purity_bin > 0 & ...
    assigned.coverage_diffusivity_bin > 0 & ...
    assigned.coverage_sws_bin > 0 & ...
    assigned.coverage_frequency_bin > 0;

assigned.coverage_cell_key = ...
    make_coverage_cell_keys( ...
        assigned.coverage_sws_bin, ...
        assigned.coverage_frequency_bin, ...
        assigned.coverage_purity_bin, ...
        assigned.coverage_diffusivity_bin, ...
        assigned.coverage_valid);

end


function keys = make_coverage_cell_keys( ...
        sws_bin, frequency_bin, purity_bin, ...
        diffusivity_bin, valid)

keys = repmat("out_of_range", numel(valid), 1);

keys(valid) = compose( ...
    "s%02d_f%02d_p%02d_d%02d", ...
    sws_bin(valid), ...
    frequency_bin(valid), ...
    purity_bin(valid), ...
    diffusivity_bin(valid));

end


function bin = assign_numeric_bin(values, edges)

values = double(values);
bin = discretize(values, edges);

bin = double(bin);
bin(~isfinite(bin)) = 0;

end


function labels = make_labels(bin, edges)

labels = strings(numel(bin), 1);

for index = 1:numel(bin)
    bin_index = bin(index);

    if bin_index <= 0
        labels(index) = "out_of_range";
        continue
    end

    lower_edge = edges(bin_index);
    upper_edge = edges(bin_index + 1);

    if bin_index == numel(edges) - 1
        closing_symbol = "]";
    else
        closing_symbol = ")";
    end

    labels(index) = sprintf( ...
        "[%g,%g%s", ...
        lower_edge, ...
        upper_edge, ...
        closing_symbol);
end

end


function validate_variables(examples, required_variables)

available = string(examples.Properties.VariableNames);

for variable = required_variables.'
    if ~ismember(variable, available)
        error( ...
            "reqml:MissingCoverageVariable", ...
            "Example table is missing coverage variable '%s'.", ...
            variable);
    end

    values = examples.(variable);

    if ~isnumeric(values) && ~islogical(values)
        error( ...
            "reqml:InvalidCoverageVariable", ...
            "Coverage variable '%s' must be numeric.", ...
            variable);
    end
end

end


function validate_edges(edges, name)

if numel(edges) < 2 || ...
        any(~isfinite(edges)) || ...
        any(diff(edges) <= 0)

    error( ...
        "reqml:InvalidCoverageEdges", ...
        "%s must contain at least two finite increasing values.", ...
        name);
end

end
