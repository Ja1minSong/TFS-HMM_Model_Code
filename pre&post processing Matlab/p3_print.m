%% === 读取 Excel 表格 ===
data = readtable('file path\test_result.xlsx');

% 提取时间、标签、预测结果、修正结果
time_intervals = data.time; 
labels     = data.label;
results    = data.result;
HMM  = data.HMM;
types      = data.type;  % interictal / preictal / ictal / postictal
hmm_smooth = data.("HMM_smooth");  % 新增的 HMM-smooth 列

num_segments = height(data);
start_times = zeros(num_segments,1);
end_times   = zeros(num_segments,1);

% === 解析时间区间 ===
for i = 1:num_segments
    parts = split(time_intervals{i}, '-');
    start_times(i) = str2double(parts{1});
    end_times(i)   = str2double(parts{2});
end

%% === 把时间轴0点对齐到 ictal 开始 ===
ictal_mask = strcmp(types,'ictal');
if any(ictal_mask)
    t0 = min(start_times(ictal_mask));  % ictal开始时间
else
    t0 = min(start_times);              % 没有ictal就不平移
end
start_times = start_times - t0;
end_times   = end_times - t0;

%% === 颜色映射：0 -> 绿色, 1 -> 黄色 ===
cmap = [0 1 0; 1 1 0];  % [R G B]

figure;
hold on;

%% === 绘制 Label 行 (y=4) ===
for i = 1:num_segments
    color = cmap(labels(i)+1,:);
    fill([start_times(i) end_times(i) end_times(i) start_times(i)], ...
         [3.75 3.75 4.25 4.25], color, 'EdgeColor','none');
end

%% === 绘制 Result 行 (y=3) ===
for i = 1:num_segments
    color = cmap(results(i)+1,:);
    fill([start_times(i) end_times(i) end_times(i) start_times(i)], ...
         [2.75 2.75 3.25 3.25], color, 'EdgeColor','none');
end

%% === 绘制 Corrected 行 (y=2) ===
for i = 1:num_segments
    color = cmap(HMM(i)+1,:);
    fill([start_times(i) end_times(i) end_times(i) start_times(i)], ...
         [1.75 1.75 2.25 2.25], color, 'EdgeColor','none');
end

%% === 绘制 HMM-smooth 行 (y=1) ===
for i = 1:num_segments
    color = cmap(hmm_smooth(i)+1,:);
    fill([start_times(i) end_times(i) end_times(i) start_times(i)], ...
         [0.75 0.75 1.25 1.25], color, 'EdgeColor','none');
end

%% === 寻找连续15个1并画箭头 ===
smooth_vals = hmm_smooth(:)';   % 行向量
arrow_times = [];

count = 0;
for i = 1:length(smooth_vals)
    if smooth_vals(i) == 1
        count = count + 1;
    else
        count = 0;
    end
    if count == 15
        % 箭头位置：当前段中点
        seg_mid = (start_times(i) + end_times(i))/2;
        arrow_times = [arrow_times seg_mid]; %#ok<AGROW>
    end
end

% 按时间排序
arrow_times = sort(arrow_times);

% 按顺序筛选箭头，保证间距 >= 900 秒
if ~isempty(arrow_times)
    keep_arrow = arrow_times(1);  % 保留第一个
    last_time = arrow_times(1);
    
    for i = 2:length(arrow_times)
        if arrow_times(i) - last_time >= 900
            keep_arrow = [keep_arrow, arrow_times(i)]; %#ok<AGROW>
            last_time = arrow_times(i);
        end
    end
    
    arrow_times = keep_arrow;
end


%% === 坐标轴设置（提前定义x/y范围）===
xrange = [min(start_times) max(end_times)];
yrange = [0.5 4.5];
ylim(yrange);
yticks([1 2 3 4]);
yticklabels({'HMM-smooth','HMM','Result','Label'});
xlabel('Time (s)');

%% === 计算准确率 ===
accuracy_result    = mean(labels == results) * 100;
accuracy_corrected = mean(labels == HMM) * 100;
accuracy_HMM_smooth = mean(labels == hmm_smooth) * 100;   % HMM_smooth行
title_text = sprintf('(Accuracy Result = %.2f%%, Accuracy HMM = %.2f%%, Accuracy HMM-smooth = %.2f%%)', ...
    accuracy_result, accuracy_corrected, accuracy_HMM_smooth);
title(title_text, 'FontSize', 12, 'FontWeight', 'bold');

box on;

%% === 在上方标注每种类型的范围 ===
unique_types = unique(types, 'stable'); % 按出现顺序保持顺序
for t = 1:length(unique_types)
    mask = strcmp(types, unique_types{t});
    if any(mask)
        seg_start = min(start_times(mask));
        seg_end   = max(end_times(mask));
        mid_time  = (seg_start + seg_end) / 2;
        text(mid_time, 4.4, unique_types{t}, 'HorizontalAlignment','center', ...
             'FontSize',9, 'FontWeight','bold');
    end
end

%% === X轴范围完整 ===
xlim(xrange);

%% === 压缩纵横比 & 窗口大小 ===
pbaspect([5 1 1]);
set(gcf,'Position',[100 100 1400 300]);  % 横向宽，高度稍大

%% === 用 annotation('arrow') 画箭头（底部从Label行底部开始）===
ax = gca;
y_base = 0.9;  % Label 行底部
y_top  = 1.625;  % HMM-smooth 行上方（你可以自己调整）

for k = 1:length(arrow_times)
    x = arrow_times(k);
    
    % 将数据坐标转换为 figure 归一化坐标
    [x_norm, y_norm] = ds2nfu(ax,[x x],[y_base y_top]); 
    
    % 画箭头
    annotation('arrow', x_norm, y_norm, ...
        'Color','r','LineWidth',2.5,'HeadLength',10,'HeadWidth',10);
end


hold off;

%% === 输出每个箭头的时间（秒 + 提前分钟秒）===
fprintf('\n=== 箭头时间点列表 ===\n');
for k = 1:length(arrow_times)
    t = arrow_times(k);   % 当前箭头时间（s）
    % 计算提前多久（绝对值，转分钟秒）
    minutes = floor(abs(t)/60);
    seconds = mod(abs(t),60);
    if t < 0
        % ictal开始前
        fprintf('箭头%d: %.0fs (提前%d分钟%.0f秒)\n', ...
            k, t, minutes, seconds);
    else
        % ictal开始后
        fprintf('箭头%d: %.0fs (延后%d分钟%.0f秒)\n', ...
            k, t, minutes, seconds);
    end
end


%% === 辅助函数：数据坐标转 figure 坐标 ===
function [x_norm,y_norm] = ds2nfu(ax,x,y)
    % 获取坐标轴位置
    axun = ax.Units;
    ax.Units = 'normalized';
    axpos = ax.Position;
    ax.Units = axun;
    % 获取坐标轴范围
    ax_xlim = ax.XLim;
    ax_ylim = ax.YLim;
    % 转换
    x_norm = axpos(1) + (x - ax_xlim(1)) / (ax_xlim(2)-ax_xlim(1)) * axpos(3);
    y_norm = axpos(2) + (y - ax_ylim(1)) / (ax_ylim(2)-ax_ylim(1)) * axpos(4);
end

