function result=buildV2ExternalEvaluationConfig(master_config_file,options)
%BUILDV2EXTERNALEVALUATIONCONFIG Assemble auditable cases from completed runs.
arguments
    master_config_file {mustBeTextScalar}
    options.OutputFile {mustBeTextScalar} = ""
    options.CompletionMode {mustBeMember(options.CompletionMode,["complete","available"])} = "complete"
    options.EvaluationId {mustBeTextScalar} = ""
    options.OutputRoot {mustBeTextScalar} = ""
    options.MapStepPixels (1,1) double {mustBeNonnegative} = 0
    options.ResumeCasePredictions (1,1) logical = false
end
master_config_file=string(master_config_file);
master=jsondecode(fileread(master_config_file));
repo=string(fileparts(fileparts(fileparts(fileparts(mfilename("fullpath"))))));
framework=reqml.config.resolveWorkspacePath(string(master.simulation_framework_root),RepositoryRoot=repo);
parts=cell(0,1); audit=cell(numel(master.campaigns),1);
for i=1:numel(master.campaigns)
    spec=master.campaigns(i);
    csv=fullfile(framework,"outputs","campaigns","scientific","reqml_q0_v2", ...
        string(spec.campaign_name),"campaign_runs.csv");
    if ~isfile(csv)
        if options.CompletionMode=="complete"
            error("reqml:MissingV2ExternalCampaign","Missing completed campaign ledger: %s",csv);
        end
        audit{i}=campaign_audit(spec,0,0,"missing_ledger");
        continue
    end
    runs=readtable(csv,TextType="string",VariableNamingRule="preserve");
    complete=ismember(runs.status,["completed","skipped_completed"]);
    completed_count=nnz(complete); valid_complete=complete & double(runs.valid)==1;
    runs=runs(valid_complete,:); valid=double(runs.valid);
    if options.CompletionMode=="complete" && (height(runs)~=double(spec.expected_runs) || ...
            any(~isfinite(valid)) || any(valid~=1))
        error("reqml:IncompleteV2ExternalCampaign", ...
            "%s has %d valid completed runs; expected %d.", ...
            spec.campaign_name,height(runs),double(spec.expected_runs));
    end
    if any(~isfile(runs.wavefield_sample_path))
        error("reqml:MissingV2ExternalSample", ...
            "%s ledger references a missing wavefield sample.",spec.campaign_name);
    end
    if isempty(runs)
        audit{i}=campaign_audit(spec,completed_count,0,"no_valid_completed_runs");
        continue
    end
    p=table(string(runs.design_id),repmat(string(spec.backend),height(runs),1), ...
        repmat(string(spec.geometry),height(runs),1),field_from_id(runs.design_id), ...
        portable_path(runs.wavefield_sample_path,framework),double(runs.seed), ...
        double(runs.direction_count),double(runs.requested_in_plane_count), ...
        double(runs.solid_angle_sr),double(runs.retained_direction_count), ...
        double(runs.retained_in_plane_count),double(runs.angular_entropy), ...
        VariableNames=["label","backend","geometry","field_regime","sample_file", ...
        "seed","requested_direction_count","requested_in_plane_count", ...
        "requested_solid_angle_sr","realized_direction_count", ...
        "realized_in_plane_count","realized_angular_entropy"]);
    parts{end+1}=p; %#ok<AGROW>
    if height(runs)==double(spec.expected_runs), state="complete"; else, state="partial"; end
    audit{i}=campaign_audit(spec,completed_count,height(runs),state);
end
if isempty(parts), error("reqml:NoAvailableV2ExternalCases","No valid completed v2 external cases are available."); end
cases=vertcat(parts{:});
if any(contains(cases.sample_file,"_v1"))
    error("reqml:V1ExternalDataReuse","A v2 external case resolves to v1 data.");
end
evaluation_id=string(options.EvaluationId); if strlength(evaluation_id)==0, evaluation_id=string(master.evaluation_id); end
output_root=string(options.OutputRoot); if strlength(output_root)==0, output_root=string(master.output_root); end
expected=sum(double([master.campaigns.expected_runs]));
evaluation=struct("schema_name","reqml_external_q0_transfer_study", ...
    "schema_version","2.1","evaluation_id",evaluation_id, ...
    "evaluation_scope",string(options.CompletionMode), ...
    "partial_result",options.CompletionMode=="available", ...
    "expected_case_count",expected,"included_case_count",height(cases), ...
    "omitted_expected_case_count",expected-height(cases), ...
    "campaign_audit",[audit{:}], ...
    "model_bundle",string(master.model_bundle),"output_root",output_root, ...
    "feature_config",master.feature_config,"cases",table2struct(cases));
if options.MapStepPixels>0
    evaluation.feature_config.map_step_px=round(options.MapStepPixels);
end
evaluation.feature_config.resume_case_predictions=options.ResumeCasePredictions;
output=string(options.OutputFile);
if strlength(output)==0
    output=fullfile(reqml.config.resolveWorkspacePath(output_root, ...
        RepositoryRoot=repo),"evaluation_config.json");
end
folder=fileparts(output); if ~isfolder(folder), mkdir(folder); end
write_json(output,evaluation);
result=struct("config",evaluation,"cases",cases,"output_file",output);
end

function value=campaign_audit(spec,completed_count,included_count,state)
value=struct("backend",string(spec.backend),"geometry",string(spec.geometry), ...
    "campaign_name",string(spec.campaign_name),"expected_runs",double(spec.expected_runs), ...
    "completed_runs",double(completed_count),"included_runs",double(included_count), ...
    "state",string(state));
end

function value=field_from_id(ids)
ids=string(ids); value=strings(size(ids));
value(endsWith(ids,"_low"))="low";
value(endsWith(ids,"_mid"))="mid";
value(endsWith(ids,"_high"))="high";
if any(strlength(value)==0)
    error("reqml:UnknownV2ExternalAngularAnchor","Cannot infer low/mid/high anchor.");
end
end

function value=portable_path(paths,framework)
value=replace(string(paths),framework,"${SWSIM_ROOT}");
end

function write_json(path,value)
fid=fopen(path,"w");
if fid<0, error("reqml:CannotWriteV2ExternalConfig","Cannot write %s",path); end
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,"%s\n",jsonencode(value,PrettyPrint=true));
end
