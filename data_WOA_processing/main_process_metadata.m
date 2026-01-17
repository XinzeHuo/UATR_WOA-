%% 基于 metadata.csv 的海洋多径效应叠加主程序
% 功能：读取 metadata.csv，对每一条音频应用 Bellhop 仿真的多径信道，
%       并保持原本的 train/test 文件夹结构输出。

clear; clc; close all;

%% === 1. 配置路径 (请修改此处) ===

% 1. metadata.csv 文件的路径
METADATA_PATH = 'E:\rcq\pythonProject\Data\ShipsEar_16k_30s_hop15\metadata.csv'; 

% 2. 干净音频数据的根目录 (metadata.csv 中 filepath 是相对这个目录的)
%    例如 metadata 中的路径是 train\ClassA\..., 这里的 Root 就是包含 train 的那个文件夹
CLEAN_DATA_ROOT = 'E:\rcq\pythonProject\Data\ShipsEar_16k_30s_hop15'; 

% 3. 输出处理后数据的根目录
OUTPUT_ROOT = 'E:\rcq\pythonProject\Data\ShipsEar_16k_30s_hop15_Multipath';

% 4. Bellhop 生成的 Arrivals 文件路径 (.arr)
%    请确保您有这个文件，它包含了信道的物理参数(时延、幅度)
ARR_FILE = 'Pos1Azi1freq100Hz.arr'; 

%% === 2. 加载信道参数 (Bellhop Arrivals) ===

fprintf('正在读取信道参数文件: %s ...\n', ARR_FILE);
if ~isfile(ARR_FILE)
    error('找不到 .arr 文件！请确保该文件存在。');
end

[Arr, Pos] = read_arrivals_bin(ARR_FILE);

% 获取信道参数的维度
num_ranges = length(Pos.r.r); % 接收距离数量
num_depths = length(Pos.s.z); % 声源深度数量

fprintf('信道加载成功！\n');
fprintf('  - 接收距离点数: %d\n', num_ranges);
fprintf('  - 声源深度点数: %d\n', num_depths);

%% === 3. 读取 Metadata 并准备处理 (修正部分) ===

fprintf('正在读取 metadata.csv ...\n');
opts = detectImportOptions(METADATA_PATH);

% --- 修正开始：使用 setvartype 设置变量类型 ---
% 强制将 filepath 列读取为字符数组(char)或字符串(string)，防止被识别为 Categorical 导致路径拼接出错
opts = setvartype(opts, 'filepath', 'char'); 

% 如果需要，也可以将其他文本列设为 char
if ismember('split', opts.VariableNames)
    opts = setvartype(opts, 'split', 'char');
end
% --- 修正结束 ---

meta_table = readtable(METADATA_PATH, opts);

num_files = height(meta_table);
fprintf('共发现 %d 个音频文件待处理。\n', num_files);

if ~exist(OUTPUT_ROOT, 'dir')
    mkdir(OUTPUT_ROOT);
end

%% === 4. 循环处理 ===

h = waitbar(0, '正在处理多径效应叠加...');

for i = 1:num_files
    try
        % --- A. 获取文件路径 ---
        rel_path = meta_table.filepath{i};
        
        % 确保 rel_path 是字符串
        if iscell(rel_path)
            rel_path = rel_path{1};
        end
        
        % 修复路径分隔符 (防止 Windows/Linux 混用问题)
        rel_path = strrep(rel_path, '/', filesep);
        rel_path = strrep(rel_path, '\', filesep);
        
        in_wav_path = fullfile(CLEAN_DATA_ROOT, rel_path);
        
        % --- B. 确定输出路径 ---
        out_wav_path = fullfile(OUTPUT_ROOT, rel_path);
        out_dir = fileparts(out_wav_path);
        if ~exist(out_dir, 'dir')
            mkdir(out_dir);
        end
        
        % --- C. 读取音频 ---
        if ~isfile(in_wav_path)
            % 偶尔可能 metadata 里有文件但磁盘上没有，跳过不报错
            fprintf('警告：文件不存在，跳过: %s\n', in_wav_path);
            continue;
        end
        
        [x, fs] = audioread(in_wav_path);
        
        % --- D. 选择信道参数 (核心逻辑) ---
        % k: 距离索引 (Range Index)
        k = mod(i-1, num_ranges) + 1;
        
        % n: 深度索引 (Source Depth Index)
        n = mod(ceil(i / num_ranges) - 1, num_depths) + 1;
        
        % Arr(range_idx, receiver_depth_idx, source_depth_idx)
        curr_Arr = Arr(k, 1, n);
        
        if isempty(curr_Arr.A)
             y_out = x;
        else
            Arr_A = double(curr_Arr.A / max(abs(curr_Arr.A))); 
            Arr_TAU = double(curr_Arr.delay - min(curr_Arr.delay)); 
            
            % --- E. 应用频域多径效应 (funOME) ---
            y_out = funOME(x, fs, Arr_A, Arr_TAU);
            
            % --- F. 归一化 (funNorm) ---
            y_out = funNorm(y_out);
        end
        
        % --- G. 保存文件 ---
        audiowrite(out_wav_path, y_out, fs);
        
    catch ME
        fprintf('处理文件出错 (Index: %d): %s\n错误信息: %s\n', i, rel_path, ME.message);
    end
    
    % 更新进度条
    if mod(i, 100) == 0
        waitbar(i/num_files, h, sprintf('已处理: %d / %d', i, num_files));
    end
end

close(h);
fprintf('所有处理完成！新数据集保存在: %s\n', OUTPUT_ROOT);