function summary = summarizeExternalPredictions(predictions, group_columns)
%SUMMARIZEEXTERNALPREDICTIONS Summarize frozen-Q0 external transfer metrics.

arguments
    predictions table
    group_columns (1,:) string
end

required=[group_columns,"q_error","cs_error_m_s","cs_error_percent", ...
    "cs_absolute_error_percent","sws_valid"];
missing=setdiff(required,string(predictions.Properties.VariableNames));
if ~isempty(missing)
    error("reqml:MissingExternalPredictionVariable", ...
        "External predictions are missing: %s",strjoin(missing,", "));
end
data=predictions(logical(predictions.sws_valid),:);
if isempty(data)
    summary=table(); return
end
[group,values]=findgroups(data(:,group_columns));
summary=values;
summary.patch_count=splitapply(@numel,data.q_error,group);
summary.q_mae=splitapply(@(x) mean(abs(x),"omitnan"),data.q_error,group);
summary.q_rmse=splitapply(@(x) sqrt(mean(x.^2,"omitnan")),data.q_error,group);
summary.q_bias=splitapply(@(x) mean(x,"omitnan"),data.q_error,group);
summary.sws_mae_m_s=splitapply(@(x) mean(abs(x),"omitnan"),data.cs_error_m_s,group);
summary.sws_rmse_m_s=splitapply(@(x) sqrt(mean(x.^2,"omitnan")),data.cs_error_m_s,group);
summary.sws_mape=splitapply(@(x) mean(x,"omitnan"),data.cs_absolute_error_percent,group);
summary.sws_bias_percent=splitapply(@(x) mean(x,"omitnan"),data.cs_error_percent,group);
summary.sws_median_ape=splitapply(@(x) median(x,"omitnan"),data.cs_absolute_error_percent,group);
summary.sws_p90_ape=splitapply(@(x) prctile(x,90),data.cs_absolute_error_percent,group);
end
