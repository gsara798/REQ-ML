function result = build_campaign()

[conditions,runs,cfg] = materialize_design();

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));

sim_root = string(getenv("SWSIM_ROOT"));
assert(strlength(sim_root)>0,"SWSIM_ROOT is not defined.");

base_config = replace( ...
    string(cfg.paths.simulation_base_config), ...
    "${SWSIM_ROOT}",sim_root);

assert(isfile(base_config),"Missing base config: %s",base_config);

output_root = replace( ...
    string(cfg.paths.output_root), ...
    "${REPOSITORY_ROOT}",repo_root);

campaign_dir = fullfile(output_root,"campaign");
simulation_output = fullfile(output_root,"simulations");

if ~isfolder(campaign_dir), mkdir(campaign_dir); end
if ~isfolder(simulation_output), mkdir(simulation_output); end

definitions = repmat(struct( ...
    "design_id","", ...
    "condition_id","", ...
    "realization_id",0, ...
    "overrides",struct([])), ...
    height(runs),1);

for i = 1:height(runs)

    r = runs(i,:);
    c = conditions(conditions.condition_id==r.condition_id,:);

    assert(height(c)==1);

    definitions(i).design_id = string(r.run_id);
    definitions(i).condition_id = string(r.condition_id);
    definitions(i).realization_id = double(r.realization);
    definitions(i).overrides = make_overrides(c,r);
end

campaign = struct();
campaign.schema_version = "1.2";
campaign.backend = "swsynth";
campaign.campaign_name = string(cfg.study_id);
campaign.base_config = base_config;
campaign.runs = definitions;
campaign.output = struct("directory",simulation_output);

campaign_path = fullfile(campaign_dir,"simulation_campaign.json");
write_json(campaign_path,campaign);

manifest = struct();
manifest.schema_name = ...
    "reqml_angular_aperture_inplane_sweep_campaign_manifest";
manifest.schema_version = "1.0";
manifest.study_id = string(cfg.study_id);
manifest.source_config = fullfile( ...
    repo_root,"configs","validation", ...
    "angular_aperture_inplane_sweep_cs3_v1.json");
manifest.base_config = base_config;
manifest.condition_count = height(conditions);
manifest.run_count = height(runs);
manifest.direction_count = double(cfg.design.direction_count);
manifest.in_plane_counts = double(cfg.design.in_plane_count(:));
manifest.aperture_fractions = double(cfg.design.solid_angle_fraction(:));
manifest.realizations_per_condition = ...
    double(cfg.design.realizations_per_condition);
manifest.req_M_values = double(cfg.req.M_values(:));
manifest.req_cs_guess_m_s = double(cfg.req.cs_guess_m_s);
manifest.q_oracle_enabled = true;
manifest.q_pred_enabled = true;
manifest.q_theory_enabled = false;
manifest.created_utc = string(datetime("now","TimeZone","UTC"));
manifest.simulation_framework_root = sim_root;
manifest.campaign_file = campaign_path;

write_json(fullfile(campaign_dir,"campaign_manifest.json"),manifest);

writetable(conditions,fullfile(campaign_dir,"physical_conditions.csv"));
writetable(runs,fullfile(campaign_dir,"planned_runs.csv"));

fprintf("\nAngular aperture x in-plane campaign materialization PASSED\n");
fprintf("===========================================================\n");
fprintf("Conditions       : %d\n",height(conditions));
fprintf("Runs             : %d\n",height(runs));
fprintf("Directions       : %d\n",cfg.design.direction_count);
fprintf("In-plane levels  : %d\n",numel(cfg.design.in_plane_count));
fprintf("Aperture levels  : %d\n",numel(cfg.design.solid_angle_fraction));
fprintf("Realizations     : %d\n",cfg.design.realizations_per_condition);
fprintf("Campaign file    : %s\n",campaign_path);

result = struct( ...
    "conditions",conditions, ...
    "runs",runs, ...
    "config",cfg, ...
    "campaign_path",campaign_path);

end


function overrides = make_overrides(c,r)

paths = [
    "seed"
    "wavefield.frequency_hz"
    "medium.background_cs_m_s"
    "directions.count"
    "directions.in_plane_count"
    "directions.support.solid_angle_sr"
];

values = {
    double(r.seed)
    double(c.frequency_hz)
    double(c.cs_true_m_s)
    double(c.direction_count)
    double(c.in_plane_count)
    double(c.solid_angle_sr)
};

overrides = repmat( ...
    struct("path","","value",[]), ...
    numel(paths),1);

for j = 1:numel(paths)
    overrides(j).path = paths(j);
    overrides(j).value = values{j};
end

end


function write_json(path,value)

fid = fopen(path,"w");
assert(fid>=0,"Cannot write %s",path);

cleanup = onCleanup(@() fclose(fid));
fprintf(fid,"%s\n",jsonencode(value,PrettyPrint=true));

end
