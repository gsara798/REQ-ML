function selected=selectHotspotControlPatches(predictions,options)
%SELECTHOTSPOTCONTROLPATCHES Select deterministic high-error and control rows.
arguments
    predictions table
    options.HotspotFraction (1,1) double {mustBePositive,mustBeLessThanOrEqual(options.HotspotFraction,1)} = .01
end
required=["example_id","cx","cz","cs_absolute_error_percent","sws_valid"];
missing=setdiff(required,string(predictions.Properties.VariableNames));
if ~isempty(missing)
    error("reqml:MissingHotspotPredictionVariable","Missing: %s",strjoin(missing,", "));
end
valid=predictions(logical(predictions.sws_valid) & ...
    isfinite(predictions.cs_absolute_error_percent),:);
if isempty(valid), selected=valid; selected.selection_group=strings(0,1); return; end
n_hot=max(1,ceil(options.HotspotFraction*height(valid)));
[~,order]=sortrows(table(-double(valid.cs_absolute_error_percent), ...
    string(valid.example_id)),[1 2]);
hot=valid(order(1:n_hot),:); hot.selection_group=repmat("hotspot",height(hot),1);
median_error=median(valid.cs_absolute_error_percent);
pool=valid(valid.cs_absolute_error_percent<median_error,:);
pool=sortrows(pool,["cx","cz","example_id"]);
if height(pool)<n_hot
    error("reqml:InsufficientHotspotControls", ...
        "Only %d below-median controls are available for %d hotspots.",height(pool),n_hot);
end
indices=unique(round(linspace(1,height(pool),n_hot)),'stable');
if numel(indices)<n_hot
    remaining=setdiff(1:height(pool),indices,'stable');
    indices=[indices,remaining(1:n_hot-numel(indices))];
end
control=pool(indices,:); control.selection_group=repmat("control",height(control),1);
selected=[hot;control];
end
