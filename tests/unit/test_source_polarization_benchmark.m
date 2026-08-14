classdef test_source_polarization_benchmark < matlab.unittest.TestCase
    methods(Test)
        function configIsFrozenAndIsolated(testCase)
            root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
            c=jsondecode(fileread(fullfile(root,'configs','benchmarks', ...
                'experimental_bilayer_400hz_source_polarization.json')));
            testCase.verifyEqual(string(c.benchmark_id), ...
                "experimental_bilayer_400hz_source_polarization_v1");
            testCase.verifyNotEqual(string(c.output_root), ...
                "${REPOSITORY_ROOT}/outputs/benchmarks/experimental_bilayer_400hz_v1");
            testCase.verifyEqual(numel(c.conditions),6);
            testCase.verifyEqual(sort(string({c.conditions.source_polarization})), ...
                sort(repmat(["X","Z"],1,3)));
            testCase.verifyEqual(c.req.step_pixels,1);
        end
        function patchGridUsesNativeCoordinates(testCase)
            p=table([.2;.1;.2;.1],[.3;.3;.4;.4],[2;1;4;3], ...
                'VariableNames',{'x_m','z_m','estimate_m_s'});
            [map,x,z]=reqml.benchmarks.sourcePolarization.patchesToGrid(p);
            testCase.verifyEqual(map,[1 2;3 4]);
            testCase.verifyEqual(x,[100 200]);
            testCase.verifyEqual(z,[300;400]);
        end
        function duplicateGridRejected(testCase)
            p=table([.1;.1],[.2;.2],[1;2], ...
                'VariableNames',{'x_m','z_m','estimate_m_s'});
            testCase.verifyError(@() ...
                reqml.benchmarks.sourcePolarization.patchesToGrid(p), ...
                'reqml:benchmark:DuplicateGridPoint');
        end
        function missingGeometryAuditIsClear(testCase)
            folder=tempname; mkdir(folder); cleanup=onCleanup(@() rmdir(folder,'s'));
            testCase.verifyError(@() ...
                reqml.benchmarks.sourcePolarization.copyGeometryAudit( ...
                folder,folder),'reqml:benchmark:MissingGeometryAudit');
        end
        function sourceComparisonUsesMatchedRows(testCase)
            source_polarization=["Z";"X"]; condition=["H";"H"];
            estimator=["Q0";"Q0"]; M=[2;2]; center_material_id=[1;1];
            N=[10;10]; median_estimate_m_s=[2;1.9]; std_estimate_m_s=[.1;.2];
            MAPE_percent=[2;5]; bias_m_s=[-.04;-.1];
            t=table(source_polarization,condition,estimator,M,center_material_id, ...
                N,median_estimate_m_s,std_estimate_m_s,MAPE_percent,bias_m_s);
            c=reqml.benchmarks.sourcePolarization.compareSourceSummaries(t);
            testCase.verifyEqual(c.delta_MAPE_x_minus_z_percent_points,3);
            testCase.verifyEqual(c.delta_bias_x_minus_z_m_s,-.06,'AbsTol',1e-12);
        end
    end
end
