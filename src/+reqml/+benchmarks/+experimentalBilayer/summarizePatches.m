function summary = summarizePatches(patches, group_names, options)
%SUMMARIZEPATCHES Aggregate controlled estimator errors without imputation.
arguments
    patches table
    group_names (1,:) string
    options.CommonSupportOnly (1,1) logical = true
end
rows=patches(patches.valid,:);
if options.CommonSupportOnly, rows=rows(rows.common_support,:); end
if isempty(rows), summary=table(); return; end
[group,values]=findgroups(rows(:,group_names)); summary=values;
summary.N=splitapply(@numel,rows.estimate_m_s,group);
summary.mean_estimate_m_s=splitapply(@mean,rows.estimate_m_s,group);
summary.median_estimate_m_s=splitapply(@median,rows.estimate_m_s,group);
summary.std_estimate_m_s=splitapply(@std,rows.estimate_m_s,group);
summary.IQR_m_s=splitapply(@iqr,rows.estimate_m_s,group);
summary.truth_m_s=splitapply(@median,rows.truth_m_s,group);
summary.bias_m_s=splitapply(@mean,rows.signed_error_m_s,group);
summary.relative_bias_percent=100*summary.bias_m_s./summary.truth_m_s;
summary.MAPE_percent=splitapply(@mean,rows.absolute_error_percent,group);
summary.support_scope=repmat("intersection",height(summary),1);
end
