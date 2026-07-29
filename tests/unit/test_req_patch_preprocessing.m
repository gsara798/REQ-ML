function tests = test_req_patch_preprocessing
%TEST_REQ_PATCH_PREPROCESSING Test canonical local REQ preprocessing.

tests = functiontests(localfunctions);

end

function testOutsideWindowSupportRemainsZero(test_case)

V = reshape(1:25, 5, 5);
W = zeros(5);
W(2:4, 2:4) = 1;

[V_processed, diagnostics] = ...
    reqml.spectrum.preprocess_req_patch(V, W);

verifyTrue(test_case, diagnostics.valid);
verifyEqual(test_case, V_processed(W == 0), zeros(nnz(W == 0), 1));

end

function testAdditiveOffsetIsRemoved(test_case)

rng(41);

V = randn(7) + 1i*randn(7);
W = reqml.spectrum.hann2_circular_shrink( ...
    7, 7, 1, 1, 1);

[A, diagnostics_a] = ...
    reqml.spectrum.preprocess_req_patch(V, W);

[B, diagnostics_b] = ...
    reqml.spectrum.preprocess_req_patch( ...
        V + (4.2 - 1.7i), ...
        W);

verifyTrue(test_case, diagnostics_a.valid);
verifyTrue(test_case, diagnostics_b.valid);

verifyEqual(test_case, A, B, AbsTol=1e-12);

end

function testNormalizedRmsIsOne(test_case)

rng(42);

V = randn(9) + 1i*randn(9);
W = reqml.spectrum.hann2_circular_shrink( ...
    9, 9, 1, 1, 1);

[V_processed, diagnostics] = ...
    reqml.spectrum.preprocess_req_patch(V, W);

rms_value = sqrt(mean(abs(V_processed(:)).^2));

verifyTrue(test_case, diagnostics.valid);
verifyEqual(test_case, rms_value, 1, AbsTol=1e-12);

end

function testConstantPatchIsRejected(test_case)

V = ones(7);
W = ones(7);

[V_processed, diagnostics] = ...
    reqml.spectrum.preprocess_req_patch(V, W);

verifyFalse(test_case, diagnostics.valid);
verifyEqual(test_case, V_processed, zeros(7));

end
