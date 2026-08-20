function preflight()

repo_root = fileparts(fileparts(fileparts(mfilename("fullpath"))));
config_file = fullfile(repo_root, "configs", "validation", "eikonal_validation_v1.json");

cfg = jsondecode(fileread(config_file));

sim_root = getenv("SWSIM_ROOT");
assert(strlength(string(sim_root)) > 0, ...
    "SWSIM_ROOT environment variable is not defined.");

output_root = strrep(cfg.paths.output_root, ...
    "${REPOSITORY_ROOT}", repo_root);

assert(strcmp(cfg.paths.simulation_framework_root, "${SWSIM_ROOT}"), ...
    "Expected simulation_framework_root to use ${SWSIM_ROOT}.");

geometry_names = ["homogeneous","bilayer","circular_inclusion"];

for i = 1:numel(geometry_names)
    g = geometry_names(i);
    relative_path = string(cfg.simulation.base_config_mapping.(g));
    base_file = fullfile(sim_root, relative_path);
    assert(isfile(base_file), ...
        "Missing base config for %s: %s", g, base_file);
end

frequencies = cfg.design.frequencies_hz(:)';
regimes = cfg.design.field_regimes;

rows = struct([]);
k = 0;
condition_index = 0;

% Homogeneous controls
for cs = cfg.design.homogeneous.sws_m_s(:)'
    for f = frequencies
        for r = 1:numel(regimes)
            condition_index = condition_index + 1;
            for realization = 1:cfg.design.realizations.count
                k = k + 1;

                rows(k).condition_id = sprintf( ...
                    "hom_cs%g_f%d_%s", ...
                    cs, f, regimes(r).name);

                rows(k).design_id = sprintf( ...
                    "%s_r%02d", rows(k).condition_id, realization);

                rows(k).geometry = "homogeneous";
                rows(k).background_sws_m_s = cs;
                rows(k).target_sws_m_s = cs;
                rows(k).frequency_hz = f;
                rows(k).field_regime = string(regimes(r).name);
                rows(k).direction_count = regimes(r).direction_count;
                rows(k).in_plane_count = regimes(r).in_plane_count;
                rows(k).solid_angle_sr = regimes(r).solid_angle_sr;
                rows(k).realization_id = realization;
                rows(k).seed = cfg.design.realizations.base_seed ...
                    + 1000 * condition_index + realization;
            end
        end
    end
end

% Heterogeneous conditions
for g = string(cfg.design.heterogeneous.geometries(:))'
    for target = cfg.design.heterogeneous.target_sws_m_s(:)'
        for f = frequencies
            for r = 1:numel(regimes)
                condition_index = condition_index + 1;
                for realization = 1:cfg.design.realizations.count
                    k = k + 1;

                    rows(k).condition_id = sprintf( ...
                        "%s_bg%g_t%g_f%d_%s", ...
                        g, ...
                        cfg.design.heterogeneous.background_sws_m_s, ...
                        target, f, regimes(r).name);

                    rows(k).design_id = sprintf( ...
                        "%s_r%02d", rows(k).condition_id, realization);

                    rows(k).geometry = g;
                    rows(k).background_sws_m_s = ...
                        cfg.design.heterogeneous.background_sws_m_s;
                    rows(k).target_sws_m_s = target;
                    rows(k).frequency_hz = f;
                    rows(k).field_regime = string(regimes(r).name);
                    rows(k).direction_count = regimes(r).direction_count;
                    rows(k).in_plane_count = regimes(r).in_plane_count;
                    rows(k).solid_angle_sr = regimes(r).solid_angle_sr;
                    rows(k).realization_id = realization;
                    rows(k).seed = cfg.design.realizations.base_seed ...
                        + 1000 * condition_index + realization;
                end
            end
        end
    end
end

T = struct2table(rows);

expected_physical_conditions = ...
    numel(cfg.design.homogeneous.sws_m_s) * ...
    numel(frequencies) * numel(regimes) + ...
    numel(cfg.design.heterogeneous.geometries) * ...
    numel(cfg.design.heterogeneous.target_sws_m_s) * ...
    numel(frequencies) * numel(regimes);

assert(numel(unique(T.condition_id)) == expected_physical_conditions, ...
    "Unexpected number of unique physical conditions.");

assert(height(T) == expected_physical_conditions * ...
    cfg.design.realizations.count, ...
    "Unexpected number of planned runs.");

assert(numel(unique(T.design_id)) == height(T), ...
    "design_id values are not unique.");

assert(numel(unique(T.seed)) == height(T), ...
    "Seeds are not unique.");

fprintf("\nEikonal validation preflight PASSED\n");
fprintf("Config: %s\n", config_file);
fprintf("Simulation framework: %s\n", sim_root);
fprintf("Output root: %s\n", output_root);
fprintf("Physical conditions: %d\n", expected_physical_conditions);
fprintf("Planned runs: %d\n", height(T));
fprintf("  homogeneous: %d\n", ...
    sum(T.geometry == "homogeneous"));
fprintf("  bilayer: %d\n", ...
    sum(T.geometry == "bilayer"));
fprintf("  circular_inclusion: %d\n", ...
    sum(T.geometry == "circular_inclusion"));

disp(groupcounts(T, ["geometry","field_regime"]));

end
