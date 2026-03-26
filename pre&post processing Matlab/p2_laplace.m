%% === 参数设置 ===
rootDir = 'file path';  % 根目录
maxZeroLen = 45;                      

%% === 查找所有result.xlsx ===
files = dir(fullfile(rootDir, '**', 'test_result.xlsx')); 
% '**' 可以递归搜索子文件夹（R2016b及以上版本）

fprintf('共找到 %d 个 result.xlsx 文件\n', numel(files));

%% === 循环处理每个result.xlsx ===
for i = 1:numel(files)
    filePath = fullfile(files(i).folder, files(i).name);
    fprintf('正在处理：%s\n', filePath);

    % === 读取表格 ===
    T = readtable(filePath);

    % 检查HMM列是否存在
    if ~ismember('HMM', T.Properties.VariableNames)
        warning('文件 %s 中没有HMM列，跳过。\n', filePath);
        continue;
    end

    hmm = double(T.HMM(:));

    % === 短段平滑 ===
    inv = ~hmm;                              
    d = diff([0; inv; 0]);                    
    starts = find(d == 1);                    
    ends   = find(d == -1) - 1;               

    hmm_smooth = hmm;                         
    for k = 1:length(starts)
        len = ends(k) - starts(k) + 1;        
        if len <= maxZeroLen
            hmm_smooth(starts(k):ends(k)) = 1;
        end
    end

    % === 添加新列并写回 ===
    T.("HMM-smooth") = hmm_smooth;  

    % 如果已经存在同名列可以覆盖，也可以先删除再添加：
    % if ismember('HMM-smooth', T.Properties.VariableNames)
    %     T.("HMM-smooth") = [];
    % end
    % T.("HMM-smooth") = hmm_smooth;

    writetable(T, filePath);  % 覆盖保存

    fprintf('已处理并保存：%s\n', filePath);
end

fprintf('所有文件处理完成！\n');
