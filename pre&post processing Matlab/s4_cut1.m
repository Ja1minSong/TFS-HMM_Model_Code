% === 设置参数 ===
file_path = 'file path\chb22_24_1_interictal.mat';   % 要处理的 mat 文件路径
mode = 'front';      % 选项: 'front' 前面部分, 'end' 最后部分, 'middle' 中间部分
percentage = 0.5;     % 保留的比例 (0~1)，如 0.3 表示 30%
middle_start = 0.75;   % 仅在 mode = 'middle' 时有效，表示起始百分比 (0~1)

% === 加载文件 ===
S = load(file_path);
if ~isfield(S, 'data')
    error('文件中未找到变量 "data"。');
end
data = S.data;

% === 检查维度 ===
[channels, samples] = size(data);

% === 根据模式选择采样点范围 ===
switch mode
    case 'front'   % 前面部分
        keep_samples = round(samples * percentage);
        data = data(:, 1:keep_samples);

    case 'end'     % 最后部分
        keep_samples = round(samples * percentage);
        data = data(:, end-keep_samples+1:end);

    case 'middle'  % 中间部分
        start_idx = round(samples * middle_start) + 1;
        end_idx   = start_idx + round(samples * percentage) - 1;
        if end_idx > samples
            end_idx = samples;
        end
        data = data(:, start_idx:end_idx);

    otherwise
        error('无效的 mode 参数，应为 front / end / middle');
end

% === 覆盖保存，变量名保持不变 ===
save(file_path, 'data', '-v7');

fprintf('文件已处理并覆盖保存: %s\n', file_path);
