function plot_smoke_wavefields()

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));

root = fullfile( ...
    repo_root, ...
    "outputs","validation","angular_aperture_validation_v1", ...
    "smoke_simulation","angular_aperture_validation_v1_smoke");

runs = [
    struct( ...
        "run_dir","run_000001_4a27f42c2cc9", ...
        "label","Near directional", ...
        "omega_sr",0.01)
    struct( ...
        "run_dir","run_000002_a242c02749bb", ...
        "label","Intermediate", ...
        "omega_sr",pi)
];

out_dir = fullfile( ...
    repo_root, ...
    "outputs","validation","angular_aperture_validation_v1", ...
    "smoke_diagnostics");

if ~isfolder(out_dir)
    mkdir(out_dir);
end

fig = figure( ...
    "Visible","off", ...
    "Color","w", ...
    "Position",[100 100 1350 720]);

tl = tiledlayout(2,3, ...
    "TileSpacing","compact", ...
    "Padding","compact");

for i = 1:2

    f = fullfile( ...
        root,runs(i).run_dir,"data","wavefield_sample.mat");

    S = load(f,"wavefield_sample");
    W = S.wavefield_sample;

    U = double(W.wavefield.data_zx);

    x_mm = 1e3 * double(W.coordinates.x_m);
    z_mm = 1e3 * double(W.coordinates.z_m);

    amp = abs(U);
    amp = amp ./ max(amp(:));

    ph = angle(U);

    % Spatial spectrum, display only.
    F = fftshift(fft2(U));
    P = abs(F).^2;
    P = P ./ max(P(:));

    dx = mean(diff(double(W.coordinates.x_m)));
    dz = mean(diff(double(W.coordinates.z_m)));

    Nx = numel(x_mm);
    Nz = numel(z_mm);

    kx = 2*pi * ((-floor(Nx/2)):(ceil(Nx/2)-1)) / (Nx*dx);
    kz = 2*pi * ((-floor(Nz/2)):(ceil(Nz/2)-1)) / (Nz*dz);

    kx = kx / 1e3;  % rad/mm
    kz = kz / 1e3;

    % Amplitude
    nexttile((i-1)*3 + 1);
    imagesc(x_mm,z_mm,amp);
    axis image;
    set(gca,"YDir","normal");
    xlabel("x (mm)");
    ylabel("z (mm)");
    title(sprintf("%s | |U|",runs(i).label));
    colorbar;

    % Phase
    nexttile((i-1)*3 + 2);
    imagesc(x_mm,z_mm,ph);
    axis image;
    set(gca,"YDir","normal");
    clim([-pi pi]);
    xlabel("x (mm)");
    ylabel("z (mm)");
    title(sprintf("\\Omega = %.4g sr | phase",runs(i).omega_sr));
    colorbar;

    % Spectrum
    nexttile((i-1)*3 + 3);
    imagesc(kx,kz,log10(P + 1e-8));
    axis image;
    set(gca,"YDir","normal");
    xlabel("k_x (rad/mm)");
    ylabel("k_z (rad/mm)");
    title("log_{10} normalized spectral power");
    colorbar;

end

title(tl, ...
    "Angular-aperture smoke diagnostics | c_s = 3 m/s, f = 500 Hz");

out_file = fullfile(out_dir,"smoke_wavefields.png");
exportgraphics(fig,out_file,"Resolution",250);
close(fig);

fprintf("Saved:\n%s\n",out_file);

end
