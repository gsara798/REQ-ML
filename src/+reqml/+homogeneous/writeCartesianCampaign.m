function result = writeCartesianCampaign(config_file, options)
%WRITECARTESIANCAMPAIGN Write explicit simulation campaign and provenance.

arguments
    config_file {mustBeTextScalar}
    options.OutputDirectory {mustBeTextScalar} = ""
    options.Design struct = struct()
    options.CampaignId {mustBeTextScalar} = ""
end

config_file=string(config_file);
config=jsondecode(fileread(config_file));
repo_root=resolve_repository_root();
output_root=resolve_path(string(config.paths.output_root),repo_root);
output=string(options.OutputDirectory);
if strlength(output)==0, output=fullfile(output_root,"campaign"); end
if ~isfolder(output), mkdir(output); end
design=options.Design;
if isempty(fieldnames(design))
    design=reqml.homogeneous.materializeCartesianDesign(config);
end
campaign_id=string(options.CampaignId);
if strlength(campaign_id)==0, campaign_id=string(config.campaign_id); end

conditions=design.conditions;
runs=design.runs;
definitions=repmat(struct("design_id","","condition_id","", ...
    "realization_id",0,"overrides",struct([])),height(runs),1);
for index=1:height(runs)
    condition=conditions(conditions.condition_id==runs.condition_id(index),:);
    definitions(index).design_id=runs.design_id(index);
    definitions(index).condition_id=runs.condition_id(index);
    definitions(index).realization_id=runs.realization_index(index);
    definitions(index).overrides=make_overrides(condition,runs(index,:));
end

campaign=struct();
campaign.schema_version="1.2";
campaign.backend="swsynth";
campaign.campaign_name=campaign_id;
campaign.base_config=string(config.paths.simulation_base_config);
campaign.runs=definitions;
campaign.output=struct("directory", ...
    string(config.paths.simulation_output_root));

paths=struct();
paths.campaign_json=fullfile(output,"simulation_campaign.json");
paths.conditions_csv=fullfile(output,"physical_conditions.csv");
paths.runs_csv=fullfile(output,"planned_runs.csv");
paths.manifest_json=fullfile(output,"campaign_manifest.json");
write_json(paths.campaign_json,campaign);
writetable(conditions,paths.conditions_csv);
writetable(runs,paths.runs_csv);
manifest=struct("schema_name",design.schema_name, ...
    "schema_version",design.schema_version,"campaign_id",campaign_id, ...
    "source_config",config_file,"condition_count",design.condition_count, ...
    "run_count",design.run_count,"req_M",double(config.req.M), ...
    "req_cs_guess_m_s",double(config.req.cs_guess_m_s), ...
    "created_utc",string(datetime("now","TimeZone","UTC")));
write_json(paths.manifest_json,manifest);
result=struct("config",config,"design",design,"campaign",campaign, ...
    "paths",paths,"output_root",output_root);
end


function overrides=make_overrides(c,r)
p=["seed","wavefield.frequency_hz","domain.dx_m","domain.dz_m", ...
    "domain.Lx_m","domain.Lz_m","medium.background_cs_m_s", ...
    "directions.count","directions.in_plane_count", ...
    "directions.support.solid_angle_sr","directions.support.axis_xyz"];
v={r.seed,c.frequency_hz,c.dx_m,c.dz_m,c.domain_x_m,c.domain_z_m, ...
    c.cs_m_s,c.direction_count,c.in_plane_count,c.solid_angle_sr, ...
    [r.axis_x,r.axis_y,r.axis_z]};
overrides=repmat(struct("path","","value",[]),numel(p),1);
for i=1:numel(p), overrides(i).path=p(i); overrides(i).value=v{i}; end
end


function root=resolve_repository_root()
root=string(fileparts(fileparts(fileparts(fileparts(mfilename("fullpath"))))));
end
function value=resolve_path(value,root)
if startsWith(value,"${REPOSITORY_ROOT}/")
    value=fullfile(root,extractAfter(value,"${REPOSITORY_ROOT}/"));
end
end
function write_json(path,value)
fid=fopen(path,"w");
if fid<0, error("reqml:CannotWriteHomogeneousCampaign","Cannot write %s",path); end
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,"%s\n",jsonencode(value,PrettyPrint=true));
end
