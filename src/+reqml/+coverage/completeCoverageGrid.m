function complete = completeCoverageGrid( ...
    summary, purity_edges, diffusivity_edges)
%COMPLETECOVERAGEGRID Add unobserved purity-diffusivity cells with zero counts.
%
% Coverage must be evaluated over the complete configured grid, not only
% over cells that happened to receive examples.

arguments
    summary table
    purity_edges (1,:) double
    diffusivity_edges (1,:) double
end

validate_edges(purity_edges, "purity_edges");
validate_edges(diffusivity_edges, "diffusivity_edges");

purity_bin_count = numel(purity_edges) - 1;
diffusivity_bin_count = numel(diffusivity_edges) - 1;

[purity_grid, diffusivity_grid] = ndgrid( ...
    1:purity_bin_count, ...
    1:diffusivity_bin_count);

complete = table();
complete.purity_bin = purity_grid(:);
complete.diffusivity_bin = diffusivity_grid(:);

complete.purity_label = make_bin_labels( ...
    complete.purity_bin, ...
    purity_edges);

complete.diffusivity_label = make_bin_labels( ...
    complete.diffusivity_bin, ...
    diffusivity_edges);

complete.example_count = zeros(height(complete), 1);
complete.independent_run_count = zeros(height(complete), 1);
complete.sws_bin_count = zeros(height(complete), 1);
complete.frequency_bin_count = zeros(height(complete), 1);

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

[found, location] = ismember( ...
    complete(:, ["purity_bin", "diffusivity_bin"]), ...
    summary(:, ["purity_bin", "diffusivity_bin"]), ...
    "rows");

source_variables = [
    "example_count"
    "independent_run_count"
    "sws_bin_count"
    "frequency_bin_count"
    "independent_condition_count"
    "geometry_seed_count"
    ];

available_summary = string(summary.Properties.VariableNames);
available_complete = string(complete.Properties.VariableNames);

for variable = source_variables.'
    if ~ismember(variable, available_summary) || ...
            ~ismember(variable, available_complete)
        continue
    end

    values = complete.(variable);
    values(found) = summary.(variable)(location(found));
    complete.(variable) = values;
end

end


function labels = make_bin_labels(bin_indices, edges)

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


function validate_edges(edges, name)

if numel(edges) < 2 || ...
        any(~isfinite(edges)) || ...
        any(diff(edges) <= 0)

    error("reqml:InvalidCoverageEdges", ...
        "%s must contain finite increasing values.", ...
        name);
end

end
