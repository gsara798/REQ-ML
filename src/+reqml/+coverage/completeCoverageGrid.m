function complete = completeCoverageGrid( ...
    summary, sws_edges, frequency_edges, ...
    purity_edges, diffusivity_edges, ...
    discretization_pairs_m)
%COMPLETECOVERAGEGRID Add every configured 5-D coverage cell.
%
% A coverage cell is defined by:
%
%   SWS bin
%   frequency bin
%   purity bin
%   diffusivity / nominal-angular-coverage bin
%   spatial-discretization bin
%
% Coverage must be evaluated over the complete configured grid, including
% cells that received no examples.

arguments
    summary table
    sws_edges (1,:) double
    frequency_edges (1,:) double
    purity_edges (1,:) double
    diffusivity_edges (1,:) double

    discretization_pairs_m (:,2) double = ...
        [0.0005 0.0005]
end

validate_edges(sws_edges, "sws_edges");
validate_edges(frequency_edges, "frequency_edges");
validate_edges(purity_edges, "purity_edges");
validate_edges(diffusivity_edges, "diffusivity_edges");
validate_discretization_pairs(discretization_pairs_m);

sws_bin_count = numel(sws_edges) - 1;
frequency_bin_count = numel(frequency_edges) - 1;
purity_bin_count = numel(purity_edges) - 1;
diffusivity_bin_count = numel(diffusivity_edges) - 1;
discretization_bin_count = size(discretization_pairs_m, 1);

[ ...
    sws_grid, ...
    frequency_grid, ...
    purity_grid, ...
    diffusivity_grid, ...
    discretization_grid ...
    ] = ndgrid( ...
        1:sws_bin_count, ...
        1:frequency_bin_count, ...
        1:purity_bin_count, ...
        1:diffusivity_bin_count, ...
        1:discretization_bin_count);

complete = table();

complete.sws_bin = sws_grid(:);
complete.frequency_bin = frequency_grid(:);
complete.purity_bin = purity_grid(:);
complete.diffusivity_bin = diffusivity_grid(:);
complete.discretization_bin = discretization_grid(:);

complete.cell_key = compose( ...
    "s%02d_f%02d_p%02d_d%02d_g%02d", ...
    complete.sws_bin, ...
    complete.frequency_bin, ...
    complete.purity_bin, ...
    complete.diffusivity_bin, ...
    complete.discretization_bin);

complete.sws_label = make_bin_labels( ...
    complete.sws_bin, ...
    sws_edges);

complete.frequency_label = make_bin_labels( ...
    complete.frequency_bin, ...
    frequency_edges);

complete.purity_label = make_bin_labels( ...
    complete.purity_bin, ...
    purity_edges);

complete.diffusivity_label = make_bin_labels( ...
    complete.diffusivity_bin, ...
    diffusivity_edges);

complete.discretization_label = ...
    make_discretization_labels( ...
        complete.discretization_bin, ...
        discretization_pairs_m);

complete.example_count = ...
    zeros(height(complete), 1);

complete.independent_run_count = ...
    zeros(height(complete), 1);

if ismember( ...
        "independent_condition_count", ...
        string(summary.Properties.VariableNames))

    complete.independent_condition_count = ...
        zeros(height(complete), 1);
end

if ismember( ...
        "geometry_seed_count", ...
        string(summary.Properties.VariableNames))

    complete.geometry_seed_count = ...
        zeros(height(complete), 1);
end

if isempty(summary)
    return
end

required_summary_variables = [
    "sws_bin"
    "frequency_bin"
    "purity_bin"
    "diffusivity_bin"
    "example_count"
    "independent_run_count"
    ];

validate_summary_variables( ...
    summary, ...
    required_summary_variables);

key_variables = [
    "sws_bin"
    "frequency_bin"
    "purity_bin"
    "diffusivity_bin"
    "discretization_bin"
    ];

[found, location] = ismember( ...
    complete(:, key_variables), ...
    summary(:, key_variables), ...
    "rows");

source_variables = [
    "example_count"
    "independent_run_count"
    "independent_condition_count"
    "geometry_seed_count"
    ];

available_summary = string( ...
    summary.Properties.VariableNames);

available_complete = string( ...
    complete.Properties.VariableNames);

for variable = source_variables.'
    if ~ismember(variable, available_summary) || ...
            ~ismember(variable, available_complete)

        continue
    end

    values = complete.(variable);

    values(found) = ...
        summary.(variable)(location(found));

    complete.(variable) = values;
end

complete = sortrows( ...
    complete, ...
    [ ...
        "sws_bin"
        "frequency_bin"
        "purity_bin"
        "diffusivity_bin"
        "discretization_bin"
    ]);

end


function labels = make_discretization_labels( ...
        bin_indices, pairs_m)

labels = strings(numel(bin_indices), 1);

for index = 1:numel(bin_indices)
    level = bin_indices(index);

    labels(index) = sprintf( ...
        "dx=%g,dz=%g", ...
        pairs_m(level, 1), ...
        pairs_m(level, 2));
end

end


function labels = make_bin_labels( ...
        bin_indices, edges)

labels = strings(numel(bin_indices), 1);

for index = 1:numel(bin_indices)
    bin_index = bin_indices(index);

    if bin_index == numel(edges) - 1
        closing_symbol = "]";
    else
        closing_symbol = ")";
    end

    labels(index) = sprintf( ...
        "[%g,%g%s", ...
        edges(bin_index), ...
        edges(bin_index + 1), ...
        closing_symbol);
end

end


function validate_summary_variables( ...
        summary, required)

available = string( ...
    summary.Properties.VariableNames);

for variable = required.'
    if ~ismember(variable, available)
        error( ...
            "reqml:MissingCoverageSummaryVariable", ...
            "Coverage summary is missing variable '%s'.", ...
            variable);
    end
end

end


function validate_discretization_pairs(pairs_m)

pairs_m = double(pairs_m);

if isempty(pairs_m) || ...
        size(pairs_m, 2) ~= 2 || ...
        any(~isfinite(pairs_m), "all") || ...
        any(pairs_m <= 0, "all")

    error("reqml:InvalidDiscretizationCoverage", ...
        "discretization_pairs_m must be a finite positive N-by-2 matrix.");
end

if size(unique(pairs_m, "rows"), 1) ~= size(pairs_m, 1)
    error("reqml:InvalidDiscretizationCoverage", ...
        "discretization_pairs_m must not contain duplicate pairs.");
end

end


function validate_edges(edges, name)

if numel(edges) < 2 || ...
        any(~isfinite(edges)) || ...
        any(diff(edges) <= 0)

    error( ...
        "reqml:InvalidCoverageEdges", ...
        "%s must contain finite increasing values.", ...
        name);
end

end
