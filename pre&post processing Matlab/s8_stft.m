clear; clc;

% ====== 根路径设置 ======
rootPath = 'Your main data folder path';

% ====== 遍历 chbXX 文件夹 ======
chbFolders = dir(fullfile(rootPath, 'chb*'));

for i = 1:length(chbFolders)
    chbPath = fullfile(rootPath, chbFolders(i).name);

    % 遍历 seizureXX 子文件夹
    seizureFolders = dir(fullfile(chbPath, 'seizure*'));

    for j = 1:length(seizureFolders)
        seizurePath = fullfile(chbPath, seizureFolders(j).name);

        % 处理四种类型的 mat 文件
        for type = ["interictal", "preictal", "ictal", "postictal"]
            matFile = fullfile(seizurePath, type + ".mat");

            if exist(matFile, 'file')
                % 加载数据
                fprintf('Processing: %s\n', matFile);
                S = load(matFile);
                if isfield(S, 'data')
                    eegData = S.data;  % [样本数 × 通道数 × 采样点数]
                else
                    warning('%s 不包含 data 变量，跳过。\n', matFile);
                    continue;
                end

                [numSamples, numChannels, ~] = size(eegData);
                stftData = zeros(numSamples, numChannels, 32, 32);

                % 对每个样本、通道执行 STFT 并 resize
                for n = 1:numSamples
                    for ch = 1:numChannels
                        signal = squeeze(eegData(n, ch, :));
                        [s, ~, ~] = spectrogram(signal, hamming(256), 128, [], 256); % fs=256Hz
                        spec = abs(s);
                        resizedSpec = imresize(spec, [32, 32]);
                        stftData(n, ch, :, :) = resizedSpec;
                    end
                end

                % 保存结果
                saveFile = fullfile(seizurePath, type + "_stft.mat");
                data = stftData; %#ok<NASGU> % 保存变量名为 data
                save(saveFile, 'data', '-v7.3');
                fprintf('Saved STFT to: %s\n', saveFile);
            end
        end
    end
end

disp('所有 STFT 转换完成！');
