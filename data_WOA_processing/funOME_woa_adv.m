function [y, Hk, cfg_used] = funOME_woa_adv(x, fs, ch, cfg)
% 高级 WOA 多径叠加：shadowing + delay jitter + Thorp 吸收

if nargin < 4, cfg = struct(); end
cfg_defaults = struct( ...
    'use_shadowing', true, ...
    'shadow_sigma_db', 3.0, ...
    'use_delay_jitter', true, ...
    'delay_jitter_max', 0.5e-3, ...
    'use_absorption', true, ...
    'normalize_output', true, ...
    'output_mode', 'same', ... % 'same' or 'full'
    'seed', [] ...
    );
cfg_used = cfg_defaults;
if ~isempty(cfg)
    fn = fieldnames(cfg);
    for i=1:numel(fn)
        cfg_used.(fn{i}) = cfg.(fn{i});
    end
end

if ~isempty(cfg_used.seed)
    rng(cfg_used.seed);
end

x = x(:);
N = length(x);
if ~isfield(ch,'Amp') || ~isfield(ch,'tau')
    error('ch must contain fields Amp and tau.');
end
Amp0 = double(ch.Amp(:).');
tau0 = double(ch.tau(:).');

P = numel(Amp0);
if P == 0
    y  = zeros(N,1);
    Hk = [];
    return;
end

% 1) shadowing
if cfg_used.use_shadowing
    sigma_db = cfg_used.shadow_sigma_db;
    dB_perturb = sigma_db * randn(size(Amp0));
    Amp = Amp0 .* 10.^(dB_perturb/20);
else
    Amp = Amp0;
end

% 2) delay jitter
if cfg_used.use_delay_jitter
    dt_max = cfg_used.delay_jitter_max;
    dt  = (2*rand(size(tau0)) - 1) * dt_max;
    tau = tau0 + dt;
else
    tau = tau0;
end

[~, imax] = max(abs(Amp));
tau = tau - tau(imax);

max_delay_samp = ceil(max(abs(tau)) * fs);
Nfft = 2^nextpow2(N + max_delay_samp);

Fx = fft(x, Nfft).';
fk = (0:(Nfft-1)) * (fs / Nfft);

phase = exp(-1j * 2 * pi * (tau(:) * fk));

% 5) Thorp 吸收
if cfg_used.use_absorption
    alpha_db_per_km = thorp_alpha(fk);
    if isfield(ch, 'meta') && isfield(ch.meta, 'range_m')
        d_all = ch.meta.range_m;
        if numel(d_all) == 1
            d_all = repmat(d_all, size(Amp));
        end
        d_all = double(d_all(:).');
    else
        warning('ch.meta.range_m not present; using nominal 1 km for absorption scaling.');
        d_all = ones(1,P) * 1000;
    end
    dist_km = d_all / 1e3;
    G_mat = 10 .^ ( - (dist_km(:) * alpha_db_per_km) / 20 );
else
    G_mat = ones(P, Nfft);
end

Amp_mat = Amp(:) * ones(1, Nfft);
H_mat   = Amp_mat .* phase .* G_mat;
Hk      = sum(H_mat, 1);

Yk    = Fx .* Hk;
y_full = ifft(Yk, Nfft).';

if strcmpi(cfg_used.output_mode, 'full')
    y = real(y_full(1:Nfft));
else
    y = real(y_full(1:N));
end

if cfg_used.normalize_output
    rms_x = rms(x);
    rms_y = rms(y);
    if rms_y > eps
        y = y * (rms_x / rms_y);
    end
end

end

function alpha_db = thorp_alpha(f_hz)
f_khz = f_hz / 1e3;
f2    = f_khz.^2;
alpha_db = 0.11 * f2 ./ (1 + f2) + 44 * f2 ./ (4100 + f2) + 2.75e-4 * f2 + 0.003;
alpha_db(~isfinite(alpha_db)) = max(alpha_db(isfinite(alpha_db)));
alpha_db(alpha_db < 0) = 0;
end
