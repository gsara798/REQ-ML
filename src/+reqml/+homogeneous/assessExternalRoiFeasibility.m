function report=assessExternalRoiFeasibility(geometry,options)
%ASSESS_EXTERNALROIFEASIBILITY Count discrete stride ROIs before simulation.
arguments
    geometry (1,1) string {mustBeMember(geometry,["inclusion","bilayer"])}
    options.DomainSizeM (1,1) double {mustBePositive}
    options.GridSpacingM (1,1) double {mustBePositive}
    options.FrequencyHz (1,1) double {mustBePositive} = 400
    options.MValues (:,1) double = [2;3]
    options.CsGuessMPerS (1,1) double = 3
    options.InclusionRadiusM (1,1) double {mustBeNonnegative} = 0
    options.InterfaceAngleRad (1,1) double = pi/6
end
n=round(options.DomainSizeM/options.GridSpacingM)+1;
x=(0:n-1)*options.GridSpacingM; [X,Z]=meshgrid(x,x); center=options.DomainSizeM/2;
switch geometry
    case "inclusion"
        if options.InclusionRadiusM<=0, error("reqml:InvalidExternalInclusionRadius","Radius must be positive."); end
        material=double((X-center).^2+(Z-center).^2<=options.InclusionRadiusM^2);
    case "bilayer"
        normal=[cos(options.InterfaceAngleRad),sin(options.InterfaceAngleRad)];
        material=double((X-center)*normal(1)+(Z-center)*normal(2)>=0);
end
rows=cell(numel(options.MValues),1);
for i=1:numel(options.MValues)
    M=options.MValues(i); g=reqml.homogeneous.computePatchGeometry( ...
        options.FrequencyHz,options.GridSpacingM,options.GridSpacingM, ...
        M=M,CsGuessMPerS=options.CsGuessMPerS);
    h=(g.patch_width_px-1)/2; centers=(h+1):g.stride_x_px:(n-h);
    labels=strings(numel(centers)^2,1); k=0;
    for cz=centers
      for cx=centers
        k=k+1; patch=material(cz-h:cz+h,cx-h:cx+h);
        purity=max(mean(patch(:)==0),mean(patch(:)==1));
        if purity<1-1e-12, labels(k)="interface_band";
        elseif geometry=="inclusion" && material(cz,cx)==1, labels(k)="inclusion_core";
        elseif geometry=="inclusion", labels(k)="background_far";
        elseif material(cz,cx)==0, labels(k)="layer1_core";
        else, labels(k)="layer2_core"; end
      end
    end
    rows{i}=table(M,g.patch_width_px,g.stride_x_px,numel(labels), ...
        sum(labels=="background_far"),sum(labels=="inclusion_core"), ...
        sum(labels=="layer1_core"),sum(labels=="layer2_core"), ...
        sum(labels=="interface_band"), ...
        VariableNames=["REQ_M","patch_width_px","stride_px","patch_count", ...
        "background_far_count","inclusion_core_count","layer1_core_count", ...
        "layer2_core_count","interface_band_count"]);
end
report=vertcat(rows{:});
end
