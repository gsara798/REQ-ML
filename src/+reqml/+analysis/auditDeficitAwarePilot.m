function audit = auditDeficitAwarePilot(pilot_root, options)
%AUDITDEFICITAWAREPILOT Audit hybrid analytic/deficit-aware center selection.

arguments
    pilot_root {mustBeTextScalar}
    options.V2Root {mustBeTextScalar} = ""
    options.V3Root {mustBeTextScalar} = ""
    options.MaximumIterations (1,1) double = 10
    options.OutputDirectory {mustBeTextScalar} = ""
    options.RecomputeRequestedMetrics (1,1) logical = true
    options.SaveOutputs (1,1) logical = true
end

pilot_root = string(pilot_root);
pilot = reqml.analysis.summarizeAdaptivePilotIterations(pilot_root, ...
    MaximumIterations=options.MaximumIterations, ...
    RecomputeRequestedMetrics=options.RecomputeRequestedMetrics);
iterations = pilot.iterations;

center_summary = table();
center_audit = table();
rejection_summary = table();
pre_state_audit = table();
previous_run_ids = strings(0,1);

for row = 1:height(iterations)
    index = double(iterations.iteration_index(row));
    directory = string(iterations.iteration_directory(row));
    dataset_directory = fullfile(directory,"dataset");
    examples_file = fullfile(dataset_directory,"examples.mat");
    summaries_file = fullfile(dataset_directory,"sample_summaries.csv");
    state_file = fullfile(directory,"pre_iteration_deficit_state.csv");
    coverage_file = fullfile(directory,"coverage_summary.csv");
    deficits_file = fullfile(directory,"coverage_deficits.csv");
    require_files([examples_file,summaries_file,state_file, ...
        coverage_file,deficits_file],index);

    loaded = load(examples_file,"examples");
    if ~isfield(loaded,"examples") || ~istable(loaded.examples)
        error("reqml:DeficitAwareAuditInvalidExamples", ...
            "Iteration %d examples.mat does not contain table examples.",index);
    end
    examples = loaded.examples;
    require_columns(examples,["campaign_run_id","campaign_condition_id", ...
        "center_selection_role","achieved_cell_key", ...
        "selected_for_requested_cell","selected_for_opportunistic_cell", ...
        "target_cell_mismatch","predicted_discrete_purity", ...
        "achieved_purity"],examples_file);
    all_run_ids = unique(string(examples.campaign_run_id),"stable");
    new_run_ids = setdiff(all_run_ids,previous_run_ids,"stable");
    selected = examples(ismember(string(examples.campaign_run_id),new_run_ids),:);
    previous_run_ids = all_run_ids;

    summaries = readtable(summaries_file,TextType="string");
    require_columns(summaries,"run_id",summaries_file);
    new_summaries = summaries(ismember(string(summaries.run_id),new_run_ids),:);
    state = readtable(state_file,TextType="string");
    coverage = readtable(coverage_file,TextType="string");
    deficits = readtable(deficits_file,TextType="string");
    require_columns(state,["cell_key","example_count","coverage_complete"], ...
        state_file);
    require_columns(coverage,["cell_key","example_count"],coverage_file);
    require_columns(deficits,"cell_key",deficits_file);

    selected.iteration_index = repmat(index,height(selected),1);
    selected = movevars(selected,"iteration_index","Before",1);
    center_audit = append_compatible(center_audit,selected,"selected centers");
    state.iteration_index = repmat(index,height(state),1);
    state = movevars(state,"iteration_index","Before",1);
    pre_state_audit = append_compatible(pre_state_audit,state,"deficit states");

    opportunistic = selected.selected_for_opportunistic_cell;
    target = selected.center_selection_role == "analytic_target";
    opportunity_keys = unique(string(selected.achieved_cell_key(opportunistic)));
    prior_unobserved = string(state.cell_key(double(state.example_count)==0));
    prior_incomplete = string(state.cell_key(~logical(state.coverage_complete)));
    current_observed = string(coverage.cell_key(double(coverage.example_count)>0));
    current_complete = setdiff(string(coverage.cell_key), ...
        string(deficits.cell_key),"stable");

    newly_observed_from_opportunistic = numel(intersect(opportunity_keys, ...
        intersect(prior_unobserved,current_observed)));
    newly_complete_from_opportunistic = numel(intersect(opportunity_keys, ...
        intersect(prior_incomplete,current_complete)));

    target_errors = abs(double(selected.achieved_purity(target)) - ...
        double(selected.predicted_discrete_purity(target)));
    target_errors = target_errors(isfinite(target_errors));
    [run_cell_pairs,condition_cell_pairs] = independence_pairs(selected(opportunistic,:));
    center_summary = [center_summary; table(index, ...
        double(iterations.executed_run_count(row)),height(selected),sum(target), ...
        sum(opportunistic),numel(opportunity_keys), ...
        newly_observed_from_opportunistic,newly_complete_from_opportunistic, ...
        height(run_cell_pairs),height(condition_cell_pairs), ...
        sum(logical(selected.target_cell_mismatch)), ...
        safe_ratio(height(selected),numel(new_run_ids)), ...
        safe_ratio(sum(opportunistic),numel(new_run_ids)), ...
        safe_median(target_errors),safe_max(target_errors), ...
        VariableNames=["iteration_index","executed_run_count", ...
        "selected_center_count","analytic_target_center_count", ...
        "opportunistic_center_count","opportunistic_helped_cell_count", ...
        "newly_observed_cells_with_opportunistic_contribution", ...
        "newly_complete_cells_with_opportunistic_contribution", ...
        "opportunistic_run_cell_pair_count", ...
        "opportunistic_condition_cell_pair_count", ...
        "analytic_target_cell_mismatch_count","mean_centers_per_run", ...
        "mean_opportunistic_centers_per_run", ...
        "median_absolute_target_predicted_purity_error", ...
        "maximum_absolute_target_predicted_purity_error"])]; %#ok<AGROW>

    rejection_summary = [rejection_summary; ...
        aggregate_rejections(new_summaries,index)]; %#ok<AGROW>
end

center_metrics = removevars(center_summary,"executed_run_count");
progress = outerjoin(pilot.progress,center_metrics,Keys="iteration_index", ...
    MergeKeys=true,Type="left");
comparison = build_comparison(options,pilot.progress);

audit = struct("schema_name","reqml_deficit_aware_pilot_audit", ...
    "schema_version","1.0","pilot_root",pilot_root, ...
    "iteration_progress",progress,"center_selection_summary",center_summary, ...
    "selected_center_audit",center_audit,"rejection_summary",rejection_summary, ...
    "pre_iteration_deficit_state",pre_state_audit, ...
    "requested_vs_achieved_summary",pilot.requested_vs_achieved, ...
    "first_ten_comparison",comparison);

if ~options.SaveOutputs
    audit.paths = struct();
    return
end
output_directory = string(options.OutputDirectory);
if strlength(output_directory)==0
    output_directory = fullfile(pilot_root,"analysis");
end
if ~isfolder(output_directory), mkdir(output_directory); end
files = struct( ...
    "iteration_progress",fullfile(output_directory,"v4_iteration_progress.csv"), ...
    "center_selection",fullfile(output_directory,"v4_center_selection_summary.csv"), ...
    "selected_centers",fullfile(output_directory,"v4_selected_center_audit.csv"), ...
    "rejections",fullfile(output_directory,"v4_rejection_summary.csv"), ...
    "pre_state",fullfile(output_directory,"v4_pre_iteration_deficit_state.csv"), ...
    "requests",fullfile(output_directory,"v4_requested_vs_achieved_summary.csv"), ...
    "comparison",fullfile(output_directory,"v4_v2_v3_first10_comparison.csv"));
writetable(progress,files.iteration_progress);
writetable(center_summary,files.center_selection);
writetable(center_audit,files.selected_centers);
writetable(rejection_summary,files.rejections);
writetable(pre_state_audit,files.pre_state);
writetable(pilot.requested_vs_achieved,files.requests);
writetable(comparison,files.comparison);
audit.paths = files;

end


function [run_pairs,condition_pairs] = independence_pairs(examples)
if isempty(examples)
    run_pairs = table(); condition_pairs = table(); return
end
run_pairs = unique(examples(:,["campaign_run_id","achieved_cell_key"]));
condition_pairs = unique(examples(:,["campaign_condition_id","achieved_cell_key"]));
end


function output = aggregate_rejections(summaries,index)
names = string(summaries.Properties.VariableNames);
names = names(startsWith(names,"rejected_"));
names = names(:);
if isempty(names)
    output = table(repmat(index,0,1),strings(0,1),zeros(0,1), ...
        VariableNames=["iteration_index","rejection_reason","rejection_count"]);
    return
end
counts = zeros(numel(names),1);
for i=1:numel(names), counts(i)=sum(double(summaries.(names(i))),"omitnan"); end
output = table(repmat(index,numel(names),1),erase(names,"rejected_"),counts, ...
    VariableNames=["iteration_index","rejection_reason","rejection_count"]);
end


function comparison = build_comparison(options,v4)
comparison = tag_progress(v4,"v4");
roots = [string(options.V2Root),string(options.V3Root)];
labels = ["v2","v3"];
for i=1:2
    if strlength(roots(i))==0, continue, end
    current = reqml.analysis.summarizeAdaptivePilotIterations(roots(i), ...
        MaximumIterations=options.MaximumIterations, ...
        RecomputeRequestedMetrics=options.RecomputeRequestedMetrics);
    comparison = [comparison; tag_progress(current.progress,labels(i))]; %#ok<AGROW>
end
comparison = sortrows(comparison,["iteration_index","campaign_version"]);
end


function value = tag_progress(progress,label)
value = progress;
value.campaign_version = repmat(label,height(value),1);
value = movevars(value,"campaign_version","Before",1);
end


function require_files(files,index)
for file=files
    if ~isfile(file)
        error("reqml:DeficitAwareAuditMissingArtifact", ...
            "Iteration %d is missing required artifact: %s",index,file);
    end
end
end


function require_columns(value,names,description)
missing = setdiff(string(names),string(value.Properties.VariableNames));
if ~isempty(missing)
    error("reqml:DeficitAwareAuditMissingColumn", ...
        "%s is missing column(s): %s",description,strjoin(missing,", "));
    end
end


function output = append_compatible(output,value,description)
if isempty(output), output=value; return, end
if ~isequal(string(output.Properties.VariableNames), ...
        string(value.Properties.VariableNames))
    error("reqml:DeficitAwareAuditSchemaMismatch", ...
        "Iteration %s schema changed.",description);
end
output = [output;value];
end


function value = safe_ratio(n,d)
if d==0, value=NaN; else, value=n/d; end
end
function value = safe_median(x)
if isempty(x), value=NaN; else, value=median(x); end
end
function value = safe_max(x)
if isempty(x), value=NaN; else, value=max(x); end
end
