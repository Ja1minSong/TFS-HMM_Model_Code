% 设置主目录
main_dir = 'Your main data folder path';

% 获取所有 chb* 文件夹
chb_dirs = dir(fullfile(main_dir, 'chb*'));

% 四类文件名
types = {'interictal','preictal','ictal','postictal'};

for i = 1:length(chb_dirs)
    chb_path = fullfile(main_dir, chb_dirs(i).name);
    if ~chb_dirs(i).isdir
        continue;
    end

    % 遍历 seizure* 子文件夹
    seizure_dirs = dir(fullfile(chb_path, 'seizure*'));
    for j = 1:length(seizure_dirs)
        seizure_path = fullfile(chb_path, seizure_dirs(j).name);
        if ~seizure_dirs(j).isdir
            continue;
        end

        fprintf('正在处理: %s\n', seizure_path);

        % 遍历四类类型文件
        for t = 1:length(types)
            type_name = types{t};

            % 原始类型.mat
            file1 = fullfile(seizure_path, [type_name '.mat']);
            if exist(file1, 'file')
                delete(file1);
                fprintf('已删除: %s\n', file1);
            end

            % 对应的_stft.mat
            file2 = fullfile(seizure_path, [type_name '_stft.mat']);
            if exist(file2, 'file')
                delete(file2);
                fprintf('已删除: %s\n', file2);
            end
        end
    end
end

disp('所有指定文件已删除完成。');
