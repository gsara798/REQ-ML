function geometry = copyGeometryAudit(simulation_root,output_root)
%COPYGEOMETRYAUDIT Copy the simulation preflight audit into analysis output.
arguments
    simulation_root {mustBeTextScalar}
    output_root {mustBeTextScalar}
end
preflight=fullfile(simulation_root,'outputs','benchmarks', ...
    'experimental_bilayer_400hz_source_polarization','preflight');
json_file=fullfile(preflight,'source_domain_geometry.json');
figure_file=fullfile(preflight,'source_domain_geometry.png');
if ~isfile(json_file) || ~isfile(figure_file)
    error('reqml:benchmark:MissingGeometryAudit', ...
        'Expected source/domain preflight audit was not found: %s',preflight);
end
geometry=jsondecode(fileread(json_file));
copyfile(json_file,fullfile(output_root,'source_domain_geometry.json'));
copyfile(figure_file,fullfile(output_root,'figures','source_domain_geometry.png'));
end
