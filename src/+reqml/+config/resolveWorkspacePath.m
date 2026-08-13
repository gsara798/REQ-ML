function value = resolveWorkspacePath(raw_value, options)
%RESOLVEWORKSPACEPATH Resolve versioned workspace path placeholders.
%
% Supported roots are ${REPOSITORY_ROOT} and any explicitly supplied or
% environment-defined variable such as ${SWSIM_ROOT}. Unknown or empty
% variables fail rather than falling back to a machine-specific path.

arguments
    raw_value {mustBeTextScalar}
    options.RepositoryRoot {mustBeTextScalar} = ""
    options.Variables (1,1) struct = struct()
end

value=string(raw_value);
repository_root=string(options.RepositoryRoot);
if strlength(repository_root)==0
    repository_root=string(fileparts(fileparts(fileparts(fileparts( ...
        mfilename("fullpath"))))));
end
tokens=regexp(value,'\$\{([A-Z][A-Z0-9_]*)\}','tokens');
for index=1:numel(tokens)
    name=string(tokens{index}{1});
    replacement=lookup_root(name,repository_root,options.Variables);
    value=replace(value,"${"+name+"}",replacement);
end
if contains(value,"${")
    error("reqml:UnresolvedWorkspacePath", ...
        "Path contains an unresolved placeholder: %s",value);
end
value=string(char(java.io.File(char(value)).getCanonicalPath()));
end


function value=lookup_root(name,repository_root,variables)
if name=="REPOSITORY_ROOT"
    value=repository_root;
elseif isfield(variables,char(name))
    value=string(variables.(char(name)));
else
    value=string(getenv(name));
end
if strlength(value)==0
    error("reqml:MissingWorkspaceRoot", ...
        "Workspace root %s is required. Set it or pass it explicitly.",name);
end
end
