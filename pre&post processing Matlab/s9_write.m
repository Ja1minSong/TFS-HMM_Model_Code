% 主目录
main_dir = 'Your main data folder path';

% 获取所有 chb 文件夹
chb_dirs = dir(fullfile(main_dir, 'chb*'));

% 遍历每个 chb 文件夹
for i = 1:length(chb_dirs)
    chb_path = fullfile(main_dir, chb_dirs(i).name);
    if ~chb_dirs(i).isdir, continue; end

    % 获取该 chb 下所有 seizure 文件夹
    seizure_dirs = dir(fullfile(chb_path, 'seizure*'));
    for j = 1:length(seizure_dirs)
        seizure_path = fullfile(chb_path, seizure_dirs(j).name);
        if ~seizure_dirs(j).isdir, continue; end

        fprintf('正在处理: %s\n', seizure_path);

        % ==== 拼接原始数据 ====
        type_list = {'interictal', 'preictal', 'ictal', 'postictal'};
        all_data = [];
        all_data_stft = [];
        time_col = {};
        type_col = {};
        label_col = [];
        time_counter = 0; % 时间递增 (秒)

        for t = 1:length(type_list)
            type_name = type_list{t};
            mat_file = fullfile(seizure_path, [type_name '.mat']);
            stft_file = fullfile(seizure_path, [type_name '_stft.mat']);

            if exist(mat_file, 'file')
                % 载入原始 data
                S = load(mat_file);
                cur_data = S.data;
                all_data = cat(1, all_data, cur_data);

                % 生成 result.xlsx 内容
                num_samples = size(cur_data,1);
                for k = 1:num_samples
                    start_time = time_counter;
                    end_time = time_counter + 4;
                    time_col{end+1,1} = sprintf('%d-%d', start_time, end_time);
                    type_col{end+1,1} = type_name;
                    if strcmp(type_name,'preictal')
                        label_col(end+1,1) = 1;
                    else
                        label_col(end+1,1) = 0;
                    end
                    time_counter = time_counter + 4;
                end
            end

            if exist(stft_file, 'file')
                % 载入 STFT data
                S2 = load(stft_file);
                cur_data_stft = S2.data;
                all_data_stft = cat(1, all_data_stft, cur_data_stft);
            end
        end

        % ==== 保存 mat 文件，变量名统一为 data ====
        data = all_data; %#ok<NASGU>
        save(fullfile(seizure_path, 'test.mat'), 'data', '-v7.3');

        data = all_data_stft; %#ok<NASGU>
        save(fullfile(seizure_path, 'test_stft.mat'), 'data', '-v7.3');

        % ==== 保存 Excel 文件 ====
        T = table(time_col, type_col, label_col, ...
                  'VariableNames', {'time','type','label'});
        writetable(T, fullfile(seizure_path, 'result.xlsx'));
    end
end

disp('所有 seizure 文件夹处理完成，mat 文件变量名已统一为 data。');
