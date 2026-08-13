function registry = scientific_5d_predictor_registry()
%SCIENTIFIC_5D_PREDICTOR_REGISTRY Compatibility registry for 5D models.
%
% The reusable observable Q0 contract is owned by q0_predictor_registry.

registry=reqml.training.q0_predictor_registry();
base_predictors=registry.q_spectrum_predictors;
composition_prediction_predictors="predicted_patch_purity";
registry.schema_name="reqml_scientific_5d_predictor_registry";
registry.purity_predictors=base_predictors;
registry.composition_prediction_predictors=composition_prediction_predictors;
registry.q_composition_predictors=[base_predictors; ...
    composition_prediction_predictors];
registry.targets=struct("purity","truth_material_purity", ...
    "quantile","q_target_from_center_truth");
end
