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

%% Full campaign

definitions = make_definitions(runs,conditions);

campaign = struct();
campaign.schema_version = "1.2";
campaign.backend = "swsynth";
campaign.campaign_name = string(cfg.study_id);
campaign.base_config = base_config;
campaign.runs = definitions;
campaign.output = struct("directory",simulation_output);

campaign_path = fullfile(campaign_dir,"simulation_campaign.json");
write_json(campaign_path,campaign);

%% Smoke campaign

smoke_cases = cfg.smoke.cases;
smoke_rows = cell(numel(smoke_cases),1);

for i = 1:numel(smoke_cases)

    sc = smoke_cases(i);

    mask = ...
        abs(runs.cs_true_m_s-double(sc.cs_m_s))<1e-12 & ...
        abs(runs.solid_angle_fraction- ...
            double(sc.solid_angle_fraction))<1e-12 & ...
        runs.realization==double(sc.realization);

    assert(nnz(mask)==1, ...
        "Expected one run for smoke case %s.",string(sc.name));

    sr = runs(mask,:);
    sr.smoke_name = repmat(string(sc.name),height(sr),1);
    smoke_rows{i} = sr;
end

smoke_runs = vertcat(smoke_rows{:});
smoke_definitions = make_definitions(smoke_runs,conditions);

smoke_output = fullfile(output_root,"smoke_simulation");

smoke_campaign = struct();
smoke_campaign.schema_version = "1.2";
smoke_campaign.backend = "swsynth";
smoke_campaign.campaign_name = string(cfg.study_id) + "_smoke";
smoke_campaign.base_config = base_config;
smoke_campaign.runs = smoke_definitions;
smoke_campaign.output = struct("directory",smoke_output);

smoke_campaign_path = fullfile( ...
    campaign_dir,"simulation_campaign_smoke.json");

write_json(smoke_campaign_path,smoke_campaign);

%% Manifest

manifest = struct();
manifest.schema_name = ...
    "reqml_angular_aperture_validation_campaign_manifest";
manifest.schema_version = "1.0";
manifest.study_id = string(cfg.study_id);
manifest.source_config = fullfile( ...
    repo_root,"configs","validation", ...
    "angular_aperture_validation_v1.json");

manifest.base_config = base_config;
manifest.condition_count = height(conditions);
manifest.run_count = height(runs);
manifest.smoke_run_count = height(smoke_runs);

manifest.cs_m_s = double(cfg.design.cs_m_s(:)).';
manifest.frequency_hz = double(cfg.design.frequency_hz);
manifest.direction_count = double(cfg.design.direction_count);
manifest.in_plane_count = double(cfg.design.in_plane_count);

manifest.aperture_level_count = ...
    numel(cfg.design.solid_angle_fraction);

manifest.realizations_per_condition = ...
    double(cfg.design.realizations_per_condition);

manifest.req_M = double(cfg.req.M);
manifest.req_cs_guess_m_s = double(cfg.req.cs_guess_m_s);

manifest.q_oracle_enabled = ...
    logical(cfg.analysis.compute_q_oracle);

manifest.q_theory_enabled = ...
    logical(cfg.analysis.compute_q_theory);

manifest.created_utc = ...
    string(datetime("now","TimeZone","UTC"));

manifest.simulation_framework_root = sim_root;
manifest.full_campaign_file = campaign_path;
manifest.smoke_campaign_file = smoke_campaign_path;

write_json(fullfile(campaign_dir,"campaign_manifest.json"),manifest);

%% Console

fprintf("\nAngular aperture campaign materialization PASSED\n");
fprintf("===============================================\n");
fprintf("Physical conditions : %d\n",height(conditions));
fprintf("Planned runs        : %d\n",height(runs));
fprintf("Direction count     : %d\n",cfg.design.direction_count);
fprintf("In-plane count      : %d\n",cfg.design.in_plane_count);
fprintf("Smoke runs          : %d\n",height(smoke_runs));

fprintf("\nSmoke definitions\n");
fprintf("-----------------\n");
disp(smoke_runs);

fprintf("Full campaign:\n  %s\n",campaign_path);
fprintf("Smoke campaign:\n  %s\n",smoke_campaign_path);

result = struct();
result.conditions = conditions;
result.runs = runs;
result.smoke_runs = smoke_runs;
result.config = cfg;
result.campaign_path = campaign_path;
result.smoke_campaign_path = smoke_campaign_path;

end


function definitions = make_definitions(runs,conditions)

definitions = repmat(struct( ...
    "design_id","", ...
    "condition_id","", ...
    "realization_id",0, ...
    "overrides",struct([])), ...
    height(runs),1);

for i = 1:height(runs)

    r = runs(i,:);
    c = conditions(conditions.condition_id==r.condition_id,:);

    assert(height(c)==1, ...
        "Expected one condition for %s.",r.condition_id);

    definitions(i).design_id = string(r.run_id);
    definitions(i).condition_id = string(r.condition_id);
    definitions(i).realization_id = double(r.realization);
    definitions(i).overrides = make_overrides(c,r);
end

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
