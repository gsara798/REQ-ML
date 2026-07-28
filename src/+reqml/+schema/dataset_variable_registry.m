function registry = dataset_variable_registry(examples)
%DATASET_VARIABLE_REGISTRY Classify REQ-ML dataset variables centrally.

arguments
    examples table
end

names = string(examples.Properties.VariableNames);
n = numel(names);

variable_name = names(:);
role = strings(n, 1);
source = strings(n, 1);
group = strings(n, 1);
trainable = false(n, 1);
numeric = false(n, 1);
classification_rule = strings(n, 1);

for index = 1:n
    name = variable_name(index);
    value = examples.(name);

    numeric(index) = ...
        isnumeric(value) || islogical(value);

    [role(index), ...
     source(index), ...
     group(index), ...
     trainable(index), ...
     classification_rule(index)] = ...
        classify_variable(name, numeric(index));
end

registry = table( ...
    variable_name, ...
    role, ...
    source, ...
    group, ...
    trainable, ...
    numeric, ...
    classification_rule);

end

function [role, source, group, trainable, rule] = ...
    classify_variable(name, is_numeric)

role = "unregistered";
source = "unknown";
group = "unknown";
trainable = false;
rule = "unregistered";

identifier_names = [
    "dataset_id"
    "sample_id"
    "example_id"
    "campaign_run_id"
    "campaign_hash_sha256"
    "campaign_sample_file"
    ];

coordinate_names = [
    "map_iz"
    "map_ix"
    "patch_idx"
    "cx"
    "cz"
    "x_center_m"
    "z_center_m"
    ];

prediction_names = [
    "q_pred"
    "k_pred"
    "cs_pred"
    ];

diagnostic_names = [
    "q_local_req"
    "M"
    "SIM_f0"
    "SIM_cs_bg"
    ];

theory_names = [
    "theory_field_class"
    "q_theory_single_wave_discrete"
    "q_theory_diffuse3d_discrete"
    "q_theory_discrete"
    "q_theory_valid"
    ];

operational_context_names = [
    "REQ_M"
    "REQ_cs_guess_m_s"
    "REQ_Nbins_effective"
    "GRID_dx_m"
    "GRID_dz_m"
    "REQ_dkx_rad_m"
    "REQ_dkz_rad_m"
    "campaign_frequency_hz"
    ];

target_names = [
    "target_cs_center_m_s"
    "target_k_center_rad_m"
    "q_target_from_center_truth"
    "target_valid"
    "target_definition"
    ];

campaign_metadata_names = [
    "campaign_ordinal"
    "campaign_backend"
    "campaign_scenario"
    "campaign_seed"
    "campaign_background_cs_m_s"
    "campaign_direction_count"
    ];

if ismember(name, identifier_names)
    role = "identifier";
    source = "dataset";
    group = "identity";
    rule = "explicit_identifier";
    return
end

if ismember(name, coordinate_names)
    role = "coordinate";
    source = "patch_geometry";
    group = "location";
    rule = "explicit_coordinate";
    return
end

if ismember(name, prediction_names)
    role = "prediction";
    source = "req_estimator";
    group = "estimator_output";
    rule = "explicit_prediction";
    return
end

if ismember(name, diagnostic_names)
    role = "diagnostic";
    source = "req_estimator";
    group = "req_diagnostic";
    rule = "explicit_diagnostic";
    return
end

if ismember(name, theory_names)
    role = "diagnostic";
    source = "discrete_req_theory";
    group = "theory_baseline";
    rule = "explicit_theory_baseline";
    return
end

% Must be checked before the general campaign metadata rule.
if ismember(name, operational_context_names)
    role = "metadata";
    source = "operational_configuration";
    group = "operational_context";
    trainable = true;
    rule = "explicit_trainable_context";
    return
end

if ismember(name, target_names)
    role = "target";
    source = "center_pixel_truth_mapping";
    group = "supervised_target";
    rule = "explicit_target";
    return
end

if ismember(name, campaign_metadata_names) || ...
        startsWith(name, "campaign_")
    role = "metadata";
    source = "simulation_campaign";
    group = "campaign";
    rule = "campaign_metadata";
    return
end

if startsWith(name, "truth_")
    role = "truth";
    source = "simulation_truth";
    group = truth_group(name);
    rule = "truth_prefix";
    return
end

if name == "req_mapping"
    role = "diagnostic";
    source = "req_estimator";
    group = "req_mapping";
    rule = "explicit_req_mapping";
    return
end

if name == "SIM_WaveModel"
    role = "metadata";
    source = "sample_physics";
    group = "wavefield_model";
    rule = "explicit_sample_metadata";
    return
end

if is_numeric
    role = "feature";
    source = "wavefield_derived";
    group = feature_group(name);
    trainable = true;
    rule = "remaining_numeric_feature";
end

end

function group = feature_group(name)

name = lower(string(name));

if startsWith(name, "ang_") || ...
        contains(name, "circ_") || ...
        contains(name, "direction")
    group = "angular";
elseif startsWith(name, "radial_") || ...
        contains(name, "lowk") || ...
        contains(name, "midband") || ...
        contains(name, "highk") || ...
        contains(name, "width_")
    group = "radial";
elseif startsWith(name, "ecum_") || ...
        contains(name, "slope") || ...
        contains(name, "curvature")
    group = "cumulative_energy";
elseif contains(name, "window")
    group = "window";
elseif contains(name, "peak")
    group = "spectral_peak";
elseif contains(name, "theory") || ...
        startsWith(name, "q_")
    group = "theory";
else
    group = "other_feature";
end

end

function group = truth_group(name)

if contains(name, "material")
    group = "material_truth";
elseif contains(name, "valid")
    group = "validity_truth";
elseif contains(name, "cs_")
    group = "sws_truth";
else
    group = "other_truth";
end

end
