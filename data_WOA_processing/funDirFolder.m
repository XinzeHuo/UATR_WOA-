function subFolderList = funDirFolder(fpath)
% 列出fpath下面的所有文件夹
subPathList = dir(fpath);
j = 1;
for i = 3: length(subPathList) % 去掉当前路径. 和上一级路径..
    if subPathList(i).isdir == 1  % 如果为文件夹则复制
        subFolderList(j) = subPathList(i);
        j = j + 1;
    end
end