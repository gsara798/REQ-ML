function registry = scientific_5d_predictor_registry()
%SCIENTIFIC_5D_PREDICTOR_REGISTRY Predictor contract for 5D training.
%
% The same observable spectral and operational predictors are used by:
%
%   purity:
%       predictors -> truth_material_purity
%
%   q_spectrum:
%       predictors -> q_target_from_center_truth
%
%   q_spectrum_plus_composition:
%       predictors + out-of-fold composition predictions
%           -> q_target_from_center_truth
%
% Simulation truth, campaign design variables, achieved bins, coordinates,
% estimator outputs, IDs, and selection diagnostics are excluded.

operational_predictors = [
    "REQ_M"
    "REQ_cs_guess_m_s"
    "GRID_dx_m"
    "GRID_dz_m"
    "REQ_dkx_rad_m"
    "REQ_dkz_rad_m"
    "REQ_Nbins_effective"
    "campaign_frequency_hz"
    ];

spectral_predictors = [
    "radial_entropy"
    "width_75_25_rel"
    "width_90_50_rel"
    "width_90_10_rel"
    "lowk_frac_rel"
    "midband_frac_rel"
    "highk_frac_rel"

    "ang_entropy"
    "circ_var"
    "dom_dir_frac"
    "window_max_frac"
    "window_cf"
    "ang_moment_1"
    "ang_moment_2"
    "ang_moment_4"
    "ang_peak_count_rel"
    "ang_top1_window_frac"
    "ang_top2_window_frac"
    "ang_top3_window_frac"
    "ang_top2_to_top1"
    "ang_peak_separation_deg"

    "ecum_k10_norm_k50"
    "ecum_k25_norm_k50"
    "ecum_k75_norm_k50"
    "ecum_k90_norm_k50"
    "ecum_width_50_rel"
    "ecum_width_80_rel"
    "ecum_lower_tail_rel"
    "ecum_upper_tail_rel"
    "ecum_asymmetry_10_90"
    "ecum_asymmetry_25_75"
    "ecum_width_ratio_80_50"
    "ecum_lower_upper_width_ratio"
    "ecum_auc_norm"
    "ecum_increment_entropy"
    "ecum_increment_peak_frac"
    "ecum_increment_gini"
    "ecum_slope_max"
    "ecum_slope_peak_to_mean"
    "ecum_slope_iqr_to_median"

    "srad_proxy_centroid_k_norm"
    "srad_proxy_std_k_norm"
    "srad_proxy_skewness"
    "srad_proxy_kurtosis"
    "srad_proxy_peak_k_norm"
    "srad_proxy_peak_to_centroid"
    "srad_proxy_low_side_frac"
    "srad_proxy_high_side_frac"
    ];

base_predictors = [
    operational_predictors
    spectral_predictors
    ];

composition_prediction_predictors = [
    "predicted_patch_purity"
    "predicted_mixed_probability"
    "predicted_strong_mixed_probability"
    ];

registry = struct();

registry.schema_name = ...
    "reqml_scientific_5d_predictor_registry";
registry.schema_version = "1.0";

registry.operational_predictors = operational_predictors;
registry.spectral_predictors = spectral_predictors;

registry.purity_predictors = base_predictors;
registry.q_spectrum_predictors = base_predictors;

registry.composition_prediction_predictors = ...
    composition_prediction_predictors;

registry.q_composition_predictors = [
    base_predictors
    composition_prediction_predictors
    ];

registry.targets = struct( ...
    "purity", "truth_material_purity", ...
    "quantile", "q_target_from_center_truth");

registry.split_columns = [
    "example_id"
    "campaign_condition_id"
    "campaign_run_id"
    ];

registry.forbidden_exact_names = [
    "q_local_req"
    "q_pred"
    "k_pred"
    "cs_pred"
    "q_theory_discrete"
    "predicted_discrete_purity"
    "M"
    "SIM_f0"
    "SIM_cs_bg"
    "campaign_background_cs_m_s"
    "campaign_direction_count"
    "campaign_solid_angle_sr"
    "campaign_angular_entropy"
    "campaign_radial_entropy"
    "achieved_local_sws_m_s"
    "achieved_purity"
    "distance_to_interface_m"
    "nominal_angular_coverage"
    "frequency_hz"
    ];

registry.forbidden_prefixes = [
    "truth_"
    "target_"
    "achieved_"
    "campaign_primary_"
    "pre_iteration_"
    "distance_to_"
    "selected_for_"
    "center_"
    ];

registry.forbidden_suffixes = [
    "_id"
    "_key"
    "_bin"
    "_index"
    "_rank"
    ];

end
