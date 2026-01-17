%% 海洋声信道数据生成主流程 | Main workflow of ocean acoustic channel data generation
% 输入参数:
%   oriDataPath - 原始音频数据路径 | Raw audio data path
%   ocnDataPath - 生成数据存储路径 | Generated data storage path
%
% 主要功能:
%   1. 加载BELLHOP仿真结果
%   2. 应用声场传播模型到音频数据
%   3. 生成多位置声学特征数据集
%
% Main functions:
%   1. Load BELLHOP simulation results
%   2. Apply acoustic propagation model to audio
%   3. Generate multi-position acoustic feature dataset

%%
% 文件结构
% -0
% --0_0
% --0_1
oriDataPath = "E:\MTQP\wjy_codes\shipsear_5s_16k"; % 原始数据文件夹路径
ocnDataPath = "E:\MTQP\wjy_codes\shipsear_5s_16k_ocnwav_Posyye"; % 扩充数据文件夹路径

if ~exist(ocnDataPath, 'dir')
    mkdir(ocnDataPath)
end
% 划分数据集
txtCell = funReadTestLb("test_list.txt");
txtCellFt = funReadTestLb("train_list.txt");
txtCellFt = txtCellFt(1:end); % 测试距离定位任务，迁移学习不用全部训练数据
txtCell = txtCell(1:end);

subFolderList = funDirFolder(oriDataPath);
ARRFIL = 'Pos1Azi1freq100Hz';
bellhop(ARRFIL)
[Arr, Pos] = read_arrivals_bin([ARRFIL '.arr']);
FtTxtPath = sprintf("%s\\%s", ocnDataPath, "train_list.txt");
FtTestTxtPath = sprintf("%s\\%s", ocnDataPath, "test_list.txt");
fidFineTune = fopen(FtTxtPath, 'wt+');
fidFTTest = fopen(FtTestTxtPath, 'wt+');
for i = 1: length(subFolderList) % 0
    wavFileList = dir(sprintf('%s\\%s\\**\\*.wav', subFolderList(i).folder, subFolderList(i).name));
    wavNameList = cell(length(wavFileList),1);
    for id = 1: length(wavFileList)
        wavNameList{id} = wavFileList(id).name;
    end
    [FN, IS] =  natsortfiles(wavNameList); % 文件名按照windows排序
    
    for j = 1: length(wavNameList)
        wavName = wavFileList(IS(j)).name;
        wavPath = fullfile(wavFileList(IS(j)).folder, wavName);
        [y, fs] = audioread(wavPath);
        k = mod(j-1, length(Pos.r.r))+1;
        n = mod(ceil(j/ length(Pos.r.r))-1, length(Pos.s.z))+1;
        Arr_A = double(Arr(k, 1, n).A/max(abs(Arr(k, 1, n).A))); % 到达结构最大值归一化
        Arr_TAU = double(Arr(k, 1, n).delay - min(Arr(k, 1, n).delay)); % 减到达结构的最小值
        % y_out = funApplynt(y, fs, Arr_A, Arr_TAU);
        y_out = funOME(y, fs, Arr_A, Arr_TAU);
        y_out = funNorm(y_out);
        wavOutPath = fullfile(ocnDataPath, wavFileList(IS(j)).name);
        if (any(strcmp(wavName, txtCell)))
            audiowrite(wavOutPath, y_out, fs);                   
            fprintf(fidFTTest  , "%-100s\t%s\t%12.3f\t%12.3f\n", wavOutPath, subFolderList(i).name, Pos.r.r(k)/1e3, Pos.s.z(n)/1e3);
        elseif (any(strcmp(wavName, txtCellFt)))
            audiowrite(wavOutPath, y_out, fs);
            fprintf(fidFineTune, "%-100s\t%s\t%12.3f\t%12.3f\n", wavOutPath, subFolderList(i).name, Pos.r.r(k)/1e3, Pos.s.z(n)/1e3);
        end
    end
    fprintf('第%d类处理完毕\n', i);
end
% fclose all;

%% 写config

data.Rrmax = Pos.r.r(end)/1e3;
data.Szmax = Pos.s.z(end)/1e3;

datajson = jsonencode(data);
fid = fopen(sprintf("%s/config.json", ocnDataPath), 'wt');
fprintf(fid, '%s', datajson);
fclose(fid);