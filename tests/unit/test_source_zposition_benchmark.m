classdef test_source_zposition_benchmark < matlab.unittest.TestCase
    methods(Test)
        function configIsIsolatedQ0Only(testCase)
            root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
            c=jsondecode(fileread(fullfile(root,'configs','benchmarks', ...
                'experimental_bilayer_400hz_source_zposition.json')));
            testCase.verifyEqual(string(c.benchmark_id), ...
                "experimental_bilayer_400hz_source_zposition_v1");
            testCase.verifyEqual(string({c.positions.id}), ...
                ["NEAR_INTERFACE","SOURCE_IN_SOFT","SOURCE_IN_STIFF"]);
            testCase.verifyFalse(isfield(c,'aia'));
            testCase.verifyFalse(isfield(c,'theory_discrete'));
            testCase.verifyEqual(c.req.M,2); testCase.verifyEqual(c.req.step_pixels,1);
            testCase.verifyNotEqual(string(c.output_root),string(c.baseline_analysis_root));
        end
        function regionsMatchFrozenSourcePolarizationBenchmark(testCase)
            root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
            old=jsondecode(fileread(fullfile(root,'configs','benchmarks', ...
                'experimental_bilayer_400hz_source_polarization.json')));
            new=jsondecode(fileread(fullfile(root,'configs','benchmarks', ...
                'experimental_bilayer_400hz_source_zposition.json')));
            old=old.regions(string({old.regions.condition})=="BILAYER");
            testCase.verifyEqual(string({new.regions.name}),string({old.name}));
            testCase.verifyEqual([new.regions.x_m],[old.x_m]);
            testCase.verifyEqual([new.regions.z_m],[old.z_m]);
        end
    end
end
