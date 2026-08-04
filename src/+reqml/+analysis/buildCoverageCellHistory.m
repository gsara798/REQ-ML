function history = buildCoverageCellHistory(loop_root)
%BUILDCOVERAGECELLHISTORY Build per-cell coverage history across iterations.
%
% The output contains one row per coverage cell and adaptive iteration.
% Requested-vs-achieved statistics are attached when available.

arguments
    loop_root {mustBeTextScalar}
end

loop_root = string(loop_root);

if ~isfolder(loop_root)
    error("reqml:AdaptiveAuditRootNotFound", ...
        "Adaptive loop root was not found: %s", ...
        loop_root);
end

listing = dir(fullfile(loop_root, "*_iteration_*"));
listing = listing([listing.isdir]);

iteration_indices = nan(numel(listing), 1);

for index = 1:numel(listing)
    token = regexp( ...
        listing(index).name, ...
        "_iteration_(\d+)$", ...
        "tokens", ...
        "once");

    if ~isempty(token)
        iteration_indices(index) = str2double(token{1});
    end
end

valid = isfinite(iteration_indices);
listing = listing(valid);
iteration_indices = iteration_indices(valid);

[iteration_indices, order] = sort(iteration_indices);
listing = listing(order);

if isempty(listing)
    error("reqml:AdaptiveAuditNoIterationsFound", ...
        "No adaptive iteration directories were found in: %s", ...
        loop_root);
end

history_parts = cell(numel(listing), 1);

for index = 1:numel(listing)
    iteration_directory = fullfile( ...
        loop_root, ...
        listing(index).name);

    summary_file = fullfile( ...
        iteration_directory, ...
        "coverage_summary.csv");

    if ~isfile(summary_file)
        error("reqml:AdaptiveAuditCoverageSummaryNotFound", ...
            "Coverage summary was not found: %s", ...
            summary_file);
    end

    summary = readtable( ...
        summary_file, ...
        Delimiter=",", ...
        TextType="string");

    validate_summary_columns(summary, summary_file);

    row_count = height(summary);

    summary.iteration_index = repmat( ...
        iteration_indices(index), ...
        row_count, ...
        1);

    summary.iteration_id = repmat( ...
        string(listing(index).name), ...
        row_count, ...
        1);

    request_statistics = read_request_statistics( ...
        iteration_directory);

    if ~isempty(request_statistics)
        summary = outerjoin( ...
            summary, ...
            request_statistics, ...
            Keys="cell_key", ...
            MergeKeys=true, ...
            Type="left");
    else
        summary.requested_condition_count = zeros(row_count, 1);
        summary.requested_patch_count = zeros(row_count, 1);
        summary.requested_cell_patch_count = zeros(row_count, 1);
        summary.requested_cell_hit_count = zeros(row_count, 1);
    end

    request_columns = [
        "requested_condition_count"
        "requested_patch_count"
        "requested_cell_patch_count"
        "requested_cell_hit_count"
        ];

    for column = request_columns'
        values = summary.(column);

        if isnumeric(values)
            values(ismissing(values)) = 0;
            values(~isfinite(values)) = 0;
        end

        summary.(column) = double(values);
    end

    history_parts{index} = summary;
end

history = vertcat(history_parts{:});

history = sortrows( ...
    history, ...
    ["cell_key", "iteration_index"]);

end


function statistics = read_request_statistics(iteration_directory)

request_file = fullfile( ...
    iteration_directory, ...
    "requested_vs_achieved.csv");

if ~isfile(request_file)
    statistics = table();
    return
end

requests = readtable( ...
    request_file, ...
    Delimiter=",", ...
    TextType="string");

required_columns = [
    "condition_id"
    "patch_count"
    "requested_cell_patch_count"
    "requested_cell_hit"
    ];

missing_columns = setdiff( ...
    required_columns, ...
    string(requests.Properties.VariableNames));

if ~isempty(missing_columns)
    error("reqml:AdaptiveAuditRequestColumnsMissing", ...
        "Requested-vs-achieved file is missing columns: %s", ...
        strjoin(missing_columns, ", "));
end

cell_keys = strings(height(requests), 1);

for row = 1:height(requests)
    token = regexp( ...
        requests.condition_id(row), ...
        "s(\d+)_f(\d+)_p(\d+)_d(\d+)", ...
        "tokens", ...
        "once");

    if isempty(token)
        error("reqml:AdaptiveAuditConditionIdParseFailed", ...
            "Could not recover the requested cell from condition ID: %s", ...
            requests.condition_id(row));
    end

    cell_keys(row) = sprintf( ...
        "s%02d_f%02d_p%02d_d%02d", ...
        str2double(token{1}), ...
        str2double(token{2}), ...
        str2double(token{3}), ...
        str2double(token{4}));
end

[group_index, unique_keys] = findgroups(cell_keys);

statistics = table();
statistics.cell_key = unique_keys;

statistics.requested_condition_count = splitapply( ...
    @numel, ...
    cell_keys, ...
    group_index);

statistics.requested_patch_count = splitapply( ...
    @sum, ...
    double(requests.patch_count), ...
    group_index);

statistics.requested_cell_patch_count = splitapply( ...
    @sum, ...
    double(requests.requested_cell_patch_count), ...
    group_index);

statistics.requested_cell_hit_count = splitapply( ...
    @sum, ...
    double(requests.requested_cell_hit), ...
    group_index);

end


function validate_summary_columns(summary, summary_file)

required_columns = [
    "sws_bin"
    "frequency_bin"
    "purity_bin"
    "diffusivity_bin"
    "cell_key"
    "sws_label"
    "frequency_label"
    "purity_label"
    "diffusivity_label"
    "example_count"
    "independent_run_count"
    "independent_condition_count"
    ];

missing_columns = setdiff( ...
    required_columns, ...
    string(summary.Properties.VariableNames));

if ~isempty(missing_columns)
    error("reqml:AdaptiveAuditSummaryColumnsMissing", ...
        "Coverage summary '%s' is missing columns: %s", ...
        summary_file, ...
        strjoin(missing_columns, ", "));
end

end
