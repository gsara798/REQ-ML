function result = build_campaigns()

[conditions,runs,cfg] = materialize_design();

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
sim_root = string(getenv("SWSIM_ROOT"));

assert(strlength(sim_root)>0,"SWSIM_ROOT is not defined.");

study_root = fullfile( ...
    repo_root,"outputs","validation","kwave_validation_v1");

campaign_root = fullfile(study_root,"campaign");
simulation_root = fullfile(study_root,"simulations");

if ~isfolder(campaign_root), mkdir(campaign_root); end
if ~isfolder(simulation_root), mkdir(simulation_root); end

%% Resolve study-local base configs

base.homogeneous = resolve_path( ...
    string(cfg.paths.homogeneous_base_config),repo_root,sim_root);

base.bilayer = resolve_path( ...
    string(cfg.paths.bilayer_base_config),repo_root,sim_root);

base.inclusion = resolve_path( ...
    string(cfg.paths.inclusion_base_config),repo_root,sim_root);

%% Full campaigns

geometries = ["homogeneous","bilayer","inclusion"];

full_paths = strings(numel(geometries),1);

for gi = 1:numel(geometries)

    geometry = geometries(gi);

    rr = runs(runs.geometry==geometry,:);

    campaign = make_campaign( ...
        "kwave_validation_v1_"+geometry, ...
        base.(geometry), ...
        fullfile(simulation_root,geometry), ...
        rr);

    path = fullfile( ...
        campaign_root, ...
        geometry+"_campaign.json");

    write_json(path,campaign);
    full_paths(gi) = path;

    writetable(rr,fullfile( ...
        campaign_root,geometry+"_planned_runs.csv"));
end

%% Smoke campaigns
%
% homogeneous:
%   cs=3, f=500, directional
%   cs=3, f=500, diffuse_like
%
% bilayer:
%   f=500, intermediate
%
% inclusion:
%   f=500, intermediate

smoke_paths = strings(3,1);

% Homogeneous smoke
rr = select_run(runs, ...
    "homogeneous",500,"directional",1,3);
rr = [rr; select_run(runs, ...
    "homogeneous",500,"diffuse_like",1,3)];

campaign = make_campaign( ...
    "kwave_validation_v1_smoke_v2_homogeneous", ...
    base.homogeneous, ...
    fullfile(simulation_root,"smoke","homogeneous"), ...
    rr);

smoke_paths(1) = fullfile( ...
    campaign_root,"smoke_homogeneous.json");

write_json(smoke_paths(1),campaign);

% Bilayer smoke
rr = select_run(runs, ...
    "bilayer",500,"intermediate",1,NaN);

campaign = make_campaign( ...
    "kwave_validation_v1_smoke_v2_bilayer", ...
    base.bilayer, ...
    fullfile(simulation_root,"smoke","bilayer"), ...
    rr);

smoke_paths(2) = fullfile( ...
    campaign_root,"smoke_bilayer.json");

write_json(smoke_paths(2),campaign);

% Inclusion smoke
rr = select_run(runs, ...
    "inclusion",500,"intermediate",1,NaN);

campaign = make_campaign( ...
    "kwave_validation_v1_smoke_v2_inclusion", ...
    base.inclusion, ...
    fullfile(simulation_root,"smoke","inclusion"), ...
    rr);

smoke_paths(3) = fullfile( ...
    campaign_root,"smoke_inclusion.json");

write_json(smoke_paths(3),campaign);

%% Design tables

writetable(conditions,fullfile(campaign_root,"physical_conditions.csv"));
writetable(runs,fullfile(campaign_root,"planned_runs.csv"));

%% Manifest

manifest = struct();

manifest.schema_name = ...
    "reqml_kwave_validation_v1_campaign_manifest";
manifest.schema_version = "1.0";
manifest.study_id = "kwave_validation_v1";

manifest.dimension = 3;
manifest.condition_count = height(conditions);
manifest.run_count = height(runs);

manifest.full_campaigns = cellstr(full_paths);
manifest.smoke_campaigns = cellstr(smoke_paths);

manifest.homogeneous_runs = nnz(runs.geometry=="homogeneous");
manifest.bilayer_runs = nnz(runs.geometry=="bilayer");
manifest.inclusion_runs = nnz(runs.geometry=="inclusion");

manifest.created_utc = ...
    string(datetime("now","TimeZone","UTC"));

write_json( ...
    fullfile(campaign_root,"campaign_manifest.json"), ...
    manifest);

fprintf("\nk-Wave campaign materialization PASSED\n");
fprintf("======================================\n");
fprintf("Homogeneous full : %d runs\n", ...
    nnz(runs.geometry=="homogeneous"));
fprintf("Bilayer full     : %d runs\n", ...
    nnz(runs.geometry=="bilayer"));
fprintf("Inclusion full   : %d runs\n", ...
    nnz(runs.geometry=="inclusion"));
fprintf("Total full       : %d runs\n",height(runs));
fprintf("Smoke            : 4 runs\n");

fprintf("\nFull campaigns:\n");
for i = 1:numel(full_paths)
    fprintf("  %s\n",full_paths(i));
end

fprintf("\nSmoke campaigns:\n");
for i = 1:numel(smoke_paths)
    fprintf("  %s\n",smoke_paths(i));
end

result = struct();
result.conditions = conditions;
result.runs = runs;
result.full_campaigns = full_paths;
result.smoke_campaigns = smoke_paths;

end


function campaign = make_campaign(name,base_config,output_dir,runs)

definitions = repmat(struct( ...
    "design_id","", ...
    "condition_id","", ...
    "realization_id",0, ...
    "overrides",struct([])), ...
    height(runs),1);

for i = 1:height(runs)

    r = runs(i,:);

    definitions(i).design_id = string(r.design_id);
    definitions(i).condition_id = string(r.condition_id);
    definitions(i).realization_id = double(r.realization);

    definitions(i).overrides = make_overrides(r);
end

campaign = struct();

campaign.schema_version = "1.2";
campaign.backend = "kwsim";
campaign.campaign_name = string(name);
campaign.base_config = string(base_config);

campaign.output = struct( ...
    "directory",string(output_dir));

campaign.runs = definitions;

end


function overrides = make_overrides(r)

paths = [
    "seed"
    "source.f0_hz"
    "source.geometry_seed"
    "source.vibrator_count"
    "source.exact_in_plane_sources"
    "source.minimum_in_plane_sources"
    "source.minimum_out_of_plane_sources"
    "source.angular_support_solid_angle_sr"
];

values = {
    double(r.seed)
    double(r.frequency_hz)
    double(r.geometry_seed)
    double(r.vibrator_count)
    double(r.exact_in_plane_sources)
    double(r.minimum_in_plane_sources)
    double(r.minimum_out_of_plane_sources)
    double(r.solid_angle_sr)
};

% Homogeneous additionally changes material speed.
if string(r.geometry)=="homogeneous"

    paths(end+1) = "medium.cs_m_s";
    values{end+1} = double(r.cs_target_m_s);
end

overrides = repmat( ...
    struct("path","","value",[]), ...
    numel(paths),1);

for j = 1:numel(paths)

    overrides(j).path = paths(j);
    overrides(j).value = values{j};
end

end


function r = select_run(runs,geometry,f0,regime,realization,cs)

mask = ...
    runs.geometry==geometry & ...
    runs.frequency_hz==f0 & ...
    runs.regime==regime & ...
    runs.realization==realization;

if isfinite(cs)
    mask = mask & abs(runs.cs_target_m_s-cs)<1e-12;
end

r = runs(mask,:);

assert(height(r)==1, ...
    "Expected one smoke run for %s / %g Hz / %s.", ...
    geometry,f0,regime);

end


function path = resolve_path(path,repo_root,sim_root)

path = replace(path,"${REPOSITORY_ROOT}",repo_root);
path = replace(path,"${SWSIM_ROOT}",sim_root);

end


function write_json(path,value)

fid = fopen(path,"w");
assert(fid>=0,"Cannot write %s",path);

cleanup = onCleanup(@() fclose(fid));

fprintf(fid,"%s\n", ...
    jsonencode(value,PrettyPrint=true));

end
