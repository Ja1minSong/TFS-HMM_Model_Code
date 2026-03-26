clc; clear;

%% 参数设置
test_file  = 'file path\ablation2.xlsx';

%% === 读取测试数据 ===
test_data = readtable(test_file);
true_test = test_data.label(:);
obs_test  = test_data.result(:);
seq_len   = length(obs_test);

%% === 超参数 ===
N_on  = 15;  % 切换到新类的连续帧数
N_off = 15;  % 切换回旧类的连续帧数

%% === 初始化 ===
corrected_labels = obs_test;  % 初始化为原预测结果
state = obs_test(1);          % 当前状态（0 或 1）
corrected_labels(1:N_on) = obs_test(1:N_on);  % 开头不做修正

%% === 双阈值滞后逻辑 ===
for i = N_on+1 : seq_len - N_on
    % 当前及之后的 N_on 帧
    window_next = obs_test(i : i + N_on - 1);

    % 如果当前状态是 0，且未来连续 N_on 帧为 1，则切换到 1
    if state == 0 && all(window_next == 1)
        state = 1;
        corrected_labels(i:end) = 1;
    % 如果当前状态是 1，且未来连续 N_off 帧为 0，则切换回 0
    elseif state == 1 && all(window_next == 0)
        state = 0;
        corrected_labels(i:end) = 0;
    else
        corrected_labels(i) = state;
    end
end

%% === 结果写入文件 ===
test_data.ablation2 = corrected_labels;
writetable(test_data, test_file);

%% === 计算修正后准确率 ===
accuracy = sum(corrected_labels == true_test) / seq_len;
fprintf('双阈值/滞后切换规则修正后的准确率: %.2f%%\n', accuracy * 100);

