function [model_file, resolution] = resolveCurrentQ0Model(options)
%RESOLVECURRENTQ0MODEL Resolve the current Q0 bundle without downloading it.

arguments
    options.Model {mustBeTextScalar} = ""
    options.RepositoryRoot {mustBeTextScalar} = ""
end

repository_root = string(options.RepositoryRoot);
if strlength(repository_root) == 0
    repository_root = string(fileparts(fileparts(fileparts(fileparts( ...
        mfilename("fullpath"))))));
end

explicit = string(options.Model);
environment = string(getenv("REQML_Q0_MODEL"));
packaged = fullfile(repository_root, "models", "current", "model_bundle.mat");

candidates = [explicit; environment; packaged];
sources = ["Model option"; "REQML_Q0_MODEL"; "models/current"];
selected = find(strlength(candidates) > 0 & isfile(candidates), 1);
if isempty(selected)
    error("reqml:Q0ModelNotFound", "%s", ...
        "The current Q0 model bundle was not found. Pass Model=..., " + ...
        "set REQML_Q0_MODEL, or place model_bundle.mat under " + ...
        "models/current. See models/README.md.");
end

model_file = string(candidates(selected));
resolution = struct("source", sources(selected), ...
    "model_file", model_file, "repository_root", repository_root);
end
