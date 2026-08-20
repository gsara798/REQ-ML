function result = build_campaign()

design = materialize_design();

cfg = design.config;
repo_root = design.repo_root;

sim_root = string(getenv("SWSIM_ROOT"));
assert(strlength(sim_root) > 0, "SWSIM_ROOT is not defined.");

output_root = strrep(string(cfg.paths.output_root), ...
    "${REPOSITORY_ROOT}", repo_root);

campaign_dir = fullfile(output_root, "campaign");
if ~isfolder(campaign_dir)
    mkdir(campaign_dir);
end

conditions = design.conditions;
runs = design.runs;

writetable(conditions, fullfile(campaign_dir, "physical_conditions.csv"));
writetable(runs, fullfile(campaign_dir, "planned_runs.csv"));

geometries = ["homogeneous","bilayer","circular_inclusion"];

campaign_paths = strings(numel(geometries),1);

for ig = 1:numel(geometries)

    geometry = geometries(ig);

    base_relative = string(cfg.simulation.base_config_mapping.(geometry));
    base_config = fullfile(sim_root, base_relative);

    assert(isfile(base_config), ...
        "Missing base config: %s", base_config);

    condition_mask = conditions.geometry == geometry;
    geometry_conditions = conditions(condition_mask,:);

    run_mask = ismember(runs.condition_id, geometry_conditions.condition_id);
    geometry_runs = runs(run_mask,:);

    definitions = repmat(struct( ...
        "design_id","", ...
        "condition_id","", ...
        "realization_id",0, ...
        "overrides",struct([])), ...
        height(geometry_runs),1);

    for i = 1:height(geometry_runs)

        run = geometry_runs(i,:);
        condition = geometry_conditions( ...
            geometry_conditions.condition_id == run.condition_id,:);

        definitions(i).design_id = run.design_id;
        definitions(i).condition_id = run.condition_id;
        definitions(i).realization_id = run.realization_index;
        definitions(i).overrides = make_overrides( ...
            geometry, condition, run, cfg);
    end

    simulation_output = fullfile(output_root, "simulations", geometry);

    campaign = struct();
    campaign.schema_version = "1.2";
    campaign.backend = string(cfg.simulation.backend);
    campaign.campaign_name = cfg.campaign_id + "_" + geometry;
    campaign.base_config = base_config;
    campaign.runs = definitions;
    campaign.output = struct("directory", simulation_output);

    campaign_path = fullfile(campaign_dir, ...
        "simulation_campaign_" + geometry + ".json");

    write_json(campaign_path, campaign);
    campaign_paths(ig) = campaign_path;
end

manifest = struct();
manifest.schema_name = "reqml_eikonal_validation_campaign_manifest";
manifest.schema_version = "1.0";
manifest.campaign_id = string(cfg.campaign_id);
manifest.source_config = design.config_file;
manifest.condition_count = design.condition_count;
manifest.run_count = design.run_count;
manifest.req_M = cfg.req.M;
manifest.req_cs_guess_m_s = cfg.req.cs_guess_m_s;
manifest.created_utc = string(datetime("now","TimeZone","UTC"));
manifest.simulation_framework_root = sim_root;
manifest.campaign_files = campaign_paths;

write_json(fullfile(campaign_dir,"campaign_manifest.json"), manifest);

result = struct();
result.design = design;
result.campaign_dir = campaign_dir;
result.campaign_paths = campaign_paths;

fprintf("\nCampaign materialization PASSED\n");
fprintf("Conditions: %d\n", design.condition_count);
fprintf("Runs: %d\n", design.run_count);
fprintf("Campaign directory: %s\n", campaign_dir);

for ig = 1:numel(campaign_paths)
    fprintf("  %s\n", campaign_paths(ig));
end

end


function overrides = make_overrides(geometry, c, r, cfg)

paths = [
    "seed"
    "wavefield.frequency_hz"
    "domain.Lx_m"
    "domain.Lz_m"
    "medium.background_cs_m_s"
    "directions.count"
    "directions.in_plane_count"
    "directions.support.solid_angle_sr"
];

values = {
    r.seed
    c.frequency_hz
    cfg.design.domain.Lx_m
    cfg.design.domain.Lz_m
    c.background_sws_m_s
    c.direction_count
    c.in_plane_count
    c.solid_angle_sr
};

if geometry == "bilayer"
    paths(end+1) = "medium.objects[1].cs_m_s";
    values{end+1} = c.target_sws_m_s;

    paths(end+1) = "medium.objects[1].normal_angle_rad";
    values{end+1} = cfg.design.bilayer_geometry.normal_angle_rad;

    paths(end+1) = "medium.objects[1].offset_m";
    values{end+1} = cfg.design.bilayer_geometry.offset_m;

elseif geometry == "circular_inclusion"
    paths(end+1) = "medium.objects[1].cs_m_s";
    values{end+1} = c.target_sws_m_s;

    paths(end+1) = "medium.objects[1].center_xz_m";
    values{end+1} = [ ...
        cfg.design.inclusion_geometry.center_x_m, ...
        cfg.design.inclusion_geometry.center_z_m];

    paths(end+1) = "medium.objects[1].radius_m";
    values{end+1} = cfg.design.inclusion_geometry.radius_m;
end

overrides = repmat(struct("path","","value",[]), numel(paths),1);

for j = 1:numel(paths)
    overrides(j).path = paths(j);
    overrides(j).value = values{j};
end

end


function write_json(path, value)

fid = fopen(path,"w");
assert(fid >= 0, "Cannot write %s", path);

cleanup = onCleanup(@() fclose(fid));
fprintf(fid,"%s\n",jsonencode(value,PrettyPrint=true));

end
