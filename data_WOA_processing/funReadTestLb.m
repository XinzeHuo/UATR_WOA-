function txtCell = funReadTestLb(filepath)
% 读取测试标签文本文件 | Read test label text file
% 输入参数:
%   filepath : 文本文件路径 (字符串)
% 输出参数:
%   txtCell  : 单元格数组 (N×1 cell)，每元素对应一行文本
% 算法流程:
%   1. 以只读模式打开文本文件
%   2. 逐行读取字符串直到文件末尾
%   3. 存储到预分配的单元格数组中

fid = fopen(filepath, 'rt');
txtCell = cell(1,1); % 初始化单元格数组 | Initialize cell array
i = 1;
while(~feof(fid)) % 循环直到文件末尾 | Loop until end of file
    txtCell{i,1} = fscanf(fid, '%s\n', 1);
    i = i+1;
end
fclose(fid);