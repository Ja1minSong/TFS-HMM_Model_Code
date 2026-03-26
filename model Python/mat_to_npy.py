import os
import numpy as np
import scipy.io as sio
import h5py

def load_mat_file(filepath):
    """自动识别v7.3 mat文件并读取'data'变量"""
    try:
        # 普通v7或更早版本
        mat = sio.loadmat(filepath)
        if 'data' in mat:
            return mat['data']
    except NotImplementedError:
        pass  # 是v7.3格式

    try:
        # v7.3格式，使用h5py读取
        with h5py.File(filepath, 'r') as f:
            if 'data' not in f:
                print(f"警告：{filepath} 中未找到变量 'data'")
                return None
            data = f['data']
            # 转换为numpy数组，注意HDF中存储是 Fortran-order
            return np.array(data).transpose()
    except Exception as e:
        print(f"HDF5读取失败：{filepath}\n错误：{e}")
        return None

# 设置根目录
root_dir = r'file_path'

# 遍历每个chb文件夹
for chb_folder in os.listdir(root_dir):
    chb_path = os.path.join(root_dir, chb_folder)
    if not os.path.isdir(chb_path):
        continue

    # 遍历seizure子文件夹
    for seizure_folder in os.listdir(chb_path):
        seizure_path = os.path.join(chb_path, seizure_folder)
        if not os.path.isdir(seizure_path):
            continue

        # 查找需要转换的mat文件
        for file_name in os.listdir(seizure_path):
            if file_name.endswith('.mat'):  # 处理所有mat文件
                file_path = os.path.join(seizure_path, file_name)

                data = load_mat_file(file_path)
                if data is None:
                    continue

                # 构造npy保存路径
                npy_name = file_name.replace('.mat', '.npy')
                npy_path = os.path.join(seizure_path, npy_name)

                try:
                    np.save(npy_path, data)
                    print(f"保存成功: {npy_path}")
                except Exception as e:
                    print(f"保存失败：{npy_path}\n错误信息：{e}")


