function report = validateAdaptivePilotIsolation(config_file, options)
%VALIDATEADAPTIVEPILOTISOLATION Refuse unsafe adaptive-pilot output reuse.
%
% This preflight check is intentionally read-only. It verifies that a new
% pilot cannot resume or write into a prior campaign and never deletes an
% existing output directory.

arguments
    config_file {mustBeTextScalar}
    options.ExpectedCampaignId {mustBeTextScalar} = ""
    options.ExpectedSimulationFrameworkRoot {mustBeTextScalar} = ""
    options.ForbiddenCampaignIds (1,:) string = ...
        "reqml_adaptive_scientific_4d_v2"
end

config_file = canonical_path(string(config_file));

if ~isfile(config_file)
    error("reqml:AdaptivePilotConfigNotFound", ...
        "Adaptive pilot configuration was not found: %s", config_file);
end

try
    config_text = string(fileread(config_file));
    config = jsondecode(config_text);
catch exception
    error("reqml:InvalidAdaptivePilotConfigJson", ...
        "Could not decode adaptive pilot config '%s': %s", ...
        config_file, exception.message);
end

require_fields(config, ["campaign_id", "paths", "simulation", "execution"]);
require_fields(config.paths, ["output_root", "simulation_framework_root"]);
require_fields(config.simulation, "output_directory");
require_fields(config.execution, "resume_existing_loop");

campaign_id = string(config.campaign_id);
expected_id = string(options.ExpectedCampaignId);

if strlength(expected_id) > 0 && campaign_id ~= expected_id
    error("reqml:AdaptivePilotCampaignIdentityMismatch", ...
        "Expected campaign_id '%s', but the config defines '%s'.", ...
        expected_id, campaign_id);
end

if logical(config.execution.resume_existing_loop)
    error("reqml:AdaptivePilotResumeEnabled", ...
        "A clean pilot requires execution.resume_existing_loop=false. " + ...
        "The validator does not resume or delete prior output.");
end

repository_root = canonical_path(fullfile(fileparts(mfilename("fullpath")), ...
    "..", "..", ".."));
config_directory = string(fileparts(config_file));
output_root = resolve_path(string(config.paths.output_root), ...
    config_directory, repository_root);
simulation_framework_root = resolve_path( ...
    string(config.paths.simulation_framework_root), ...
    config_directory, repository_root);
simulation_output_directory = resolve_path( ...
    string(config.simulation.output_directory), ...
    config_directory, repository_root);

for forbidden_id = options.ForbiddenCampaignIds
    if contains(config_text, forbidden_id)
        error("reqml:AdaptivePilotForbiddenCampaignPath", ...
            "Pilot configuration contains forbidden prior campaign identity '%s'.", ...
            forbidden_id);
    end
end

if string(basename(output_root)) ~= campaign_id || ...
        string(basename(simulation_output_directory)) ~= campaign_id
    error("reqml:AdaptivePilotCampaignIdentityMismatch", ...
        "campaign_id and both output-directory basenames must match. " + ...
        "campaign_id='%s', REQ-ML='%s', simulation='%s'.", ...
        campaign_id, output_root, simulation_output_directory);
end

expected_framework_root = string(options.ExpectedSimulationFrameworkRoot);
if strlength(expected_framework_root) > 0 && ...
        simulation_framework_root ~= canonical_path(expected_framework_root)
    error("reqml:AdaptivePilotSimulationFrameworkMismatch", ...
        "Expected simulation framework '%s', but the config resolves to '%s'.", ...
        canonical_path(expected_framework_root), simulation_framework_root);
end

if isfolder(output_root) || isfile(output_root)
    error("reqml:AdaptivePilotReqmlOutputExists", ...
        "The clean-pilot REQ-ML output root already exists: %s. " + ...
        "No data were removed.", output_root);
end

simulation_output_exists = isfolder(simulation_output_directory) || ...
    isfile(simulation_output_directory);
simulation_output_has_entries = false;

if isfolder(simulation_output_directory)
    listing = dir(simulation_output_directory);
    names = string({listing.name});
    simulation_output_has_entries = any(names ~= "." & names ~= "..");
elseif isfile(simulation_output_directory)
    simulation_output_has_entries = true;
end

if simulation_output_has_entries
    error("reqml:AdaptivePilotSimulationOutputConflict", ...
        "The pilot simulation output directory already contains data: %s. " + ...
        "No data were removed.", simulation_output_directory);
end

report = struct();
report.config_file = config_file;
report.campaign_id = campaign_id;
report.output_root = output_root;
report.simulation_framework_root = simulation_framework_root;
report.simulation_output_directory = simulation_output_directory;
report.resume_existing_loop = false;
report.reqml_output_exists = false;
report.simulation_output_exists = simulation_output_exists;
report.simulation_output_has_entries = false;
report.safe_to_start = true;

end


function require_fields(value, names)

names = string(names);
missing = names(~isfield(value, names));

if ~isempty(missing)
    error("reqml:InvalidAdaptivePilotConfig", ...
        "Adaptive pilot config is missing required field(s): %s", ...
        strjoin(missing, ", "));
end

end


function value = resolve_path(raw_value, config_directory, repository_root)

value = string(raw_value);

if startsWith(value, "${REPOSITORY_ROOT}/")
    value = fullfile(repository_root, ...
        extractAfter(value, "${REPOSITORY_ROOT}/"));
elseif value == "${REPOSITORY_ROOT}"
    value = repository_root;
elseif startsWith(value, "${CONFIG_DIRECTORY}/")
    value = fullfile(config_directory, ...
        extractAfter(value, "${CONFIG_DIRECTORY}/"));
elseif value == "${CONFIG_DIRECTORY}"
    value = config_directory;
elseif ~is_absolute_path(value)
    value = fullfile(config_directory, value);
end

value = canonical_path(value);

end


function tf = is_absolute_path(value)

value = char(value);

if ispc
    tf = ~isempty(regexp(value, '^[A-Za-z]:[\\/]', 'once')) || ...
        startsWith(value, "\\");
else
    tf = startsWith(value, "/");
end

end


function value = canonical_path(value)

value = string(char(java.io.File(char(value)).getCanonicalPath()));

end


function name = basename(path_value)

[~, name, extension] = fileparts(char(path_value));
name = string(name) + string(extension);

end
