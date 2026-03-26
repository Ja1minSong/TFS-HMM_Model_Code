root_dir = 'Your main data folder path';

% 获取所有 chb 文件夹
chb_dirs = dir(fullfile(root_dir, 'chb*'));

% 遍历每个 chb 文件夹
for i = 1:length(chb_dirs)
    chb_path = fullfile(root_dir, chb_dirs(i).name);

    % 获取所有 seizure 文件夹
    seizure_dirs = dir(fullfile(chb_path, 'seizure*'));

    for j = 1:length(seizure_dirs)
        seizure_path = fullfile(chb_path, seizure_dirs(j).name);

        % 获取该目录下所有 .mat 文件
        mat_files = dir(fullfile(seizure_path, '*.mat'));

        for k = 1:length(mat_files)
            file_path = fullfile(seizure_path, mat_files(k).name);
            fprintf('Processing file: %s\n', file_path);

            % 加载数据
            S = load(file_path);
            if ~isfield(S, 'data')
                warning('No variable "data" found in %s. Skipping.', file_path);
                continue;
            end
            data = S.data;

            % 采样率（根据你的数据设定）
            fs = 256;

            % === 设计 50Hz 陷波滤波器（Butterworth 二阶）===
            d_notch = designfilt('bandstopiir', 'FilterOrder', 2, ...
                'HalfPowerFrequency1', 49, 'HalfPowerFrequency2', 51, ...
                'DesignMethod', 'butter', 'SampleRate', fs);

            % === 设计带通滤波器（0.5 – 70 Hz）===
            d_bandpass = designfilt('bandpassiir', 'FilterOrder', 4, ...
                'HalfPowerFrequency1', 0.5, 'HalfPowerFrequency2', 70, ...
                'DesignMethod', 'butter', 'SampleRate', fs);

            % === 对每个通道进行滤波 ===
            for ch = 1:size(data, 1)
                signal = double(data(ch, :));       % 转为 double 避免类型错误
                signal = filtfilt(d_notch, signal); % 先陷波滤除 50Hz
                signal = filtfilt(d_bandpass, signal); % 再带通滤波
                data(ch, :) = signal;               % 回存到原矩阵
            end

            % 覆盖保存
            save(file_path, 'data', '-v7');
        end
    end
end

disp('所有文件滤波完成。');
