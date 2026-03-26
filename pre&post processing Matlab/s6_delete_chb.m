% 设置主目录
root_dir = 'Your main data folder path';

% 获取所有 chb 文件夹
chb_dirs = dir(fullfile(root_dir, 'chb*'));

for i = 1:length(chb_dirs)
    chb_path = fullfile(root_dir, chb_dirs(i).name);

    % 获取所有 seizure 文件夹
    seizure_dirs = dir(fullfile(chb_path, 'seizure*'));

    for j = 1:length(seizure_dirs)
        seizure_path = fullfile(chb_path, seizure_dirs(j).name);

        % 获取该目录下所有以 chb 开头的 mat 文件
        mat_files = dir(fullfile(seizure_path, 'chb*.mat'));

        for k = 1:length(mat_files)
            file_path = fullfile(seizure_path, mat_files(k).name);
            delete(file_path); % 删除文件
            fprintf('Deleted: %s\n', file_path);
        end
    end
end

disp('所有 chb 开头的 mat 文件已删除。');
