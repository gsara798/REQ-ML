function tests=test_extract_radial_features_empty_spectrum
tests=functiontests(localfunctions);
end

function testEmptySpectrumReturnsAuditableNaNs(testCase)
opt=reqml.config.default_feature_config("M",2,"cs_guess",3);
radial=reqml.features.extract_radial_features(zeros(5),ones(5),opt);
verifyTrue(testCase,isnan(radial.radial_entropy));
verifyTrue(testCase,isnan(radial.k_q50));
verifySize(testCase,radial.Prad_plot,[1 opt.Nrad_plot]);
verifyTrue(testCase,all(isnan(radial.Prad_plot)));
end
