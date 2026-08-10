function [selected, diagnostics] = selectPatchQuota(varargin)
%SELECTPATCHQUOTA Compatibility wrapper; use reqml.datasets.selectPatchQuota.

[selected,diagnostics]=reqml.datasets.selectPatchQuota(varargin{:});
end
