% === 设置参数 ===
file_path = 'file path\chb24_20_1_interictal.mat';   % 要处理的 mat 文件路径
keep_points = 460800-257024;                   % 需要保留的采样点数

% === 加载文件 ===
S = load(file_path);
if ~isfield(S, 'data')
    error('文件中未找到变量 "data"。');
end
data = S.data;

% === 检查维度 ===
[channels, samples] = size(data);
if keep_points > samples
    error('保留的采样点数 (%d) 大于原始采样点数 (%d)。', keep_points, samples);
end

% === 裁剪每个通道，保留最后 keep_points 个采样点 ===
data = data(:, end-keep_points+1:end);

% === 覆盖保存，变量名保持不变 ===
save(file_path, 'data', '-v7');

fprintf('文件已处理并覆盖保存: %s\n', file_path);
