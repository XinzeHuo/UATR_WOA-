function ChannelPool = build_channel_pool_woa(arr_dir, max_paths, normalize_amplitude)

if nargin < 2 || isempty(max_paths)
    max_paths = 32;
end
if nargin < 3 || isempty(normalize_amplitude)
    normalize_amplitude = true;
end

arr_files = dir(fullfile(arr_dir, '*.arr'));
if isempty(arr_files)
    error('No .arr files found in directory: %s', arr_dir);
end

ChannelPool = struct('Amp', {}, 'tau', {}, 'tau_rel', {}, ...
                     'power_db', {}, 'Npaths', {}, 'meta', {});

idx = 1;
for k = 1:numel(arr_files)
    arr_name = arr_files(k).name;
    arr_path = fullfile(arr_dir, arr_name);
    fprintf('[%d/%d] Reading arrivals: %s\n', k, numel(arr_files), arr_name);

    try
        [Arr, Pos] = read_arrivals_bin(arr_path);
    catch ME
        warning('Failed to read %s : %s', arr_path, ME.message);
        continue;
    end

    % Pos.r.r : ranges (m)
    % Pos.s.z : source depths (m)
    % Pos.r.z : receiver depths (m)
    if ~isfield(Pos,'r') || ~isfield(Pos.r,'r') || ~isfield(Pos.r,'z') || ~isfield(Pos,'s') || ~isfield(Pos.s,'z')
        warning('Pos structure from %s missing expected fields (r.r / r.z / s.z). Skipping file.', arr_name);
        continue;
    end

    ranges      = double(Pos.r.r(:));
    src_depths  = double(Pos.s.z(:));
    rcv_depths  = double(Pos.r.z(:));

    for isd = 1:numel(src_depths)
        for irz = 1:numel(rcv_depths)
            for irr = 1:numel(ranges)

                % Arr indexing 可能是 (ir, iz, is) 等，做几次尝试
                try
                    arrElem = Arr(irr, irz, isd);
                catch
                    try
                        arrElem = Arr(irr, isd, irz);
                    catch
                        try
                            arrElem = Arr(isd, irz, irr);
                        catch
                            warning('Unexpected Arr indexing for file %s; skipping this triplet.', arr_name);
                            continue;
                        end
                    end
                end

                Narr = 0;
                if isfield(arrElem, 'Narr')
                    Narr = double(arrElem.Narr);
                elseif isfield(arrElem, 'A')
                    Narr = numel(arrElem.A);
                end
                if Narr <= 0
                    continue;
                end

                if isfield(arrElem, 'A')
                    Amp_all = double(arrElem.A(:));
                else
                    warning('No amplitude field A at Arr(%d,%d,%d) in %s', irr, irz, isd, arr_name);
                    continue;
                end
                if isfield(arrElem, 'delay')
                    tau_all = double(arrElem.delay(:));
                elseif isfield(arrElem, 't')
                    tau_all = double(arrElem.t(:));
                else
                    warning('No delay field in Arr element for %s, skipping', arr_name);
                    continue;
                end

                Nmin = min(numel(Amp_all), numel(tau_all));
                Amp_all = Amp_all(1:Nmin);
                tau_all = tau_all(1:Nmin);

                [~, order] = sort(abs(Amp_all).^2, 'descend');
                keepN = min(max_paths, Nmin);
                keep  = order(1:keepN);

                Amp = Amp_all(keep);
                tau = tau_all(keep);

                [~, imax_rel] = max(abs(Amp));
                tau_ref = tau(imax_rel);
                tau_rel = tau - tau_ref;

                if normalize_amplitude && ~isempty(Amp)
                    Amp = Amp ./ max(abs(Amp));
                end

                total_power = sum(abs(Amp).^2);
                power_db    = 10 * log10(max(total_power, eps));

                meta = struct();
                meta.range_m  = ranges(irr);
                meta.src_z_m  = src_depths(isd);
                meta.rcv_z_m  = rcv_depths(irz);
                meta.arr_file = arr_name;

                [meta.env_name, meta.ssp_type, meta.H, meta.bottom_type] = parse_env_meta(arr_name);

                ChannelPool(idx).Amp       = Amp(:);
                ChannelPool(idx).tau       = tau(:);
                ChannelPool(idx).tau_rel   = tau_rel(:);
                ChannelPool(idx).power_db  = power_db;
                ChannelPool(idx).Npaths    = numel(Amp);
                ChannelPool(idx).meta      = meta;

                idx = idx + 1;
            end
        end
    end
end

fprintf('WOA Channel pool built: total %d channel entries.\n', numel(ChannelPool));
end

%% ------------------------------------------------------------------------
function [env_name, ssp_type, H, bottom_type] = parse_env_meta(filename)
% Attempt to parse env metadata from filename.
[~, name, ~] = fileparts(filename);
env_name = name;
ssp_type = '';
H        = NaN;
bottom_type = '';

parts = split(name, {'_','-'});
parts = parts(:);

ssp_candidates = {'munk','summer','isothermal','winter','deep','summer_shallow','winter_shallow','deep_channel'};
for i=1:numel(parts)
    p = lower(parts{i});
    for j=1:numel(ssp_candidates)
        if contains(p, ssp_candidates{j})
            ssp_type = ssp_candidates{j};
            break;
        end
    end
    if ~isempty(ssp_type), break; end
end

for i=1:numel(parts)
    p = parts{i};
    if startsWith(lower(p), 'h')
        numstr = regexp(p, '\d+','match','once');
        if ~isempty(numstr)
            H = str2double(numstr);
            break;
        end
    end
end

for i=1:numel(parts)
    p = lower(parts{i});
    if contains(p, 'sand')
        bottom_type = 'sand'; break;
    elseif contains(p, 'mud')
        bottom_type = 'mud'; break;
    end
end

if isnan(H)
    num_tokens = regexp(name, '[0-9]+','match');
    if ~isempty(num_tokens)
        for nt = 1:numel(num_tokens)
            val = str2double(num_tokens{nt});
            if val > 10 && val < 10000
                H = val;
                break;
            end
        end
    end
end

end
