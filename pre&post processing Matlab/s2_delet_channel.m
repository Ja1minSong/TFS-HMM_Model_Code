clc;clear all;
root_dir = 'Your main data folder path';

% 获取所有 chb 文件夹
chb_dirs = dir(fullfile(root_dir, 'chb*'));

for i = 1:length(chb_dirs)
    chb_path = fullfile(root_dir, chb_dirs(i).name);
    
    % 获取所有 seizure 文件夹
    seizure_dirs = dir(fullfile(chb_path, 'seizure*'));
    
    for j = 1:length(seizure_dirs)
        seizure_path = fullfile(chb_path, seizure_dirs(j).name);
        
        % 获取所有 mat 文件
        mat_files = dir(fullfile(seizure_path, '*.mat'));
        
        for k = 1:length(mat_files)
            mat_path = fullfile(seizure_path, mat_files(k).name);
            
            % 加载 mat 文件
            S = load(mat_path, 'data');
            
            % 检查通道数
            [channels, ~] = size(S.data);
            
            if channels > 18
                % 截取前18个通道
                S.data = S.data(1:18, :);
                
                % 覆盖保存原文件
                save(mat_path, '-struct', 'S');
                fprintf('已处理并覆盖: %s\n', mat_path);
            else
                fprintf('无需处理: %s\n', mat_path);
            end
        end
    end
end

disp('所有文件检查并处理完成！');
