function result = generateAdaptiveCampaignReport( ...
    loop_output_root, examples_file, options)
%GENERATEADAPTIVECAMPAIGNREPORT Generate summary tables and plots.
%
% Inputs
% ------
% loop_output_root
%   Directory containing adaptive_loop_summary.json and
%   adaptive_loop_iterations.csv.
%
% examples_file
%   MAT file containing table variable 'examples'.
%
% Outputs
% -------
% coverage_heatmap.png
% coverage_progress.png
% run_example_progress.png
% dnom_n_omega_scatter.png
% requested_vs_achieved.png
% adaptive_campaign_report.json
% adaptive_campaign_summary.csv

arguments
    loop_output_root {mustBeTextScalar}
    examples_file {mustBeTextScalar}

    options.OutputDirectory {mustBeTextScalar}

    options.PurityEdges (1,:) double
    options.NominalAngularCoverageEdges (1,:) double
    options.SwsEdges (1,:) double
    options.FrequencyEdges (1,:) double

    options.MaximumDirectionCount (1,1) double = 128
end

loop_output_root = string(loop_output_root);
examples_file = string(examples_file);
output_directory = string(options.OutputDirectory);

validate_inputs( ...
    loop_output_root, ...
    examples_file, ...
    output_directory);

mkdir(output_directory);

summary_file = fullfile( ...
    loop_output_root, ...
    "adaptive_loop_summary.json");

iterations_file = fullfile( ...
    loop_output_root, ...
    "adaptive_loop_iterations.csv");

loop_summary = jsondecode(fileread(summary_file));

iterations = readtable( ...
    iterations_file, ...
    Delimiter=",", ...
    TextType="string", ...
    VariableNamingRule="preserve");

loaded = load(examples_file);

if ~isfield(loaded, "examples") || ...
        ~istable(loaded.examples)

    error("reqml:InvalidAdaptiveReportExamplesFile", ...
        "Examples MAT file must contain table variable 'examples'.");
end

examples = loaded.examples;

assigned = reqml.coverage.assignCoverageBins( ...
    examples, ...
    FieldCoverageMode="nominal", ...
    PurityEdges=options.PurityEdges, ...
    DiffusivityEdges= ...
        options.NominalAngularCoverageEdges, ...
    SwsEdges=options.SwsEdges, ...
    FrequencyEdges=options.FrequencyEdges);

coverage = reqml.coverage.computePatchCoverage( ...
    examples, ...
    FieldCoverageMode="nominal", ...
    PurityEdges=options.PurityEdges, ...
    DiffusivityEdges= ...
        options.NominalAngularCoverageEdges, ...
    SwsEdges=options.SwsEdges, ...
    FrequencyEdges=options.FrequencyEdges, ...
    MinimumExamples=1, ...
    MinimumIndependentRuns=1, ...
    MinimumSwsBins=1, ...
    MinimumFrequencyBins=1, ...
    MinimumIndependentConditions=1);

paths = struct();

paths.coverage_heatmap = fullfile( ...
    output_directory, ...
    "coverage_heatmap.png");

paths.coverage_progress = fullfile( ...
    output_directory, ...
    "coverage_progress.png");

paths.run_example_progress = fullfile( ...
    output_directory, ...
    "run_example_progress.png");

paths.dnom_n_omega_scatter = fullfile( ...
    output_directory, ...
    "dnom_n_omega_scatter.png");

paths.requested_vs_achieved = fullfile( ...
    output_directory, ...
    "requested_vs_achieved.png");

paths.geometry_efficiency = fullfile( ...
    output_directory, ...
    "geometry_efficiency.png");

paths.requested_vs_achieved_csv = fullfile( ...
    output_directory, ...
    "requested_vs_achieved_combined.csv");

paths.summary_csv = fullfile( ...
    output_directory, ...
    "adaptive_campaign_summary.csv");

paths.report_json = fullfile( ...
    output_directory, ...
    "adaptive_campaign_report.json");

make_coverage_heatmap( ...
    coverage.summary, ...
    options.PurityEdges, ...
    options.NominalAngularCoverageEdges, ...
    paths.coverage_heatmap);

make_coverage_progress( ...
    iterations, ...
    paths.coverage_progress);

make_run_example_progress( ...
    iterations, ...
    paths.run_example_progress);

make_dnom_scatter( ...
    assigned, ...
    options.MaximumDirectionCount, ...
    paths.dnom_n_omega_scatter);

requested_vs_achieved = ...
    collect_requested_vs_achieved( ...
        loop_output_root);

if ~isempty(requested_vs_achieved)
    writetable( ...
        requested_vs_achieved, ...
        paths.requested_vs_achieved_csv);

    make_requested_vs_achieved_plot( ...
        requested_vs_achieved, ...
        paths.requested_vs_achieved);

    make_geometry_efficiency_plot( ...
        requested_vs_achieved, ...
        paths.geometry_efficiency);
else
    paths.requested_vs_achieved = "";
    paths.geometry_efficiency = "";
    paths.requested_vs_achieved_csv = "";
end

summary_table = build_summary_table( ...
    loop_summary, ...
    iterations, ...
    assigned, ...
    coverage);

writetable(summary_table, paths.summary_csv);

report = struct();

report.schema_name = ...
    "reqml_adaptive_campaign_report";

report.schema_version = "1.0";

report.campaign_id = ...
    string(loop_summary.campaign_id);

report.coverage_complete = ...
    logical(loop_summary.coverage_complete);

report.completed_iteration_count = ...
    double(loop_summary.completed_iteration_count);

report.final_run_count = ...
    double(iterations.accumulated_run_count(end));

report.final_example_count = ...
    double(iterations.example_count(end));

report.coverage_cell_count = ...
    double(coverage.coverage_cell_count);

report.observed_coverage_cell_count = ...
    double(coverage.observed_coverage_cell_count);

report.deficient_cell_count = ...
    double(coverage.deficient_cell_count);

report.paths = paths;

write_json(paths.report_json, report);

result = struct();

result.report = report;
result.summary = summary_table;
result.paths = paths;

end


function make_coverage_heatmap( ...
        coverage_summary, ...
        purity_edges, dnom_edges, output_path)

purity_count = numel(purity_edges) - 1;
dnom_count = numel(dnom_edges) - 1;

matrix = zeros(purity_count, dnom_count);

for row = 1:height(coverage_summary)
    p = coverage_summary.purity_bin(row);
    d = coverage_summary.diffusivity_bin(row);

    matrix(p,d) = ...
        coverage_summary.example_count(row);
end

figure_handle = figure(Visible="off");

imagesc(matrix);
axis image;

xlabel("Nominal angular coverage bin");
ylabel("Material purity bin");

title("Examples per purity × D_{nom} cell");

colorbar;

xticks(1:dnom_count);
yticks(1:purity_count);

xticklabels(make_edge_labels(dnom_edges));
yticklabels(make_edge_labels(purity_edges));

exportgraphics( ...
    figure_handle, ...
    output_path, ...
    Resolution=180);

close(figure_handle);

end


function make_coverage_progress(iterations, output_path)

figure_handle = figure(Visible="off");

plot( ...
    iterations.iteration_index, ...
    iterations.observed_coverage_cell_count, ...
    "-o", ...
    LineWidth=1.5);

hold on;

plot( ...
    iterations.iteration_index, ...
    iterations.deficient_cell_count, ...
    "-o", ...
    LineWidth=1.5);

xlabel("Adaptive iteration");
ylabel("Coverage cells");

title("Coverage progression");

legend( ...
    ["Observed cells", "Deficient cells"], ...
    Location="best");

grid on;

exportgraphics( ...
    figure_handle, ...
    output_path, ...
    Resolution=180);

close(figure_handle);

end


function make_run_example_progress(iterations, output_path)

figure_handle = figure(Visible="off");

yyaxis left;

plot( ...
    iterations.iteration_index, ...
    iterations.accumulated_run_count, ...
    "-o", ...
    LineWidth=1.5);

ylabel("Accumulated runs");

yyaxis right;

plot( ...
    iterations.iteration_index, ...
    iterations.example_count, ...
    "-o", ...
    LineWidth=1.5);

ylabel("Examples");

xlabel("Adaptive iteration");
title("Dataset growth");

grid on;

exportgraphics( ...
    figure_handle, ...
    output_path, ...
    Resolution=180);

close(figure_handle);

end


function make_dnom_scatter( ...
        assigned, maximum_direction_count, output_path)

n = double(assigned.campaign_direction_count);
omega = double(assigned.campaign_solid_angle_sr);

dnom = reqml.coverage.computeNominalAngularCoverage( ...
    n, ...
    omega, ...
    MaximumDirectionCount=maximum_direction_count);

[unique_rows, unique_index] = unique( ...
    [n omega dnom], ...
    "rows", ...
    "stable");

figure_handle = figure(Visible="off");

scatter( ...
    unique_rows(:,1), ...
    unique_rows(:,2), ...
    40, ...
    unique_rows(:,3), ...
    "filled");

xlabel("Direction count N");
ylabel("Solid angle \Omega [sr]");

title("Angular-field diversity");

colorbar_handle = colorbar;
colorbar_handle.Label.String = "D_{nom}";

grid on;

exportgraphics( ...
    figure_handle, ...
    output_path, ...
    Resolution=180);

close(figure_handle);

end


function combined = collect_requested_vs_achieved( ...
        loop_output_root)

files = dir(fullfile( ...
    loop_output_root, ...
    "*_iteration_*", ...
    "requested_vs_achieved.csv"));

combined = table();

for index = 1:numel(files)
    file = fullfile( ...
        files(index).folder, ...
        files(index).name);

    current = readtable( ...
        file, ...
        Delimiter=",", ...
        TextType="string", ...
        VariableNamingRule="preserve");

    if isempty(current)
        continue
    end

    current.source_iteration_directory = ...
        repmat(string(files(index).folder), ...
        height(current), 1);

    if isempty(combined)
        combined = current;
    else
        combined = [combined; current]; %#ok<AGROW>
    end
end

end


function make_requested_vs_achieved_plot( ...
        requested, output_path)

required = [
    "condition_id"
    "patch_count"
    "requested_cell_patch_count"
    "requested_cell_hit"
    ];

missing = setdiff( ...
    required, ...
    string(requested.Properties.VariableNames));

if ~isempty(missing)
    error("reqml:InvalidRequestedVsAchievedReport", ...
        "Requested-vs-achieved table is missing '%s'.", ...
        missing(1));
end

patch_count = double(requested.("patch_count"));

target_count = double( ...
    requested.("requested_cell_patch_count"));

fraction = zeros(height(requested), 1);

positive = patch_count > 0;

fraction(positive) = ...
    target_count(positive) ./ patch_count(positive);

labels = make_condition_labels( ...
    string(requested.("condition_id")));

figure_handle = figure(Visible="off");

bar(categorical(labels), fraction);

ylabel("Fraction of patches in requested cell");
xlabel("Planned condition");

title("Requested versus achieved coverage");

ylim([0 1]);

grid on;

exportgraphics( ...
    figure_handle, ...
    output_path, ...
    Resolution=180);

close(figure_handle);

end


function make_geometry_efficiency_plot( ...
        requested, output_path)

required = [
    "geometry_family"
    "requested_cell_hit"
    ];

missing = setdiff( ...
    required, ...
    string(requested.Properties.VariableNames));

if ~isempty(missing)
    error("reqml:InvalidRequestedVsAchievedReport", ...
        "Requested-vs-achieved table is missing '%s'.", ...
        missing(1));
end

geometry = string( ...
    requested.("geometry_family"));

hit = logical( ...
    requested.("requested_cell_hit"));

families = unique(geometry, "stable");

hit_rate = zeros(numel(families), 1);
condition_count = zeros(numel(families), 1);

for index = 1:numel(families)
    mask = geometry == families(index);

    condition_count(index) = nnz(mask);
    hit_rate(index) = mean(double(hit(mask)));
end

figure_handle = figure(Visible="off");

bar(categorical(families), hit_rate);

ylabel("Requested-cell hit rate");
xlabel("Geometry family");

title("Geometry efficiency");

ylim([0 1]);

grid on;

for index = 1:numel(families)
    text( ...
        index, ...
        min(0.98, hit_rate(index) + 0.04), ...
        sprintf("n=%d", condition_count(index)), ...
        HorizontalAlignment="center");
end

exportgraphics( ...
    figure_handle, ...
    output_path, ...
    Resolution=180);

close(figure_handle);

end


function labels = make_condition_labels(condition_ids)

count = numel(condition_ids);
labels = strings(count, 1);

for index = 1:count
    token = regexp( ...
        condition_ids(index), ...
        "p(\\d+)_d(\\d+)", ...
        "tokens", ...
        "once");

    if isempty(token)
        labels(index) = sprintf( ...
            "C%02d", ...
            index);
    else
        labels(index) = sprintf( ...
            "P%s-D%s-C%02d", ...
            token{1}, ...
            token{2}, ...
            index);
    end
end

assert(numel(unique(labels)) == count);

end


function summary = build_summary_table( ...
        loop_summary, iterations, assigned, coverage)

summary = table();

summary.campaign_id = ...
    string(loop_summary.campaign_id);

summary.coverage_complete = ...
    logical(loop_summary.coverage_complete);

summary.completed_iteration_count = ...
    height(iterations);

summary.final_run_count = ...
    double(iterations.accumulated_run_count(end));

summary.final_example_count = ...
    height(assigned);

summary.coverage_cell_count = ...
    coverage.coverage_cell_count;

summary.observed_coverage_cell_count = ...
    coverage.observed_coverage_cell_count;

summary.deficient_cell_count = ...
    coverage.deficient_cell_count;

summary.independent_condition_count = ...
    numel(unique(string( ...
        assigned.campaign_condition_id)));

summary.independent_run_count = ...
    numel(unique(string( ...
        assigned.campaign_run_id)));

summary.direction_count_min = ...
    min(double(assigned.campaign_direction_count));

summary.direction_count_max = ...
    max(double(assigned.campaign_direction_count));

summary.solid_angle_min_sr = ...
    min(double(assigned.campaign_solid_angle_sr));

summary.solid_angle_max_sr = ...
    max(double(assigned.campaign_solid_angle_sr));

end


function labels = make_edge_labels(edges)

count = numel(edges) - 1;
labels = strings(count,1);

for index = 1:count
    if index < count
        labels(index) = sprintf( ...
            "[%g,%g)", ...
            edges(index), ...
            edges(index+1));
    else
        labels(index) = sprintf( ...
            "[%g,%g]", ...
            edges(index), ...
            edges(index+1));
    end
end

end


function write_json(path_value, value)

file_id = fopen(path_value, "w");

if file_id < 0
    error("reqml:AdaptiveReportWriteFailed", ...
        "Could not create report file: %s", ...
        path_value);
end

cleanup = onCleanup(@() fclose(file_id));

fprintf(file_id, "%s", ...
    jsonencode(value, PrettyPrint=true));

clear cleanup

end


function validate_inputs( ...
        loop_output_root, examples_file, output_directory)

if ~isfolder(loop_output_root)
    error("reqml:AdaptiveReportLoopNotFound", ...
        "Loop output root was not found: %s", ...
        loop_output_root);
end

if ~isfile(examples_file)
    error("reqml:AdaptiveReportExamplesNotFound", ...
        "Examples file was not found: %s", ...
        examples_file);
end

if isfolder(output_directory)
    error("reqml:AdaptiveReportOutputExists", ...
        "Report output directory already exists: %s", ...
        output_directory);
end

end
