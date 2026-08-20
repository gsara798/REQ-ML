function design = materialize_design()

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
config_file = fullfile(repo_root, "configs", "validation", ...
    "eikonal_validation_v1.json");

cfg = jsondecode(fileread(config_file));

frequencies = cfg.design.frequencies_hz(:)';
regimes = cfg.design.field_regimes;

condition_rows = cell(0,1);
run_rows = cell(0,1);

c = 0;
ridx = 0;

% Homogeneous controls
for cs = cfg.design.homogeneous.sws_m_s(:)'
    for f = frequencies
        for ir = 1:numel(regimes)
            c = c + 1;

            condition_id = sprintf("hom_cs%g_f%d_%s", ...
                cs, f, regimes(ir).name);

            condition_rows{c,1} = make_condition( ...
                condition_id, "homogeneous", cs, cs, f, regimes(ir));

            for realization = 1:cfg.design.realizations.count
                ridx = ridx + 1;
                run_rows{ridx,1} = make_run( ...
                    condition_id, realization, ...
                    cfg.design.realizations.base_seed + ...
                    1000*c + realization);
            end
        end
    end
end

% Heterogeneous
for geometry = string(cfg.design.heterogeneous.geometries(:))'
    for target = cfg.design.heterogeneous.target_sws_m_s(:)'
        for f = frequencies
            for ir = 1:numel(regimes)
                c = c + 1;

                condition_id = sprintf("%s_bg%g_t%g_f%d_%s", ...
                    geometry, ...
                    cfg.design.heterogeneous.background_sws_m_s, ...
                    target, f, regimes(ir).name);

                condition_rows{c,1} = make_condition( ...
                    condition_id, geometry, ...
                    cfg.design.heterogeneous.background_sws_m_s, ...
                    target, f, regimes(ir));

                for realization = 1:cfg.design.realizations.count
                    ridx = ridx + 1;
                    run_rows{ridx,1} = make_run( ...
                        condition_id, realization, ...
                        cfg.design.realizations.base_seed + ...
                        1000*c + realization);
                end
            end
        end
    end
end

design = struct();
design.schema_name = "reqml_eikonal_validation_design";
design.schema_version = "1.0";
design.config = cfg;
design.config_file = config_file;
design.repo_root = repo_root;
design.conditions = struct2table(vertcat(condition_rows{:}));
design.runs = struct2table(vertcat(run_rows{:}));
design.condition_count = height(design.conditions);
design.run_count = height(design.runs);

end


function row = make_condition(id, geometry, bg, target, f, regime)

row = struct();
row.condition_id = string(id);
row.geometry = string(geometry);
row.background_sws_m_s = bg;
row.target_sws_m_s = target;
row.frequency_hz = f;
row.field_regime = string(regime.name);
row.direction_count = regime.direction_count;
row.in_plane_count = regime.in_plane_count;
row.solid_angle_sr = regime.solid_angle_sr;

end


function row = make_run(condition_id, realization, seed)

row = struct();
row.design_id = sprintf("%s_r%02d", condition_id, realization);
row.condition_id = string(condition_id);
row.realization_index = realization;
row.seed = seed;

end
