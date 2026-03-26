clc; clear;

%% 参数设置
test_file  = 'file path\test_result.xlsx';
train_file = 'file path\train_result.xlsx';

%% === 读取训练数据 ===
train_data   = readtable(train_file);
train_labels = train_data.label;     % 真实标签（隐藏状态）
train_result = train_data.result;    % 模型预测结果（观测值）

classes = unique(train_labels);
num_classes = length(classes);

%% === 1️⃣ 估计状态转移矩阵 T ===
T = zeros(num_classes);
for i = 1:length(train_labels)-1
    from = train_labels(i);
    to   = train_labels(i+1);
    T(from+1, to+1) = T(from+1, to+1) + 1;
end

alpha_T = 1 / length(train_labels);   % 自适应平滑系数
T = T + alpha_T;                      % Laplace 平滑
T = T ./ sum(T,2);

%% === 2️⃣ 估计观测概率矩阵 E ===
% E(i,j) = P(观测=j | 状态=i)
E = zeros(num_classes);
for i = 1:num_classes
    idx = find(train_labels == (i-1));  % 找出真实为 i-1 的样本
    if isempty(idx)
        continue;
    end
    preds = train_result(idx);
    for j = 1:num_classes
        E(i,j) = sum(preds == (j-1));
    end
end

alpha_E = 1 / length(train_result);  % 自适应平滑
E = E + alpha_E;                     % 平滑
E = E ./ sum(E,2);                   % 归一化为概率

%% === 3️⃣ 初始概率 π₀ ===
first_labels = train_labels(1:min(10, end));   % 可取前10个窗口估计初始分布
pi0 = histcounts(first_labels, -0.5:num_classes-0.5);
pi0 = pi0 + 1/num_classes;                     % 防止为0
pi0 = pi0 / sum(pi0);

%% === 读取测试集 ===
test_data = readtable(test_file);
true_test = test_data.label;
obs_test  = test_data.result;
seq_len   = length(obs_test);

%% === 4️⃣ Viterbi 解码 ===
delta = zeros(seq_len, num_classes);
psi   = zeros(seq_len, num_classes);

% 初始化
obs1 = obs_test(1)+1;
delta(1,:) = log(pi0) + log(E(:,obs1))';
psi(1,:) = 0;

% 递推
for t = 2:seq_len
    obs = obs_test(t)+1;
    for j = 1:num_classes
        [delta(t,j), psi(t,j)] = max(delta(t-1,:) + log(T(:,j)'));
        delta(t,j) = delta(t,j) + log(E(j,obs));
    end
end

% 回溯
[~, qT] = max(delta(end,:));
corrected_labels = zeros(seq_len,1);
corrected_labels(end) = qT - 1;

for t = seq_len-1:-1:1
    corrected_labels(t) = psi(t+1, corrected_labels(t+1)+1) - 1;
end

%% === 保存修正结果 ===
test_data.result_corrected = corrected_labels;
writetable(test_data, test_file);

%% === 计算修正后准确率 ===
accuracy = sum(corrected_labels == true_test) / seq_len;
fprintf('修正后的准确率: %.2f%%\n', accuracy*100);

%% === 打印模型统计信息 ===
disp('--- HMM 参数统计 ---');
disp('状态转移矩阵 T:');
disp(T);
disp('观测概率矩阵 E:');
disp(E);
disp('初始概率 pi0:');
disp(pi0);
