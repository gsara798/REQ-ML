function [conditions,runs,cfg] = materialize_design()

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));

config_file = fullfile( ...
    repo_root,"configs","validation", ...
    "kwave_validation_v1","config.json");

cfg = jsondecode(fileread(config_file));

freqs = double(cfg.design.frequencies_hz(:));
regimes = cfg.design.regimes;
nreal = double(cfg.design.realizations_per_condition);

rows = {};
k = 0;

%% Homogeneous: 3 cs x 2 f x 3 regimes = 18 conditions
cs_values = double(cfg.design.homogeneous_cs_m_s(:));

for ci = 1:numel(cs_values)
    cs = cs_values(ci);

    for fi = 1:numel(freqs)
        f0 = freqs(fi);

        for ri = 1:numel(regimes)
            reg = regimes(ri);

            k = k+1;

            rows{k,1} = make_condition( ...
                k,"homogeneous",cs,NaN, ...
                f0,reg);
        end
    end
end

%% Bilayer 2->3: 2 f x 3 regimes = 6 conditions
for fi = 1:numel(freqs)
    f0 = freqs(fi);

    for ri = 1:numel(regimes)
        reg = regimes(ri);

        k = k+1;

        rows{k,1} = make_condition( ...
            k,"bilayer", ...
            double(cfg.design.bilayer.background_cs_m_s), ...
            double(cfg.design.bilayer.stiff_cs_m_s), ...
            f0,reg);
    end
end

%% Inclusion 2->4: 2 f x 3 regimes = 6 conditions
for fi = 1:numel(freqs)
    f0 = freqs(fi);

    for ri = 1:numel(regimes)
        reg = regimes(ri);

        k = k+1;

        rows{k,1} = make_condition( ...
            k,"inclusion", ...
            double(cfg.design.inclusion.background_cs_m_s), ...
            double(cfg.design.inclusion.inclusion_cs_m_s), ...
            f0,reg);
    end
end

conditions = struct2table(vertcat(rows{:}));

%% Two independent realizations per physical condition
run_rows = cell(height(conditions)*nreal,1);
ridx = 0;

for ci = 1:height(conditions)

    for r = 1:nreal

        ridx = ridx+1;

        run_rows{ridx} = struct( ...
            "run_index",ridx, ...
            "condition_id",string(conditions.condition_id(ci)), ...
            "design_id", ...
                string(conditions.condition_id(ci)) + ...
                "_r" + sprintf("%02d",r), ...
            "geometry",string(conditions.geometry(ci)), ...
            "cs_background_m_s", ...
                double(conditions.cs_background_m_s(ci)), ...
            "cs_target_m_s", ...
                double(conditions.cs_target_m_s(ci)), ...
            "frequency_hz", ...
                double(conditions.frequency_hz(ci)), ...
            "regime",string(conditions.regime(ci)), ...
            "vibrator_count", ...
                double(conditions.vibrator_count(ci)), ...
            "exact_in_plane_sources", ...
                double(conditions.exact_in_plane_sources(ci)), ...
            "minimum_in_plane_sources", ...
                double(conditions.minimum_in_plane_sources(ci)), ...
            "minimum_out_of_plane_sources", ...
                double(conditions.minimum_out_of_plane_sources(ci)), ...
            "solid_angle_sr", ...
                double(conditions.solid_angle_sr(ci)), ...
            "realization",r, ...
            "seed", ...
                double(cfg.design.seed_base) + 100*ci + r, ...
            "geometry_seed", ...
                double(cfg.design.geometry_seed_base) + 100*ci + r);
    end
end

runs = struct2table(vertcat(run_rows{:}));

end


function row = make_condition(index,geometry,cs_bg,cs_target,f0,reg)

if geometry == "homogeneous"
    cs_target = cs_bg;
end

row = struct();

row.condition_index = index;

row.condition_id = sprintf( ...
    "%s_cs%g_f%d_%s", ...
    geometry,cs_target,round(f0),string(reg.name));

row.geometry = string(geometry);
row.cs_background_m_s = cs_bg;
row.cs_target_m_s = cs_target;
row.frequency_hz = f0;

row.regime = string(reg.name);
row.vibrator_count = double(reg.vibrator_count);
row.exact_in_plane_sources = ...
    double(reg.exact_in_plane_sources);
row.minimum_in_plane_sources = ...
    double(reg.minimum_in_plane_sources);
row.minimum_out_of_plane_sources = ...
    double(reg.minimum_out_of_plane_sources);
row.solid_angle_sr = double(reg.solid_angle_sr);

end
