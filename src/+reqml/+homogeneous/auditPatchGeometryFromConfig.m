function result = auditPatchGeometryFromConfig(config_file, options)
%AUDITPATCHGEOMETRYFROMCONFIG Compare every planned and extracted geometry.

arguments
    config_file {mustBeTextScalar}
    options.CampaignRunsCsv {mustBeTextScalar} = ""
    options.SampleSummariesCsv {mustBeTextScalar} = ""
    options.OutputDirectory {mustBeTextScalar} = ""
end

config_file=string(config_file);
config=jsondecode(fileread(config_file));
root=string(fileparts(fileparts(fileparts(fileparts(mfilename("fullpath"))))));
output_root=reqml.config.resolveWorkspacePath( ...
    string(config.paths.output_root),RepositoryRoot=root);
simulation_root=reqml.config.resolveWorkspacePath( ...
    string(config.paths.simulation_output_root),RepositoryRoot=root);
campaign_csv=string(options.CampaignRunsCsv);
if strlength(campaign_csv)==0
    campaign_csv=fullfile(simulation_root,string(config.campaign_id), ...
        "campaign_runs.csv");
end
summaries_csv=string(options.SampleSummariesCsv);
if strlength(summaries_csv)==0
    summaries_csv=fullfile(output_root,"dataset","sample_summaries.csv");
end
output=string(options.OutputDirectory);
if strlength(output)==0
    output=fullfile(output_root,"baseline","geometry_invariant");
end
if ~isfile(campaign_csv) || ~isfile(summaries_csv)
    error("reqml:MissingPatchGeometryArtifact", ...
        "Campaign or sample-summary artifact is missing.");
end
design=reqml.homogeneous.materializeCartesianDesign(config);
summaries=readtable(summaries_csv,TextType="string", ...
    VariableNamingRule="preserve");
coverage=reqml.homogeneous.summarizeCoverage( ...
    design,campaign_csv,summaries,TargetPatchesPerRun=double( ...
    config.patch_sampling.target_patches_per_run));
if ~isfolder(output), mkdir(output); end
audit_file=fullfile(output,"planned_vs_extracted_patch_geometry.csv");
mismatch_file=fullfile(output,"patch_geometry_mismatches.csv");
manifest_file=fullfile(output,"geometry_invariant_manifest.json");
writetable(coverage.geometry_audit,audit_file);
writetable(coverage.geometry_audit(~coverage.geometry_audit.geometry_match,:), ...
    mismatch_file);
[status,head]=system("git rev-parse HEAD"); if status~=0, head=""; end
manifest=struct("schema_name","reqml_patch_geometry_invariant", ...
    "schema_version","1.0","campaign_id",string(config.campaign_id), ...
    "source_config",config_file,"campaign_runs_csv",campaign_csv, ...
    "sample_summaries_csv",summaries_csv,"run_count",height(coverage.runs), ...
    "mismatch_count",coverage.geometry_mismatch_count, ...
    "valid",coverage.geometry_match,"git_head",strtrim(string(head)), ...
    "created_utc",string(datetime("now","TimeZone","UTC")));
write_json(manifest_file,manifest);
if ~coverage.geometry_match
    error("reqml:PlannedExtractedPatchGeometryMismatch", ...
        "%d runs have planned/extracted patch geometry mismatches.", ...
        coverage.geometry_mismatch_count);
end
result=struct("audit",coverage.geometry_audit,"coverage",coverage, ...
    "paths",struct("audit",audit_file,"mismatches",mismatch_file, ...
    "manifest",manifest_file));
end


function write_json(path,value)
fid=fopen(path,"w");
if fid<0, error("reqml:CannotWritePatchGeometryAudit", ...
        "Cannot write %s",path); end
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,"%s\n",jsonencode(value,PrettyPrint=true));
end
