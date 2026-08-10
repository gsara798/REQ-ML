function [selected, diagnostics] = selectPatchQuota( ...
        candidates, target_count, selection_seed)
%SELECTPATCHQUOTA Deterministically select at most target_count patch rows.

arguments
    candidates table
    target_count (1,1) double {mustBeInteger,mustBePositive}
    selection_seed (1,1) double {mustBeInteger,mustBeNonnegative}
end

available=height(candidates);
if ismember("example_id",string(candidates.Properties.VariableNames)) && ...
        numel(unique(string(candidates.example_id)))~=available
    error("reqml:DuplicatePatchQuotaCandidate", ...
        "Patch quota candidates contain duplicate example IDs.");
end

selected_count=min(available,double(target_count));
if available<=target_count
    indices=(1:available)';
else
    stream=RandStream("Threefry","Seed",double(selection_seed));
    indices=randperm(stream,available,selected_count)';
end
selected=candidates(indices,:);
selected.quota_selection_rank=(1:selected_count)';

diagnostics=struct();
diagnostics.available_patch_count=available;
diagnostics.selected_patch_count=selected_count;
diagnostics.target_patch_count=double(target_count);
diagnostics.deficit_patch_count=max(0,double(target_count)-selected_count);
diagnostics.selection_seed=double(selection_seed);
diagnostics.selected_candidate_indices=indices;
diagnostics.complete=selected_count>=target_count;
end
