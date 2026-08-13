function tests=test_homogeneous_v2_angular_family
tests=functiontests(localfunctions);
end

function testFrozenFamilyIsMonotonic(testCase)
t=reqml.homogeneous.buildAngularFieldFamilyV2();
verifyEqual(testCase,height(t),7); verifyEqual(testCase,t.angular_level,(1:7)');
verifyGreaterThan(testCase,diff(t.angular_support_fraction),zeros(6,1));
verifyGreaterThan(testCase,diff(t.direction_count),zeros(6,1));
verifyGreaterThanOrEqual(testCase,diff(t.in_plane_count),zeros(6,1));
verifyEqual(testCase,t.solid_angle_sr,4*pi*t.angular_support_fraction,AbsTol=1e-12);
end

function testLegacyDnomPreserved(testCase)
t=reqml.homogeneous.buildAngularFieldFamilyV2();
expected=(t.direction_count/128).*t.angular_support_fraction;
verifyEqual(testCase,t.legacy_Dnom,expected,AbsTol=1e-14);
end

function testConfigMatchesFrozenFamily(testCase)
root=string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
c=jsondecode(fileread(fullfile(root,"configs","homogeneous","homogeneous_cartesian_q0_v2.json")));
t=reqml.homogeneous.buildAngularFieldFamilyV2();
verifyEqual(testCase,string({c.field_regimes.name})',t.name);
verifyEqual(testCase,double([c.field_regimes.direction_count])',t.direction_count);
verifyEqual(testCase,double([c.field_regimes.in_plane_count])',t.in_plane_count);
verifyEqual(testCase,double([c.field_regimes.solid_angle_sr])',t.solid_angle_sr,AbsTol=1e-12);
verifyEqual(testCase,double(c.req.M_values(:)),[2;3]);
end

function testV1AuditValues(testCase)
r=reqml.homogeneous.auditAngularCoverageV2(V1CampaignRunsCsv="");
verifyEqual(testCase,r.v1.legacy_Dnom, ...
    [1/128*.01/(4*pi);4/128*.5/(4*pi);16/128*pi/(4*pi);32/128],AbsTol=1e-14);
verifyFalse(testCase,r.assessment.legacy_Dnom_primary_suitable);
verifyEqual(testCase,r.assessment.primary_v2_coordinate,"angular_support_fraction");
end
