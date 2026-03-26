% 设置主目录
root_dir = 'Your main data folder path';

% 获取所有 chb 文件夹
chb_dirs = dir(fullfile(root_dir, 'chb*'));

% 四种类型文件名
types = {'interictal.mat', 'preictal.mat', 'ictal.mat', 'postictal.mat'};

% 每个样本的采样点数
fs = 256;
window_sec = 4;
window_points = fs * window_sec;  % 1024

for i = 1:length(chb_dirs)
    chb_path = fullfile(root_dir, chb_dirs(i).name);

    % 获取所有 seizure 文件夹
    seizure_dirs = dir(fullfile(chb_path, 'seizure*'));

    for j = 1:length(seizure_dirs)
        seizure_path = fullfile(chb_path, seizure_dirs(j).name);
        fprintf('Processing folder: %s\n', seizure_path);

        for t = 1:length(types)
            file_name = types{t};
            file_path = fullfile(seizure_path, file_name);

            if ~isfile(file_path)
                warning('File not found: %s. Skipping.', file_path);
                continue;
            end

            % 加载数据
            S = load(file_path);
            if ~isfield(S, 'data')
                warning('No variable "data" in %s. Skipping.', file_path);
                continue;
            end
            data = S.data;  % channels × total_points
            [channels, total_points] = size(data);

            % 计算可切片的样本数
            num_samples = floor(total_points / window_points);
            if num_samples == 0
                warning('数据点不足 1024，跳过文件: %s', file_path);
                continue;
            end

            % 初始化切片后的矩阵：samples × channels × 1024
            sliced_data = zeros(num_samples, channels, window_points);

            for s = 1:num_samples
                start_idx = (s-1)*window_points + 1;
                end_idx = start_idx + window_points - 1;
                sliced_data(s, :, :) = data(:, start_idx:end_idx);
            end

            % 覆盖保存
            data = sliced_data; %#ok<NASGU>
            save(file_path, 'data', '-v7');
            fprintf('File sliced and saved: %s, total samples: %d\n', file_path, num_samples);
        end
    end
end

disp('所有文件切片完成！');

