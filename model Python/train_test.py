# LOOCV: For each patient, the current seizure data is used for testing and the remaining multiple seizure data is used for training (5-fold cross-validation).
import torch
from torch import nn
import numpy as np
import pandas as pd
import os
from torch.utils.data import DataLoader, TensorDataset, Subset
from sklearn.metrics import accuracy_score, confusion_matrix
import seaborn as sns
import matplotlib.pyplot as plt
from sklearn.model_selection import KFold
from sklearn.model_selection import StratifiedKFold

# 确保 model.py 文件和此脚本在同一个目录下
try:
    from model import EEGNet
except ImportError:
    print("错误：无法找到 model.py 文件。")
    print("请确保包含 EEGNet 模型定义的 model.py 文件与此脚本位于同一目录中。")
    exit()

def load_seizure_data(base_dir, seizure_ids):
    """
    从指定目录加载若干次发作的数据（用于训练或测试）。

    参数：
        base_dir: 目录路径，例如 'file path'
        seizure_ids: seizure 编号列表，例如 [2, 3]
    返回：
        (pre_x, pre_stft, inter_x, inter_stft)
    """
    pre_x, pre_stft, inter_x, inter_stft = [], [], [], []
    for sid in seizure_ids:
        seizure_path = os.path.join(base_dir, f"seizure{sid}")
        try:
            pre_x.append(np.load(os.path.join(seizure_path, "preictal_slice.npy")))
            pre_stft.append(np.load(os.path.join(seizure_path, "preictal_stft.npy")))
            inter_x.append(np.load(os.path.join(seizure_path, "interictal_slice.npy")))
            inter_stft.append(np.load(os.path.join(seizure_path, "interictal_stft.npy")))
        except FileNotFoundError as e:
            print(f"⚠️ 文件缺失: {e}")
    return (
        np.concatenate(pre_x, axis=0),
        np.concatenate(pre_stft, axis=0),
        np.concatenate(inter_x, axis=0),
        np.concatenate(inter_stft, axis=0),
    )

# ===== 数据加载函数 (已修改) =====
def load_seizure_data(base_dir, seizure_ids):
    """
    从指定目录加载若干次发作的数据。
    现在每个seizure文件夹包含 test.npy, test_stft.npy, 和 result.xlsx。

    参数：
        base_dir: 目录路径，例如 'file path'
        seizure_ids: seizure 编号列表，例如 [2, 3]
    返回：
        (all_x, all_stft, all_y)
            all_x: 原始信号数据 (numpy array)
            all_stft: STFT 数据 (numpy array)
            all_y: 标签数据 (numpy array)
    """
    all_x, all_stft, all_y = [], [], []
    for sid in seizure_ids:
        seizure_path = os.path.join(base_dir, f"seizure{sid}")
        try:
            # 加载数据和 STFT
            x = np.load(os.path.join(seizure_path, "test.npy"))
            stft = np.load(os.path.join(seizure_path, "test_stft.npy"))

            # 从 result.xlsx 加载标签
            labels_df = pd.read_excel(os.path.join(seizure_path, "result.xlsx"))
            y = labels_df['label'].values

            # 检查数据和标签的数量是否匹配
            if len(x) != len(y):
                print(f"⚠️ 警告: 在 seizure{sid} 中, 数据样本数 ({len(x)}) 与标签数 ({len(y)}) 不匹配。跳过此次发作。")
                continue
            
            all_x.append(x)
            all_stft.append(stft)
            all_y.append(y)
            
        except FileNotFoundError as e:
            print(f"⚠️ 文件缺失: {e}。跳过 seizure {sid}。")
        except Exception as e:
            print(f"加载 seizure {sid} 时发生错误: {e}")

    # 如果没有加载到任何数据，返回空数组
    if not all_x:
        return (np.array([]), np.array([]), np.array([]))

    # 将所有加载的数据连接成一个大的 numpy 数组
    return (
        np.concatenate(all_x, axis=0),
        np.concatenate(all_stft, axis=0),
        np.concatenate(all_y, axis=0),
    )

# ===== 训练与评估 (5折交叉验证 + 固定测试集) (已修改) =====
def train_and_evaluate():
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    
    # --- 1. 定义数据路径和ID ---
    try:
        train_dir = "train file path"
        train_ids = [2,3,...]
        test_dir = "test file path"
        test_ids = [1]

        train_x, train_stft, train_y = load_seizure_data(train_dir, train_ids)
        test_x, test_stft, test_y = load_seizure_data(test_dir, test_ids)
        
        if train_x.size == 0 or test_x.size == 0:
            print("❌ 错误: 未能加载训练或测试数据，程序终止。")
            return

    except FileNotFoundError as e:
        print(f"❌ 错误: 数据文件未找到。请确保所有.npy和.xlsx文件都在正确的路径下。 {e}")
        return

    # --- 2. 创建用于交叉验证的数据集 (cv_dataset) ---
    cv_dataset = TensorDataset(
        torch.tensor(train_x, dtype=torch.float32),
        torch.tensor(train_stft, dtype=torch.float32),
        torch.tensor(train_y, dtype=torch.long)
    )

    # --- 3. 创建固定的留出测试集 (test_dataset) ---
    test_dataset = TensorDataset(
        torch.tensor(test_x, dtype=torch.float32),
        torch.tensor(test_stft, dtype=torch.float32),
        torch.tensor(test_y, dtype=torch.long)
    )
    
    test_loader = DataLoader(test_dataset, batch_size=16)
    print(f"Data loaded: {len(cv_dataset)} samples for 10-fold CV, {len(test_dataset)} samples for fixed testing.")

    # --- 4. 计算类别权重 ---
    class_counts = np.bincount(train_y)
    total_samples = len(train_y)
    class_weights = total_samples / (2 * class_counts)
    class_weights_tensor = torch.tensor(class_weights, dtype=torch.float32).to(device)
    
    print(f"类别样本数: {class_counts}")
    print(f"计算出的类别权重: {class_weights_tensor}")

    # --- 5. 交叉验证设置 ---
    k_folds = 5
    patience = 5  # 早停容忍度
    kfold = StratifiedKFold(n_splits=k_folds, shuffle=True, random_state=18)
    num_epochs = 30 
    
    best_overall_val_loss = float('inf')
    # 模型保存路径
    save_path = os.path.join(test_dir, f'seizure{test_ids[0]}')
    if not os.path.exists(save_path): os.makedirs(save_path)
    best_model_file = os.path.join(save_path, 'best_model.pth')

    # --- 6. 交叉验证循环 ---
    for fold, (train_idx, val_idx) in enumerate(kfold.split(train_x, train_y)):
        print(f'\n{"="*20} 第 {fold+1}/{k_folds} 折 {"="*20}')
        
        train_sub = Subset(cv_dataset, train_idx)
        val_sub = Subset(cv_dataset, val_idx)
        
        train_loader = DataLoader(train_sub, batch_size=16, shuffle=True)
        val_loader = DataLoader(val_sub, batch_size=16)

        model = EEGNet().to(device)
        optimizer = torch.optim.Adam(model.parameters(), lr=1e-4)
        criterion = nn.CrossEntropyLoss(weight=class_weights_tensor)

        # 针对本折的早停变量
        min_val_loss = float('inf')
        epochs_no_improve = 0

        for epoch in range(num_epochs):
            # 训练阶段
            model.train()
            total_train_loss = 0
            for r, s, l in train_loader:
                r, s, l = r.to(device), s.to(device), l.to(device)
                optimizer.zero_grad()
                outputs = model(r, s)
                loss = criterion(outputs, l)
                loss.backward()
                optimizer.step()
                total_train_loss += loss.item() * r.size(0)
            avg_train_loss = total_train_loss / len(train_sub)

            # 验证阶段
            model.eval()
            total_val_loss = 0
            correct = 0
            with torch.no_grad():
                for r, s, l in val_loader:
                    r, s, l = r.to(device), s.to(device), l.to(device)
                    outputs = model(r, s)
                    loss = criterion(outputs, l)
                    total_val_loss += loss.item() * r.size(0)
                    _, pred = torch.max(outputs, 1)
                    correct += (pred == l).sum().item()
            
            avg_val_loss = total_val_loss / len(val_sub)
            val_acc = correct / len(val_sub)

            print(f"Epoch {epoch+1:02d}: Train Loss {avg_train_loss:.4f} | Val Loss {avg_val_loss:.4f} | Val Acc {val_acc:.2%}")

            # --- 早停判定逻辑 ---
            if avg_val_loss < min_val_loss:
                min_val_loss = avg_val_loss
                epochs_no_improve = 0
                # 如果这是所有折中表现最好的(基于验证集loss)，则保存
                if avg_val_loss < best_overall_val_loss:
                    best_overall_val_loss = avg_val_loss
                    torch.save(model.state_dict(), best_model_file)
                    print(f"  >> 发现全局最优模型 (Val Loss: {avg_val_loss:.4f})，已保存。")
            else:
                epochs_no_improve += 1
                if epochs_no_improve >= patience:
                    print(f"  >> 🚩 验证集损失连续 {patience} 轮未下降，触发早停。")
                    break

    # --- 7. 最终评估 ---
    print(f'\n{"="*20} 交叉验证结束，评估最优模型 {"="*20}')
    if os.path.exists(best_model_file):
        model.load_state_dict(torch.load(best_model_file))
        model.eval()
        
        all_preds, all_labels = [], []
        with torch.no_grad():
            for r, s, l in test_loader:
                r, s, l = r.to(device), s.to(device), l.to(device)
                outputs = model(r, s)
                _, pred = torch.max(outputs, 1)
                all_preds.extend(pred.cpu().numpy())
                all_labels.extend(l.cpu().numpy())

        acc = accuracy_score(all_labels, all_preds)
        print(f"测试集最终准确率: {acc:.2%}")
        
        # 混淆矩阵
        cm = confusion_matrix(all_labels, all_preds)
        plt.figure(figsize=(6, 5))
        sns.heatmap(cm, annot=True, fmt='d', cmap='Blues')
        plt.title('Final Confusion Matrix')
        plt.ylabel('True')
        plt.xlabel('Predicted')
        plt.show()
    else:
        print("未发现已保存的模型文件。")

if __name__ == '__main__':
    train_and_evaluate()