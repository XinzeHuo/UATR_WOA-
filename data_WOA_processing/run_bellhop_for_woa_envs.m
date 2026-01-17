% run_bellhop_for_woa_envs.m
clear; clc;

env_dir = 'woa_envs';
cd(env_dir);

env_files = dir('*.env');
fprintf('Found %d env files.\n', numel(env_files));

for k = 1:numel(env_files)
    [~, envName, ~] = fileparts(env_files(k).name);
    fprintf('[%d/%d] Running bellhop for %s\n', k, numel(env_files), envName);
    try
        % 如果有 bellhop.m（MATLAB 版本）：
        bellhop(envName);

        % 如果是系统命令版本，用这行代替上面那行：
        % system(sprintf('bellhop %s', envName));

    catch ME
        warning('Bellhop failed for %s: %s', envName, ME.message);
    end
end

cd('..');
fprintf('Done.\n');
