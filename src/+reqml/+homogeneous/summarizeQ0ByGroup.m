function summary = summarizeQ0ByGroup(predictions, group_columns, options)
%SUMMARIZEQ0BYGROUP Compute q and reconstructed-SWS metrics by group.

arguments
    predictions table
    group_columns (1,:) string
    options.Partition (1,1) string = ""
end

data=predictions(logical(predictions.sws_valid),:);
if strlength(options.Partition)>0
    data=data(data.partition==options.Partition,:);
end
if isempty(data)
    error("reqml:EmptyHomogeneousQ0Diagnostic","No rows match diagnostic.");
end
[group,values]=findgroups(data(:,group_columns));
summary=values;
summary.row_count=splitapply(@numel,data.q_true,group);
summary.q_mae=splitapply(@(x) mean(abs(x)),data.q_error,group);
summary.q_rmse=splitapply(@(x) sqrt(mean(x.^2)),data.q_error,group);
summary.q_bias=splitapply(@mean,data.q_error,group);
summary.q_median_ae=splitapply(@(x) median(abs(x)),data.q_error,group);
summary.sws_mae_m_s=splitapply(@(x) mean(abs(x)),data.cs_error_m_s,group);
summary.sws_rmse_m_s=splitapply(@(x) sqrt(mean(x.^2)), ...
    data.cs_error_m_s,group);
summary.sws_bias_m_s=splitapply(@mean,data.cs_error_m_s,group);
summary.sws_mape=splitapply(@mean,data.cs_absolute_error_percent,group);
summary.sws_median_ape=splitapply(@median, ...
    data.cs_absolute_error_percent,group);
summary.sws_p90_ape=splitapply(@(x) prctile(x,90), ...
    data.cs_absolute_error_percent,group);
summary.sws_error_gt5_pct=100*splitapply(@(x) mean(x>5), ...
    data.cs_absolute_error_percent,group);
summary.sws_error_gt10_pct=100*splitapply(@(x) mean(x>10), ...
    data.cs_absolute_error_percent,group);
summary.sws_error_gt20_pct=100*splitapply(@(x) mean(x>20), ...
    data.cs_absolute_error_percent,group);
summary.sws_underestimate_pct=100*splitapply(@(x) mean(x<0), ...
    data.cs_error_percent,group);
summary.sws_bias_percent=splitapply(@mean,data.cs_error_percent,group);
end
