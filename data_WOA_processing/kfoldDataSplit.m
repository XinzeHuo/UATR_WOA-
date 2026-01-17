% 对16k采样率的shipsear数据集进行海洋声信道扩充
% 生成label需要把原来的删除
%%

train_list_path = "E:\MTQP\wjy_codes\shipsear_5s_16k_ocnwav_Pos\train_list.txt"; % 原始数据文件夹路径
test_list_path = "E:\MTQP\wjy_codes\shipsear_5s_16k_ocnwav_Pos\test_list.txt";

train_list = readcell(train_list_path);
test_list = readcell(test_list_path);

cat_list = [train_list; test_list];

[FN, IS] = natsortfiles(cat_list(:,1));

% oriDataPath = "E:\1.0_UWTR_Datasets\dataset"; % 原始数据文件夹路径

rmdr_list = [1 2 3 4 0];
for i = 1: length(rmdr_list)
    rmdr = rmdr_list(i);
    TrainTxtPath = sprintf("%s\\train_list_%d.txt", oriDataPath, i);
    TestTxtPath  = sprintf("%s\\test_list_%d.txt" , oriDataPath, i);
    fidTrain = fopen(TrainTxtPath, 'wt+');
    fidTest  = fopen(TestTxtPath,  'wt+');
    for k = 1: length(FN)
        wavPath = FN{k}; % wav路径
        class = cat_list{IS(k),2}; 
        Range = cat_list{IS(k),3}; 
        Depth = cat_list{IS(k),4}; 
        if mod(k,5) == rmdr % Kfold，余数等于预设的作为测试集
            fprintf(fidTest , "%-100s\t%d\t%.3f\t%.3f\n", wavPath, class, Range, Depth);
        else
            fprintf(fidTrain, "%-100s\t%d\t%.3f\t%.3f\n", wavPath, class, Range, Depth);
        end
    end
    fclose(fidTrain);
    fclose(fidTest);
end
