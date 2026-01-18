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
% Robustly extract Amp and tau in case they are wrapped in structs
Amp0 = double(local_extract_numeric(ch.Amp));
Amp0 = Amp0(:).';
tau0 = double(local_extract_numeric(ch.tau));
tau0 = tau0(:).';

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
        d_all = local_extract_numeric(ch.meta.range_m);
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

function val = local_extract_numeric(field_val)
% Helper to extract numeric value from field that might be a struct or array
if isstruct(field_val)
    % If it's a struct, try to find a numeric field
    fn = fieldnames(field_val);
    for i = 1:numel(fn)
        tmp = field_val.(fn{i});
        if isnumeric(tmp)
            val = tmp;
            % Log which field was extracted for debugging
            if numel(fn) > 1
                warning('Struct has multiple fields; extracted numeric value from field "%s"', fn{i});
            end
            return;
        end
    end
    % If no numeric field found, return NaN
    warning('Could not extract numeric value from struct (fields: %s), using NaN', strjoin(fn, ', '));
    val = NaN;
elseif isnumeric(field_val)
    val = field_val;
else
    % Handle other types (cell, etc.)
    warning('Unexpected field type (%s), using NaN', class(field_val));
    val = NaN;
end
end
