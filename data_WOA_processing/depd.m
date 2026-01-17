for i = 1: length(files)-1
    filepath = files(i);
    copyfile(filepath, pwd)
end
