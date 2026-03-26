% 设置主目录
root_dir = 'Your main data folder path';

% 获取所有 chb 文件夹
chb_dirs = dir(fullfile(root_dir, 'chb*'));

% 四种类型
types = {'interictal', 'preictal', 'ictal', 'postictal'};

for i = 1:length(chb_dirs)
    chb_path = fullfile(root_dir, chb_dirs(i).name);

    % 获取所有 seizure 文件夹
    seizure_dirs = dir(fullfile(chb_path, 'seizure*'));

    for j = 1:length(seizure_dirs)
        seizure_path = fullfile(chb_path, seizure_dirs(j).name);
        fprintf('Processing folder: %s\n', seizure_path);

        for t = 1:length(types)
            type_name = types{t};

            % 使用正则精确匹配 "_type.mat" 结尾
            mat_files_all = dir(fullfile(seizure_path, '*.mat'));
            mat_files = [];
            for k = 1:length(mat_files_all)
                fname = mat_files_all(k).name;
                if ~isempty(regexp(fname, ['_' type_name '\.mat$'], 'once'))
                    mat_files = [mat_files; mat_files_all(k)];
                end
            end
            if isempty(mat_files)
                continue; % 没有该类型文件
            end

            % 提取 YY 和 Z 排序
            file_info = [];
            for k = 1:length(mat_files)
                fname = mat_files(k).name;
                tokens = regexp(fname, 'chb\d+_(\d+)_(\d+)_', 'tokens');
                if ~isempty(tokens)
                    YY = str2double(tokens{1}{1});
                    Z  = str2double(tokens{1}{2});
                else
                    YY = inf; Z = inf;
                end
                file_info = [file_info; struct('name', fname, 'YY', YY, 'Z', Z)];
            end
            [~, sort_idx] = sortrows([[file_info.YY]' [file_info.Z]'], [1 2]);
            mat_files = mat_files(sort_idx);

            % 重置 merged_data
            merged_data = [];

            % 合并
            for k = 1:length(mat_files)
                file_path = fullfile(seizure_path, mat_files(k).name);
                S = load(file_path);
                if ~isfield(S, 'data')
                    warning('No variable "data" in %s. Skipping.', file_path);
                    continue;
                end
                if isempty(merged_data)
                    merged_data = S.data;
                else
                    merged_data = [merged_data, S.data];
                end
            end

            % 保存合并文件
            out_file = fullfile(seizure_path, [type_name '.mat']);
            data = merged_data; %#ok<NASGU>
            save(out_file, 'data', '-v7');
            fprintf('Saved merged file: %s\n', out_file);
        end
    end
end

disp('所有文件合并完成。');

