function result = predict_discrete_theory_q( ...
    q_theory_discrete, ...
    q_theory_valid, ...
    options)
%PREDICT_DISCRETE_THEORY_Q Use the discrete theoretical q as a baseline.

arguments
    q_theory_discrete (:,1) double
    q_theory_valid (:,1) logical

    options.ClipRange (1,2) double = [0.001, 0.999]
end

if numel(q_theory_discrete) ~= numel(q_theory_valid)
    error("reqml:TheoryBaselineSizeMismatch", ...
        "Theory values and validity mask must have equal length.");
end

invalid = ...
    ~q_theory_valid | ...
    ~isfinite(q_theory_discrete);

if any(invalid)
    error("reqml:InvalidTheoryBaselineRows", ...
        "Discrete theory baseline contains %d invalid rows.", ...
        nnz(invalid));
end

q_pred = min( ...
    max(q_theory_discrete, options.ClipRange(1)), ...
    options.ClipRange(2));

result = struct();
result.baseline_id = "q_theory_discrete";
result.q_pred = q_pred;
result.invalid_row_count = 0;

end
