function values=resolveReqMValues(config)
%RESOLVEREQMVALUES Resolve scalar v1 or vector v2 REQ analysis contract.
if isfield(config.req,"M_values")
    values=double(config.req.M_values(:));
elseif isfield(config.req,"M")
    values=double(config.req.M);
else
    error("reqml:MissingHomogeneousReqM","REQ config requires M or M_values.");
end
if isempty(values) || any(~ismember(values,[2 3])) || numel(unique(values))~=numel(values)
    error("reqml:InvalidHomogeneousReqM","REQ M values must be unique members of {2,3}.");
end
values=sort(values);
end
