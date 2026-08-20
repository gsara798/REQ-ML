function result = preflight()

[conditions,runs,cfg] = materialize_design();

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));

sim_root = string(getenv("SWSIM_ROOT"));
assert(strlength(sim_root)>0, ...
    "SWSIM_ROOT environment variable is not defined.");

base_config = replace( ...
    string(cfg.paths.simulation_base_config), ...
    "${SWSIM_ROOT}",sim_root);

assert(isfile(base_config), ...
    "Simulation base config not found: %s",base_config);

%% Core counts

expected_conditions = ...
    numel(cfg.design.cs_m_s) * ...
    numel(cfg.design.solid_angle_fraction);

expected_runs = ...
    expected_conditions * ...
    double(cfg.design.realizations_per_condition);

assert(height(conditions)==expected_conditions);
assert(height(runs)==expected_runs);

%% Uniqueness

assert(numel(unique(conditions.condition_id))==height(conditions), ...
    "Condition IDs are not unique.");

assert(numel(unique(runs.run_id))==height(runs), ...
    "Run IDs are not unique.");

assert(numel(unique(runs.seed))==height(runs), ...
    "Run seeds are not unique.");

%% Physical validation

assert(all(conditions.cs_true_m_s>0));
assert(all(conditions.frequency_hz>0));

assert(all(conditions.solid_angle_sr>0));
assert(all(conditions.solid_angle_sr<=4*pi + 1e-12));

assert(all(conditions.solid_angle_fraction>0));
assert(all(conditions.solid_angle_fraction<=1));

assert(all(conditions.direction_count>=1));
assert(all(conditions.in_plane_count>=0));
assert(all(conditions.in_plane_count<=conditions.direction_count));

%% Monotonic aperture schedule per cs

cs_values = unique(conditions.cs_true_m_s);

for i = 1:numel(cs_values)
    d = conditions(conditions.cs_true_m_s==cs_values(i),:);
    d = sortrows(d,"solid_angle_fraction");

    assert(all(diff(d.solid_angle_fraction)>0), ...
        "Aperture fractions are not strictly increasing.");
end

%% Smoke cases

assert(isfield(cfg,"smoke") && isfield(cfg.smoke,"cases"), ...
    "Config must define smoke.cases.");

smoke_cases = cfg.smoke.cases;
n_smoke = numel(smoke_cases);

assert(n_smoke>=1,"At least one smoke case is required.");

smoke_rows = cell(n_smoke,1);

for i = 1:n_smoke

    sc = smoke_cases(i);

    smoke_mask = ...
        abs(runs.cs_true_m_s-double(sc.cs_m_s))<1e-12 & ...
        abs(runs.solid_angle_fraction- ...
            double(sc.solid_angle_fraction))<1e-12 & ...
        runs.realization==double(sc.realization);

    assert(nnz(smoke_mask)==1, ...
        "Expected exactly one run for smoke case %s.", ...
        string(sc.name));

    sr = runs(smoke_mask,:);
    sr.smoke_name = repmat(string(sc.name),height(sr),1);

    smoke_rows{i} = sr;
end

smoke_runs = vertcat(smoke_rows{:});

assert(numel(unique(smoke_runs.run_id))==height(smoke_runs), ...
    "Smoke cases resolve to duplicate runs.");

%% Write materialized design

out_root = replace( ...
    string(cfg.paths.output_root), ...
    "${REPOSITORY_ROOT}",repo_root);

design_root = fullfile(out_root,"design");

if ~isfolder(design_root)
    mkdir(design_root);
end

writetable(conditions,fullfile(design_root,"physical_conditions.csv"));
writetable(runs,fullfile(design_root,"planned_runs.csv"));
writetable(smoke_runs,fullfile(design_root,"smoke_runs.csv"));

%% Console summary

fprintf("\nAngular aperture validation preflight\n");
fprintf("=====================================\n");
fprintf("Study ID              : %s\n",cfg.study_id);
fprintf("Physical conditions   : %d\n",height(conditions));
fprintf("Planned runs          : %d\n",height(runs));
fprintf("SWS values            : %s m/s\n", ...
    strjoin(string(unique(conditions.cs_true_m_s).'),", "));
fprintf("Frequency             : %g Hz\n",unique(conditions.frequency_hz));
fprintf("Direction count       : %d\n",unique(conditions.direction_count));
fprintf("In-plane count        : %d\n",unique(conditions.in_plane_count));
fprintf("Aperture levels       : %d\n", ...
    numel(unique(conditions.solid_angle_fraction)));
fprintf("Aperture range        : %.6f to %.6f sr\n", ...
    min(conditions.solid_angle_sr), ...
    max(conditions.solid_angle_sr));
fprintf("Realizations/condition: %d\n", ...
    cfg.design.realizations_per_condition);

fprintf("\nSmoke runs\n");
fprintf("----------\n");
disp(smoke_runs);

fprintf("Base config:\n  %s\n",base_config);
fprintf("Design output:\n  %s\n",design_root);

result = struct();
result.conditions = conditions;
result.runs = runs;
result.smoke_runs = smoke_runs;
result.base_config = base_config;
result.design_root = design_root;

end
