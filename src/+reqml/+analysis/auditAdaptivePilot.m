function audit = auditAdaptivePilot(pilot_root, options)
%AUDITADAPTIVEPILOT Write convergence and equal-budget pilot audits.

arguments
    pilot_root {mustBeTextScalar}
    options.ComparisonRoot {mustBeTextScalar} = ""
    options.MaximumIterations (1,1) double = 10
    options.OutputDirectory {mustBeTextScalar} = ""
    options.RecomputeRequestedMetrics (1,1) logical = true
    options.SaveOutputs (1,1) logical = true
end

pilot_root = string(pilot_root);
comparison_root = string(options.ComparisonRoot);

pilot = reqml.analysis.summarizeAdaptivePilotIterations(pilot_root, ...
    MaximumIterations=options.MaximumIterations, ...
    RecomputeRequestedMetrics=options.RecomputeRequestedMetrics);

coverage_audit = reqml.analysis.auditAdaptiveCoverage(pilot_root, ...
    RecentWindow=options.MaximumIterations, SaveOutputs=false);

comparison = table();
baseline = struct();
if strlength(comparison_root) > 0
    baseline = reqml.analysis.summarizeAdaptivePilotIterations( ...
        comparison_root, MaximumIterations=options.MaximumIterations, ...
        RecomputeRequestedMetrics=options.RecomputeRequestedMetrics);
    comparison = reqml.analysis.compareAdaptivePilotProgress( ...
        baseline.progress, pilot.progress, ...
        MaximumIterations=options.MaximumIterations);
end

audit = struct();
audit.schema_name = "reqml_adaptive_pilot_audit";
audit.schema_version = "1.0";
audit.pilot_root = pilot_root;
audit.comparison_root = comparison_root;
audit.progress = pilot.progress;
audit.requested_vs_achieved_summary = pilot.requested_vs_achieved;
audit.final_difficulty_by_dimension = coverage_audit.dimension_summary;
audit.comparison = comparison;
audit.difficult_cell_count = coverage_audit.difficult_cell_count;
audit.never_observed_cell_count = coverage_audit.never_observed_cell_count;
audit.stagnant_cell_count = coverage_audit.stagnant_cell_count;
audit.request_miss_cell_count = coverage_audit.request_miss_cell_count;
audit.coverage_audit = coverage_audit;
audit.baseline = baseline;

if ~options.SaveOutputs
    audit.paths = struct();
    return
end

output_directory = string(options.OutputDirectory);
if strlength(output_directory) == 0
    output_directory = fullfile(pilot_root, "analysis");
end

if ~isfolder(output_directory)
    [created, message] = mkdir(output_directory);
    if ~created
        error("reqml:AdaptivePilotAuditOutputCreateFailed", ...
            "Could not create pilot audit directory '%s': %s", ...
            output_directory, message);
    end
end

progress_file = fullfile(output_directory, ...
    "pilot_iteration_progress.csv");
requested_file = fullfile(output_directory, ...
    "pilot_requested_vs_achieved_summary.csv");
difficulty_file = fullfile(output_directory, ...
    "pilot_final_difficulty_by_dimension.csv");
comparison_file = fullfile(output_directory, ...
    "pilot_v2_v3_first10_comparison.csv");

writetable(audit.progress, progress_file);
writetable(audit.requested_vs_achieved_summary, requested_file);
writetable(audit.final_difficulty_by_dimension, difficulty_file);
writetable(audit.comparison, comparison_file);

audit.paths = struct( ...
    "output_directory", output_directory, ...
    "progress_csv", string(progress_file), ...
    "requested_vs_achieved_csv", string(requested_file), ...
    "difficulty_by_dimension_csv", string(difficulty_file), ...
    "comparison_csv", string(comparison_file));

end
