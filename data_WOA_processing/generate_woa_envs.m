% generate_woa_envs.m
% 批量生成 Bellhop environment (.env) 文件并可尝试调用 bellhop 运行

clear; clc;

% 参数配置
matfile   = 'E:\rcq\pythonProject\Data\WOA23_mat\woa23_00.mat'; % 含 Depth/Lat/Lon/Temp/Sal/ssp
SSP_TYPES = {'munk', 'summer_shallow', 'isothermal', 'winter_shallow', 'deep_channel'};
H_list    = [50, 200, 1000];                    % 水深 (m)
R_list    = [0.5, 2, 5, 10] * 1e3;              % 收发距 (m)
BOT_list  = {'sand', 'mud'};

env_idx   = 1;
out_folder = 'woa_envs';
if ~exist(out_folder,'dir'), mkdir(out_folder); end

for s = 1:numel(SSP_TYPES)
    for h = 1:numel(H_list)
        for r = 1:numel(R_list)
            for b = 1:numel(BOT_list)

                [lat, lon, month] = pick_lat_lon_for_ssp(SSP_TYPES{s});
                depth_grid = linspace(0, H_list(h), 50)';

                try
                    ssp = load_ssp_from_WOA(lat, lon, month, depth_grid, matfile);
                catch ME
                    warning('load_ssp_from_WOA failed for %s, lat=%.2f lon=%.2f: %s', ...
                        SSP_TYPES{s}, lat, lon, ME.message);
                    continue;
                end

                src_z = min(20, 0.4 * H_list(h));
                rcv_z = [max(1, 0.2*H_list(h)), max(1, 0.6*H_list(h))];
                r_vec = R_list(r);

                envName = sprintf('env_%03d_%s_H%d_R%d_%s', ...
                    env_idx, SSP_TYPES{s}, H_list(h), round(R_list(r)), BOT_list{b});
                envPath = fullfile(out_folder, envName);

                try
                    write_bellhop_env_woa(envPath, ssp, H_list(h), BOT_list{b}, src_z, rcv_z, r_vec);
                    fprintf('Wrote %s.env\n', envPath);
                catch ME
                    warning('Failed to write env %s: %s', envPath, ME.message);
                    continue;
                end

                % 可选：调用 Bellhop 生成 .arr
                %{
                try
                    curdir = pwd;
                    cd(out_folder);
                    % bellhop(envName);  % 如果有 bellhop.m
                    % 或 system 调用:
                    % system(sprintf('bellhop %s', envName));
                    cd(curdir);
                catch ME
                    warning('Bellhop run failed or skipped for %s: %s', envName, ME.message);
                end
                %}

                env_idx = env_idx + 1;
            end
        end
    end
end

fprintf('Generated %d env files in folder %s\n', env_idx-1, out_folder);
