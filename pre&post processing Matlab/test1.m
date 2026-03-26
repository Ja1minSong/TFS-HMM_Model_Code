function [new_path] = test1(main_folder_path, in_periodization_path, start_subject_num, end_subject_num)
    eeglab('nogui');
    % 指定文件夹路径
    periodization_data = readtable(in_periodization_path);
    
    subfolders = dir(main_folder_path);
    subfolders = subfolders([subfolders.isdir]);  % 仅保留文件夹
    
    % 总输出文件夹路径
    total_folder = fullfile('Saved folder path', 'total');
    if ~exist(total_folder, 'dir')
        mkdir(total_folder);
    end
    
    % 循环处理每个子文件夹
    for folder_index = 1:length(subfolders)
        folder_name = subfolders(folder_index).name;
        numeric_part = regexp(folder_name, '\d+', 'match');
        %% 取chb01-chb20
        if startsWith(folder_name, 'chb') && str2double(numeric_part{1}) <= end_subject_num && str2double(numeric_part{1}) >= start_subject_num
            fprintf('Processing folder: %s\n', folder_name);
            % 构造子文件夹的完整路径
            folder_path = fullfile(main_folder_path, folder_name);
            
            % 该病人对应的输出文件夹
            patient_folder = fullfile(total_folder, folder_name);
            if ~exist(patient_folder, 'dir')
                mkdir(patient_folder);
            end
            
            % 检查子文件夹下是否有.edf文件
            file_list = dir(fullfile(folder_path, '*.edf'));
            % 循环处理每个文件
            for file_index = 1:length(file_list)
                % 构建文件的完整路径
                file_path = fullfile(folder_path, file_list(file_index).name);
            
                filename = getFileName(file_path);
                fprintf('Processing file: %s\n', file_path);
                try
                    EEG = pop_biosig(file_path);
                catch ME
                    warning('Error reading file %s: %s', file_path, ME.message);
                    continue;
                end

                if size(EEG.data, 1) < 18
                    disp(filename);
                    break;
                end
                
                if ~isempty(periodization_data(contains(periodization_data.FileName, filename), :))
                    matchingRecords = periodization_data(contains(periodization_data.FileName, filename), :);
                else
                    continue;
                end
                
                % 默认排序正确 第一段数据段的开始时间为文件开始时间
                file_start_time = matchingRecords(1,:).StartTime{1};
                array_total = [];
                
                for i = 1:height(matchingRecords)
                    if ~isempty(matchingRecords(i,:).type)
                        [start_time, end_time] = timeToIndices(EEG, file_start_time, matchingRecords(i,:).StartTime, matchingRecords(i,:).FrameNumbers);
                        array_total = [array_total; start_time, end_time];
                    end
                end
                
                new_path = patient_folder;
                new_filename = erase(filename, '.edf');
                
                % negative_indices_array 处理
                for i = 1:height(array_total)
                    start_index = array_total(i,1);
                    end_index = array_total(i,2);
                    data = EEG.data(:, start_index:end_index);
                    % 将文件名的 type 转换为字符向量
                    file_type = char(matchingRecords(i,:).type);
                    % 拼接文件名
                    filename = [new_filename, '_',num2str(i), '_', file_type, '.mat'];
                    save(fullfile(new_path, filename), 'data');
                end
            end
        end
    end
    
    % 确保输出参数被赋值
    if ~exist('new_path', 'var') || isempty(new_path)
        new_path = '';
    end
    
    function filename = getFileName(filepath)
        [~, filename, ext] = fileparts(filepath);
        filename = strrep(filename, '_reduced', '');
        filename = fullfile([filename, ext]);
    end
    
    function [startIndex, endIndex] = timeToIndices(eegObj, fileStartTime, startTime, frameNumbers)
        % 输入：
        % - eegObj: EEG对象 包含文件各信息
        % - fileStartTime: 文件的开始时间，格式 'HH:mm:ss'
        % - startTime: 需要映射的开始时间字符串，格式 'HH:mm:ss'
        % - frameNumbers: 帧数 持续时间*采样率
        
        % 将时间字符串转换为 datetime 对象
        startTimeDT = datetime(startTime, 'Format', 'HH:mm:ss');
        
        timeDifference = startTimeDT - datetime(fileStartTime, 'Format', 'HH:mm:ss');
        
        if seconds(timeDifference) < 0
            % 加上一整天的秒数
            timeDifference = timeDifference + days(1);
        end
        startTimeSeconds = seconds(timeDifference);
        % 计算在数组中对应的位置
        startIndex = round(startTimeSeconds * eegObj.srate) + 1;
        %% 终点时间表示"终点时间-1"个采样点（右侧闭区间 减1操作）
        endIndex = startIndex + frameNumbers  - 1;
        
        % 保证索引在数组范围内
        startIndex = max(1, startIndex);
        endIndex = min(eegObj.pnts, endIndex);
    end
end