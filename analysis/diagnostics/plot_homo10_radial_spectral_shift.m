function result = plot_homo10_radial_spectral_shift(options)
%PLOT_HOMO10_RADIAL_SPECTRAL_SHIFT Interpret the frozen H10 feature shift.
% Reconstructs radial-energy increments only from stored req_mapping Ecum
% curves. It does not run inference or modify feature-extraction code.

arguments
    options.ResultFile {mustBeTextScalar} = ...
        "/Users/sara/Library/CloudStorage/Box-Box/Research/Papers/REQ/data/Experiments/2026Feb27_homo_10perc_sp/Results_test1_400Hz/REQML_homo10_400Hz_results.mat"
    options.OutputRoot {mustBeTextScalar} = ""
end
root=string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
output_root=string(options.OutputRoot);
if strlength(output_root)==0
    output_root=fullfile(root,'outputs','diagnostics','homo10_q_feature_shift_v1');
end
if ~isfolder(output_root)
    error('reqml:diagnostics:MissingOutputRoot', ...
        'The existing H10 diagnostic output does not exist: %s',output_root);
end
figure_file=fullfile(output_root,'figures','good_vs_low_radial_energy.png');
summary_file=fullfile(output_root,'radial_spectral_shape_summary.csv');
curve_file=fullfile(output_root,'radial_spectral_median_iqr.csv');
mat_file=fullfile(output_root,'radial_spectral_shape_summary.mat');
targets=[figure_file summary_file curve_file mat_file];
if any(isfile(targets))
    error('reqml:diagnostics:OutputExists', ...
        'A requested radial-spectrum output already exists; refusing overwrite.');
end

loaded=load(options.ResultFile,'r2');examples=loaded.r2.patch_examples;
required=["x_center_m","z_center_m","req_mapping", ...
    "srad_proxy_skewness","srad_proxy_kurtosis","ecum_asymmetry_10_90"];
if ~all(ismember(required,string(examples.Properties.VariableNames)))
    error('reqml:diagnostics:MissingRadialData', ...
        'The stored patch examples lack required mappings or shape predictors.');
end
x_mm=1e3*double(examples.x_center_m);z_mm=1e3*double(examples.z_center_m);
good=x_mm>=12&x_mm<=26&z_mm>=26&z_mm<=29;
low=x_mm>=12&x_mm<=26&z_mm>=18&z_mm<=21;
[k_good,p_good]=collect_increments(examples.req_mapping(good));
[k_low,p_low]=collect_increments(examples.req_mapping(low));
if ~isequal(k_good,k_low)
    error('reqml:diagnostics:InconsistentRadialGrid', ...
        'GOOD and LOW mappings do not share the same radial k grid.');
end
k=k_good;
[good_median,good_q25,good_q75]=curve_summary(p_good);
[low_median,low_q25,low_q75]=curve_summary(p_low);
good_metrics=distribution_metrics(k,good_median);
low_metrics=distribution_metrics(k,low_median);

summary=table(["GOOD";"LOW_SWS"],[nnz(good);nnz(low)], ...
    [good_metrics.peak_k_rad_m;low_metrics.peak_k_rad_m], ...
    [good_metrics.centroid_k_rad_m;low_metrics.centroid_k_rad_m], ...
    [good_metrics.std_k_rad_m;low_metrics.std_k_rad_m], ...
    [median(double(examples.srad_proxy_skewness(good)),'omitnan'); ...
     median(double(examples.srad_proxy_skewness(low)),'omitnan')], ...
    [median(double(examples.srad_proxy_kurtosis(good)),'omitnan'); ...
     median(double(examples.srad_proxy_kurtosis(low)),'omitnan')], ...
    [median(double(examples.ecum_asymmetry_10_90(good)),'omitnan'); ...
     median(double(examples.ecum_asymmetry_10_90(low)),'omitnan')], ...
    'VariableNames',{'region','N','median_curve_peak_k_rad_m', ...
    'median_curve_centroid_k_rad_m','median_curve_std_k_rad_m', ...
    'median_srad_proxy_skewness','median_srad_proxy_kurtosis', ...
    'median_ecum_asymmetry_10_90'});
curves=table(k,good_median,good_q25,good_q75,low_median,low_q25,low_q75, ...
    low_median-good_median,'VariableNames',{'k_rad_m','good_median', ...
    'good_q25','good_q75','low_median','low_q25','low_q75', ...
    'low_minus_good'});

[k_limits,central_mass]=physical_k_limits(k,good_median,low_median);
make_figure(k,good_median,good_q25,good_q75,low_median,low_q25,low_q75, ...
    good_metrics,low_metrics,k_limits,figure_file);
writetable(summary,summary_file);writetable(curves,curve_file);
result=struct('schema_name','reqml_homo10_radial_spectral_shift', ...
    'schema_version','1.0','result_file',string(options.ResultFile), ...
    'regions',struct('x_mm',[12 26],'good_z_mm',[26 29], ...
    'low_sws_z_mm',[18 21]),'increment_definition', ...
    'p=max(diff(normalize(cummax(Ecum))),0); p=p/sum(p)', ...
    'increment_k_coordinate','midpoint of adjacent stored k_cent values', ...
    'display_k_limits_rad_m',k_limits, ...
    'display_central_energy_fraction',central_mass, ...
    'summary',summary,'curves',curves,'figure_file',figure_file);
save(mat_file,'result');
fprintf('\nH10 radial spectral-shape summary (metrics of group median curve):\n');
disp(summary);
fprintf('Displayed k range: %.1f to %.1f rad/m (central %.1f%% pooled median energy plus one-bin margin).\n', ...
    k_limits(1),k_limits(2),100*central_mass);
end

function [reference_k,values]=collect_increments(mappings)
reference_k=[];values=[];
for i=1:numel(mappings)
    mapping=mappings{i};
    if isempty(mapping)||~isstruct(mapping),continue,end
    [k,p]=increment_from_mapping(mapping);
    if isempty(k),continue,end
    if isempty(reference_k)
        reference_k=k;values=nan(numel(k),numel(mappings));
    elseif ~isequal(k,reference_k)
        error('reqml:diagnostics:InconsistentRadialGrid', ...
            'Stored mappings within a region do not share the same k grid.');
    end
    values(:,i)=p; %#ok<AGROW> values is allocated when the first valid grid is known.
end
values=values(:,all(isfinite(values),1));
if isempty(values)
    error('reqml:diagnostics:NoValidRadialCurves', ...
        'No valid stored Ecum curves were found in a requested region.');
end
end

function [centers,p]=increment_from_mapping(mapping)
E=double(mapping.Ecum(:));k=double(mapping.k_cent(:));
valid=isfinite(E)&isfinite(k)&k>0;E=E(valid);k=k(valid);
if numel(E)<3,centers=[];p=[];return,end
[k,order]=sort(k,'ascend');E=cummax(E(order));
if max(E)<=min(E),centers=[];p=[];return,end
E=(E-min(E))./(max(E)-min(E));
dE=diff(E);dk=diff(k);valid_step=isfinite(dE)&isfinite(dk)&dk>0;
dE=max(dE(valid_step),0);
all_centers=.5*(k(1:end-1)+k(2:end));centers=all_centers(valid_step);
if isempty(dE)||sum(dE)<=0,centers=[];p=[];return,end
p=dE./sum(dE);
end

function [med,q25,q75]=curve_summary(values)
med=median(values,2,'omitnan');q25=prctile(values,25,2);q75=prctile(values,75,2);
end

function out=distribution_metrics(k,p)
p=max(double(p(:)),0);p=p./sum(p);k=double(k(:));
[~,peak_index]=max(p);mu=sum(p.*k);sigma=sqrt(sum(p.*(k-mu).^2));
out=struct('peak_k_rad_m',k(peak_index),'centroid_k_rad_m',mu, ...
    'std_k_rad_m',sigma);
end

function [limits,mass]=physical_k_limits(k,good,low)
pooled=.5*(good./sum(good)+low./sum(low));c=cumsum(pooled);
lo=find(c>=.005,1,'first');hi=find(c>=.995,1,'first');
lo=max(1,lo-1);hi=min(numel(k),hi+1);limits=[k(lo) k(hi)];
mass=sum(pooled(lo:hi));
end

function make_figure(k,gm,g25,g75,lm,l25,l75,gmet,lmet,limits,filename)
fig=figure('Visible','off','Color','w','Position',[100 100 1200 760]);
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
nexttile;hold on;grid on;
fill_band(k,g25,g75,[0.15 0.45 0.78]);fill_band(k,l25,l75,[0.85 0.33 0.10]);
plot(k,gm,'Color',[0.05 0.35 0.72],'LineWidth',2.2,'DisplayName','GOOD median');
plot(k,lm,'Color',[0.80 0.20 0.05],'LineWidth',2.2,'DisplayName','LOW-SWS median');
mark_metric(gmet.peak_k_rad_m,gm,k,[0.05 0.35 0.72],'o','GOOD peak');
mark_metric(gmet.centroid_k_rad_m,gm,k,[0.05 0.35 0.72],'s','GOOD centroid');
mark_metric(lmet.peak_k_rad_m,lm,k,[0.80 0.20 0.05],'o','LOW peak');
mark_metric(lmet.centroid_k_rad_m,lm,k,[0.80 0.20 0.05],'s','LOW centroid');
xlim(limits);ylabel('radial energy fraction / bin');
title('Stored Ecum radial-energy increments (median and IQR)');
legend('Location','best','Interpreter','none');
nexttile;hold on;grid on;yline(0,'k:');
plot(k,lm-gm,'Color',[0.30 0.30 0.30],'LineWidth',2);
xlim(limits);xlabel('radial wavenumber k (rad/m)');
ylabel('LOW - GOOD energy fraction / bin');
title('Difference of group-median radial distributions');
sgtitle('H10 prespecified regions: radial spectral-shape interpretation');
exportgraphics(fig,filename,'Resolution',240);close(fig);
end

function fill_band(k,lo,hi,color)
fill([k;flipud(k)],[lo;flipud(hi)],color,'FaceAlpha',.16, ...
    'EdgeColor','none','HandleVisibility','off');
end

function mark_metric(value,curve,k,color,marker,label)
y=interp1(k,curve,value,'linear');
plot(value,y,marker,'MarkerSize',8,'LineWidth',1.5,'Color',color, ...
    'MarkerFaceColor','w','DisplayName',label);
end
