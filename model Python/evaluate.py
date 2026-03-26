# evaluate_model.py

import torch
import numpy as np
import pandas as pd
import os
from torch.utils.data import DataLoader, TensorDataset
from sklearn.metrics import accuracy_score, confusion_matrix
import seaborn as sns
import matplotlib.pyplot as plt

# 导入你封装好的模型结构
# 确保 model.py 文件和此脚本在同一个目录下
try:
    from model import EEGNet
except ImportError:
    print("错误：无法找到 model.py 文件。")
    print("请确保包含 EEGNet 模型定义的 model.py 文件与此脚本位于同一目录中。")
    exit()

def evaluate_single_seizure():
    """
    加载一个预训练模型，并在指定的一次发作数据上进行评估。
    """
    # --- 1. 定义文件和模型路径 ---
    base_dir = r'file path'
    
    # 预训练模型的路径
    model_path = os.path.join(base_dir, 'seizure1', 'saved_model.pth')
    
    # 需要测试的数据所在的文件夹路径
    test_data_dir = os.path.join(base_dir, 'seizure1')

    print(f"模型路径: {model_path}")
    print(f"测试数据路径: {test_data_dir}")

    # 检查模型文件是否存在
    if not os.path.exists(model_path):
        print(f"错误：模型文件未找到！路径: {model_path}")
        return

    # --- 2. 加载测试数据和标签 ---
    try:
        test_x_path = os.path.join(test_data_dir, 'test.npy')
        test_stft_path = os.path.join(test_data_dir, 'test_stft.npy')
        test_y_path = os.path.join(test_data_dir, 'result.xlsx')

        test_x = np.load(test_x_path)
        test_stft = np.load(test_stft_path)
        labels_df = pd.read_excel(test_y_path)
        test_y = labels_df['label'].values
        
        print(f"成功加载数据: {len(test_x)} 个样本。")

    except FileNotFoundError as e:
        print(f"错误：数据文件未找到！ {e}")
        return
    except Exception as e:
        print(f"加载数据时发生错误: {e}")
        return

    # --- 3. 准备PyTorch数据集和DataLoader ---
    # 将numpy数组转换为torch张量
    test_x_tensor = torch.tensor(test_x, dtype=torch.float32)
    test_stft_tensor = torch.tensor(test_stft, dtype=torch.float32)
    test_y_tensor = torch.tensor(test_y, dtype=torch.long)

    # 创建数据集和数据加载器
    test_dataset = TensorDataset(test_x_tensor, test_stft_tensor, test_y_tensor)
    test_loader = DataLoader(test_dataset, batch_size=16) # batch_size可以根据你的GPU显存调整

    # --- 4. 初始化模型并加载权重 ---
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"使用的设备: {device}")

    # 实例化模型结构
    model = EEGNet().to(device)
    
    # 加载预训练的权重
    # map_location=device 确保了即使模型是在GPU上训练的，也能在CPU上加载
    model.load_state_dict(torch.load(model_path, map_location=device))
    
    # 切换到评估模式，这对于BatchNorm和Dropout层非常重要
    model.eval()
    print("模型权重加载成功，并已设置为评估模式。")

    # --- 5. 执行预测 ---
    all_preds = []
    all_labels = []

    # 使用 torch.no_grad() 来关闭梯度计算，可以节省内存并加速
    with torch.no_grad():
        for raw, stft_data, labels in test_loader:
            # 将数据移动到指定设备
            raw = raw.to(device)
            stft_data = stft_data.to(device)
            
            # 模型前向传播
            outputs = model(raw, stft_data)
            
            # 获取预测结果（概率最高的类别）
            _, predicted = torch.max(outputs, 1)
            
            # 收集预测和真实标签
            all_preds.extend(predicted.cpu().numpy())
            all_labels.extend(labels.numpy())

    # --- 6. 计算并显示结果 ---
    accuracy = accuracy_score(all_labels, all_preds)
    cm = confusion_matrix(all_labels, all_preds)

    print("\n========== 评估结果 ==========")
    print(f"在 seizure1 数据集上的准确率: {accuracy * 100:.2f}%")
    print("\n混淆矩阵:")
    print(cm)
    print("==============================\n")
    
    # --- 7. 可视化混淆矩阵 ---
    try:
        plt.figure(figsize=(8, 6))
        sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', xticklabels=['类别 0', '类别 1'], yticklabels=['类别 0', '类别 1'])
        plt.xlabel('预测标签 (Predicted Label)')
        plt.ylabel('真实标签 (True Label)')
        plt.title('Confusion Matrix for Seizure 4 Test Data')
        plt.show()
    except Exception as e:
        print(f"无法绘制混淆矩阵: {e}")


if __name__ == '__main__':
    evaluate_single_seizure()