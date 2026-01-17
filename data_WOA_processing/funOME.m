function y = funOME(x, fs, Amp, tau)
% 海洋环境多径效应建模函数 | Ocean Multipath Effect Modeling
% 输入:
%   x   : 输入时域信号
%   fs  : 采样率
%   Amp : 多径幅度向量
%   tau : 多径时延向量
% 输出:
%   y   : 卷积后的信号

    Fx = fft(x).';
    
    % 找到最强路径，将其时延设为0（相对时延）
    [~, indmx ] = max(abs(Amp));
    tau = tau - tau(indmx);  
    tau = tau.'; 
    
    % 频率向量
    fk = (0: length(x)-1)/ length(x) * fs;
    
    % 频域相位延迟计算 (核心步骤)
    % H(f) = sum( Amp * exp(-j*2*pi*f*tau) )
    % 利用矩阵运算一次性计算所有频率点
    Fy = Amp * (exp(-1j * 2 * pi * tau * fk) .* (ones(length(Amp), 1) * Fx));
    
    % 恢复到时域
    y = ifft(Fy, 'symmetric');
    
    % 简单的预归一化
    y = y / max(abs(y)) * 0.9;
end