import os
import numpy as np

# 设置根目录
root_dir = r'file path'

# 遍历所有 .npy 文件并打印 shape
for chb_folder in os.listdir(root_dir):
    chb_path = os.path.join(root_dir, chb_folder)
    if not os.path.isdir(chb_path):
        continue

    for seizure_folder in os.listdir(chb_path):
        seizure_path = os.path.join(chb_path, seizure_folder)
        if not os.path.isdir(seizure_path):
            continue

        for file_name in os.listdir(seizure_path):
            if file_name.endswith('.npy'):
                file_path = os.path.join(seizure_path, file_name)
                try:
                    data = np.load(file_path, allow_pickle=True)
                    print(f"{file_path} => shape: {data.shape}")
                except Exception as e:
                    print(f"读取失败：{file_path}，错误：{e}")

