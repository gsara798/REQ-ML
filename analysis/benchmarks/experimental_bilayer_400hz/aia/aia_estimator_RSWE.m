function [cs_map, k_map, x_cent, z_cent, diag] = aia_estimator_RSWE(Uxz, dx, dz, f0, varargin)
%AIA_ESTIMATOR_RSWE Source-faithful AIA reference for this benchmark only.
%
% Provenance: copied 2026-08-13 from
% /Users/sara/Library/CloudStorage/Box-Box/Research/
% Sally_MC_Benchmark_Project/03_working_code/+estimators/
% aia_estimator_RSWE.m
%
% Purpose: controlled REQ/AIA estimator comparison. Relative to the source,
% automatic decimation and parfor default to false, input failures have stable
% identifiers, and returned center coordinates use MATLAB's 1-based index
% convention correctly. The correlation, rotational averaging, and nonlinear
% RSWE fit are unchanged. This is not part of the public reqml API.

p = inputParser;
addRequired(p, 'Uxz', @(x) isnumeric(x) && ismatrix(x) && ~isempty(x));
addRequired(p, 'dx', @(x) isnumeric(x) && isscalar(x));
addRequired(p, 'dz', @(x) isnumeric(x) && isscalar(x));
addRequired(p, 'f0', @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'WindowSize', []);
addParameter(p, 'M', 2);
addParameter(p, 'cs_guess', 3);
addParameter(p, 'StepX', 2);
addParameter(p, 'StepZ', 2);
addParameter(p, 'EdgeMode', 'valid');
addParameter(p, 'AutoDecimate', false);
addParameter(p, 'CorrMode', 'autocorr2d');
addParameter(p, 'NumAngles', 180);
addParameter(p, 'UseParfor', false);
addParameter(p, 'SmoothSigma', 0);
parse(p, Uxz, dx, dz, f0, varargin{:});
P = p.Results;
P.f0 = f0;

Uxz = double(Uxz);
if ~isscalar(f0) || ~isfinite(f0) || f0 <= 0
    error('reqml:aia:InvalidFrequency', ...
        'f0 must be specified as a positive finite scalar.');
end
if ~isscalar(dx) || ~isscalar(dz) || ~isfinite(dx) || ~isfinite(dz) || ...
        dx <= 0 || dz <= 0
    error('reqml:aia:InvalidSpacing', ...
        'dx and dz must be positive finite scalars.');
end

decimation = struct('applied', false, 'axis', 'none', 'factor', 1, ...
    'dx_original', dx, 'dz_original', dz);
spacing_tol = 1e-9*max(dx,dz);
if abs(dx-dz) > spacing_tol
    if ~P.AutoDecimate
        error('reqml:aia:AnisotropicSpacing', ...
            ['AIA rotational averaging requires dx == dz. Pre-resample ' ...
             'explicitly or opt into AutoDecimate.']);
    end
    if dx < dz
        ratio = dz/dx; factor = round(ratio);
        if factor < 1 || abs(ratio-factor) > 1e-6*max(1,ratio)
            error('reqml:aia:NonintegerDecimation', ...
                'dz/dx cannot be matched by integer decimation.');
        end
        Uxz = Uxz(:,1:factor:end); dx = dx*factor;
        decimation.applied = true; decimation.axis = 'x'; decimation.factor = factor;
    else
        ratio = dx/dz; factor = round(ratio);
        if factor < 1 || abs(ratio-factor) > 1e-6*max(1,ratio)
            error('reqml:aia:NonintegerDecimation', ...
                'dx/dz cannot be matched by integer decimation.');
        end
        Uxz = Uxz(1:factor:end,:); dz = dz*factor;
        decimation.applied = true; decimation.axis = 'z'; decimation.factor = factor;
    end
end

if isempty(P.WindowSize)
    if ~isscalar(P.cs_guess) || ~isfinite(P.cs_guess) || P.cs_guess <= 0
        error('reqml:aia:InvalidCsGuess', ...
            'cs_guess must be a positive finite scalar.');
    end
    lambda0 = P.cs_guess/f0;
    win_x = round(P.M*lambda0/dx);
    win_z = round(P.M*lambda0/dz);
else
    if ~isnumeric(P.WindowSize) || numel(P.WindowSize) ~= 2
        error('reqml:aia:InvalidWindowSize', ...
            'WindowSize must be [Nz Nx].');
    end
    win_z = P.WindowSize(1); win_x = P.WindowSize(2);
    lambda0 = [];
end
win_x = max(round(win_x),3); win_z = max(round(win_z),3);
if mod(win_x,2)==0, win_x=win_x+1; end
if mod(win_z,2)==0, win_z=win_z+1; end
half_x=floor(win_x/2); half_z=floor(win_z/2);
W=ones(win_z,win_x); [Nz,Nx]=size(Uxz);

switch lower(string(P.EdgeMode))
    case "valid"
        cx_list=(1+half_x):P.StepX:(Nx-half_x);
        cz_list=(1+half_z):P.StepZ:(Nz-half_z);
        Uwork=Uxz; x_offset=0; z_offset=0;
    case "reflect"
        Uwork=padarray(Uxz,[half_z half_x],'symmetric','both');
        x_offset=half_x; z_offset=half_z;
        cx_list=1:P.StepX:Nx; cz_list=1:P.StepZ:Nz;
    case "replicate"
        Uwork=padarray(Uxz,[half_z half_x],'replicate','both');
        x_offset=half_x; z_offset=half_z;
        cx_list=1:P.StepX:Nx; cz_list=1:P.StepZ:Nz;
    case "zeropad"
        Uwork=padarray(Uxz,[half_z half_x],0,'both');
        x_offset=half_x; z_offset=half_z;
        cx_list=1:P.StepX:Nx; cz_list=1:P.StepZ:Nz;
    otherwise
        error('reqml:aia:UnknownEdgeMode','Unknown EdgeMode: %s',P.EdgeMode);
end
if isempty(cx_list) || isempty(cz_list)
    error('reqml:aia:FieldTooSmall','Field is smaller than the AIA window.');
end

k_map=nan(numel(cz_list),numel(cx_list));
correc=local_corr2d(W,P.CorrMode);
if P.UseParfor
    parfor iz=1:numel(cz_list)
        row=nan(1,numel(cx_list)); cz=cz_list(iz)+z_offset;
        for ix=1:numel(cx_list)
            cx=cx_list(ix)+x_offset;
            patch=Uwork(cz-half_z:cz+half_z,cx-half_x:cx+half_x);
            row(ix)=local_aia_from_patch(patch,W,dx,correc,P);
        end
        k_map(iz,:)=row;
    end
else
    for iz=1:numel(cz_list)
        cz=cz_list(iz)+z_offset;
        for ix=1:numel(cx_list)
            cx=cx_list(ix)+x_offset;
            patch=Uwork(cz-half_z:cz+half_z,cx-half_x:cx+half_x);
            k_map(iz,ix)=local_aia_from_patch(patch,W,dx,correc,P);
        end
    end
end
invalid=~isfinite(k_map)|k_map<=0;
cs_map=2*pi*f0./k_map; cs_map(invalid)=NaN; k_map(invalid)=NaN;
x_cent=(cx_list-1)*dx; z_cent=(cz_list-1)*dz;
diag=struct('params',P,'f0',f0,'window',W,'correc',correc, ...
    'cx_list',cx_list,'cz_list',cz_list,'win_x',win_x,'win_z',win_z, ...
    'half_x',half_x,'half_z',half_z,'lambda0',lambda0,'dx',dx,'dz',dz, ...
    'decimation',decimation,'implementation_label',"source_faithful_contract_cleaned");
end

function k=local_aia_from_patch(patch,W,dx,correc,P)
corre=local_corr2d(double(patch).*W,P.CorrMode)./max(double(correc),eps);
if P.SmoothSigma>0
    corre=imgaussfilt(real(corre),P.SmoothSigma)+ ...
        1i*imgaussfilt(imag(corre),P.SmoothSigma);
end
c0=abs(corre(floor((size(corre,1)+1)/2),floor((size(corre,2)+1)/2)));
if c0<=0 || ~isfinite(c0), k=NaN; return; end
corre=corre/c0;
average=rotational_average_real(corre,P.NumAngles);
profile=average(floor((size(corre,1)+1)/2),:);
x=(-floor(size(corre,2)/2):floor(size(corre,2)/2))*dx;
try
    fitresult=create_fit_attenuation_1d_rswe(x,profile,2*pi/(P.cs_guess/P.f0));
    k=fitresult.k;
catch
    k=NaN;
end
end

function corre=local_corr2d(M,mode)
[m,n]=size(M);
switch lower(string(mode))
    case "xcorr2", corre=xcorr2(M);
    case "autocorr2d"
        F=fft2(M,2*m-1,2*n-1); corre=fftshift(ifft2(F.*conj(F)));
    otherwise, error('reqml:aia:UnknownCorrMode','Unknown CorrMode: %s',mode);
end
end

function average=rotational_average_real(corre,num_angles)
R=real(corre); average=zeros(size(R)); angles=linspace(0,360,num_angles+1);
for index=1:num_angles
    average=average+imrotate(R,angles(index),'bilinear','crop');
end
average=average/num_angles;
end

function fitresult=create_fit_attenuation_1d_rswe(x,y,k0)
[xData,yData]=prepareCurveData(x,y);
ft=fittype('3*((-k)*x*cos(k*x) + sin(k*x) + k^2*x^2*sin(k*x))/(4*k^3*x^3)', ...
    'independent','x','dependent','y');
opts=fitoptions('Method','NonlinearLeastSquares'); opts.Display='Off';
opts.Lower=50; opts.StartPoint=k0; opts.Exclude=(xData==0)|(yData>=1);
fitresult=fit(xData,yData,ft,opts);
end
