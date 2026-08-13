function family=buildAngularFieldFamilyV2()
%BUILDANGULARFIELDFAMILYV2 Frozen monotonic homogeneous-Q0 v2 field family.
% angular_support_fraction = Omega/(4*pi) is the primary design coordinate.
% Legacy Dnom is retained exactly as (N/128)*angular_support_fraction.

name=["level_1_near_single";"level_2_narrow";"level_3_directional"; ...
    "level_4_low_intermediate";"level_5_intermediate"; ...
    "level_6_broad";"level_7_diffuse"];
angular_level=(1:7)';
angular_support_fraction=[0.01/(4*pi);.01;.04;.125;.25;.5;1];
direction_count=[1;3;6;10;16;24;32];
in_plane_count=[1;1;2;3;4;6;8];
solid_angle_sr=4*pi*angular_support_fraction;
legacy_Dnom=reqml.coverage.computeNominalAngularCoverage( ...
    direction_count,solid_angle_sr);
direction_density_per_sr=direction_count./solid_angle_sr;
requested_in_plane_fraction=in_plane_count./direction_count;
family=table(angular_level,name,angular_support_fraction,direction_count, ...
    in_plane_count,solid_angle_sr,legacy_Dnom,direction_density_per_sr, ...
    requested_in_plane_fraction);
end
