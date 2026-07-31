function model = fit_regression_model( ...
    X, target, train_mask, model_spec)
%FIT_REGRESSION_MODEL Fit one reproducible q-regression model.
%
% Supported types:
%   ridge
%   bagged_trees

arguments
    X double
    target (:,1) double
    train_mask (:,1) logical
    model_spec struct
end

n = size(X, 1);

if numel(target) ~= n || numel(train_mask) ~= n
    error("reqml:TrainingSizeMismatch", ...
        "Predictors, target, and train mask must have equal row counts.");
end

if ~isfield(model_spec, "id") || ...
        ~isfield(model_spec, "type") || ...
        ~isfield(model_spec, "random_seed")
    error("reqml:InvalidModelSpecification", ...
        "Model specification requires id, type, and random_seed.");
end

valid_train = ...
    train_mask & ...
    isfinite(target) & ...
    all(isfinite(X), 2);

if nnz(valid_train) < 10
    error("reqml:InsufficientTrainingRows", ...
        "Only %d valid training rows are available.", nnz(valid_train));
end

Xtrain_raw = X(valid_train, :);
ytrain = target(valid_train);

mu = mean(Xtrain_raw, 1);
sigma = std(Xtrain_raw, 0, 1);

constant_predictors = ...
    ~isfinite(sigma) | ...
    sigma <= eps(max(abs(mu), 1));

sigma(constant_predictors) = 1;

Xtrain = (Xtrain_raw - mu) ./ sigma;

previous_rng = rng;
cleanup = onCleanup(@() rng(previous_rng));
rng(double(model_spec.random_seed), "twister");

model = struct();
model.schema_name = "reqml_regression_model";
model.schema_version = "1.0";
model.model_id = string(model_spec.id);
model.model_type = lower(string(model_spec.type));
model.random_seed = double(model_spec.random_seed);
model.mu = mu;
model.sigma = sigma;
model.constant_predictor_mask = constant_predictors;
model.training_row_count = nnz(valid_train);
model.train_target_min = min(ytrain);
model.train_target_max = max(ytrain);

switch model.model_type
    case "ridge"
        if ~isfield(model_spec, "lambda")
            error("reqml:MissingRidgeLambda", ...
                "Ridge model '%s' requires lambda.", model.model_id);
        end

        lambda = double(model_spec.lambda);

        if ~isscalar(lambda) || ~isfinite(lambda) || lambda < 0
            error("reqml:InvalidRidgeLambda", ...
                "Ridge lambda must be a finite nonnegative scalar.");
        end

        design = [ones(size(Xtrain, 1), 1), Xtrain];
        penalty = eye(size(design, 2));
        penalty(1, 1) = 0;

        coefficients = ...
            (design' * design + lambda * penalty) \ ...
            (design' * ytrain);

        model.lambda = lambda;
        model.coefficients = coefficients;

    case "bagged_trees"
        if exist("fitrensemble", "file") ~= 2
            error("reqml:MissingStatisticsToolbox", ...
                "Bagged trees require fitrensemble.");
        end

        required = ["num_learning_cycles", "min_leaf_size", "use_parallel"];
        missing = required(~isfield(model_spec, cellstr(required)));

        if ~isempty(missing)
            error("reqml:InvalidBaggedTreeSpecification", ...
                "Bagged-tree specification is missing: %s", ...
                strjoin(missing, ", "));
        end

        num_learning_cycles = round(double( ...
            model_spec.num_learning_cycles));

        min_leaf_size = round(double( ...
            model_spec.min_leaf_size));

        use_parallel = logical(model_spec.use_parallel);

        if num_learning_cycles < 1 || min_leaf_size < 1
            error("reqml:InvalidBaggedTreeHyperparameter", ...
                "Learning cycles and minimum leaf size must be positive.");
        end

        learner = templateTree( ...
            MinLeafSize=min_leaf_size, ...
            Reproducible=true);

        ensemble = fitrensemble( ...
            Xtrain, ...
            ytrain, ...
            Method="Bag", ...
            Learners=learner, ...
            NumLearningCycles=num_learning_cycles, ...
            Options=statset(UseParallel=use_parallel));

        model.ensemble = ensemble;
        model.num_learning_cycles = num_learning_cycles;
        model.min_leaf_size = min_leaf_size;
        model.use_parallel = use_parallel;

    otherwise
        error("reqml:UnknownRegressionModelType", ...
            "Unknown model type: %s", model.model_type);
end

clear cleanup

end
