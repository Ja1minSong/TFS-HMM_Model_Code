clc; clear;

%% 参数设置（请按需修改路径）
test_file  = 'file path\ablation1.xlsx';

%% === 读取测试数据 ===
test_data = readtable(test_file);
true_test = test_data.label(:);
obs_test  = test_data.result(:);
seq_len   = length(obs_test);

%% === 配置参数 ===
W = 15;  % 窗口长度
S = 10;   % 步长（控制重叠程度）

%% === 初始化 ===
votes = zeros(seq_len, 2);  % 记录每个点被投为0或1的次数

%% === 滑动窗口投票 ===
for start_idx = 1:S:(seq_len - W + 1)
    end_idx = start_idx + W - 1;
    window = obs_test(start_idx:end_idx);

    % 计算窗口内的众数
    num_ones = sum(window == 1);
    num_zeros = sum(window == 0);
    if num_ones > num_zeros
        majority_label = 1;
    elseif num_zeros > num_ones
        majority_label = 0;
    else
        majority_label = window(round(W/2)); % 平局取中间值
    end

    % 给该窗口内的每个位置增加投票
    if majority_label == 1
        votes(start_idx:end_idx, 2) = votes(start_idx:end_idx, 2) + 1;
    else
        votes(start_idx:end_idx, 1) = votes(start_idx:end_idx, 1) + 1;
    end
end

%% === 决定最终类别 ===
[~, max_idx] = max(votes, [], 2);
corrected_labels = max_idx - 1;  % 1→0, 2→1

%% === 保存修正结果（列名 ablation1_correct） ===
test_data.ablation1 = corrected_labels;
writetable(test_data, test_file);

%% === 计算修正后准确率 ===
accuracy = sum(corrected_labels == true_test) / seq_len;
fprintf('带重叠多数投票（融合）修正后的准确率: %.2f%%\n', accuracy * 100);
