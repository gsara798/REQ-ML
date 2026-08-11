function result=buildV2ExternalEvaluationConfig(master_config_file,options)
%BUILDV2EXTERNALEVALUATIONCONFIG Assemble auditable cases from completed runs.
arguments
    master_config_file {mustBeTextScalar}
    options.OutputFile {mustBeTextScalar} = ""
end
master_config_file=string(master_config_file);
master=jsondecode(fileread(master_config_file));
repo=string(fileparts(fileparts(fileparts(fileparts(mfilename("fullpath"))))));
framework=reqml.config.resolveWorkspacePath(string(master.simulation_framework_root),RepositoryRoot=repo);
parts=cell(numel(master.campaigns),1);
for i=1:numel(master.campaigns)
    spec=master.campaigns(i);
    csv=fullfile(framework,"outputs","campaigns","scientific","reqml_q0_v2", ...
        string(spec.campaign_name),"campaign_runs.csv");
    if ~isfile(csv)
        error("reqml:MissingV2ExternalCampaign","Missing completed campaign ledger: %s",csv);
    end
    runs=readtable(csv,TextType="string",VariableNamingRule="preserve");
    complete=ismember(runs.status,["completed","skipped_completed"]);
    runs=runs(complete,:);
    valid=double(runs.valid);
    if height(runs)~=double(spec.expected_runs) || ...
            any(~isfinite(valid)) || any(valid~=1)
        error("reqml:IncompleteV2ExternalCampaign", ...
            "%s has %d valid completed runs; expected %d.", ...
            spec.campaign_name,height(runs),double(spec.expected_runs));
    end
    if any(~isfile(runs.wavefield_sample_path))
        error("reqml:MissingV2ExternalSample", ...
            "%s ledger references a missing wavefield sample.",spec.campaign_name);
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
    parts{i}=p;
end
cases=vertcat(parts{:});
if any(contains(cases.sample_file,"_v1"))
    error("reqml:V1ExternalDataReuse","A v2 external case resolves to v1 data.");
end
evaluation=struct("schema_name","reqml_external_q0_transfer_study", ...
    "schema_version","2.0","evaluation_id",string(master.evaluation_id), ...
    "model_bundle",string(master.model_bundle),"output_root",string(master.output_root), ...
    "feature_config",master.feature_config,"cases",table2struct(cases));
output=string(options.OutputFile);
if strlength(output)==0
    output=fullfile(reqml.config.resolveWorkspacePath(string(master.output_root), ...
        RepositoryRoot=repo),"evaluation_config.json");
end
folder=fileparts(output); if ~isfolder(folder), mkdir(folder); end
write_json(output,evaluation);
result=struct("config",evaluation,"cases",cases,"output_file",output);
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
