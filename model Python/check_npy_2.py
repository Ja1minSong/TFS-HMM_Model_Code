import os
from pathlib import Path

# 根目录
root = Path(r'file path')

# 统计删除数量
deleted = 0
missing = 0

# 遍历 chb* 文件夹
for chb_dir in root.glob('chb*'):
    if not chb_dir.is_dir():
        continue

    # 遍历 seizure* 子文件夹
    for seizure_dir in chb_dir.glob('seizure*'):
        if not seizure_dir.is_dir():
            continue

        # 遍历该文件夹下所有 .mat 文件
        mat_files = list(seizure_dir.glob('*.mat'))
        if not mat_files:
            missing += 1
            continue

        for fpath in mat_files:
            try:
                fpath.unlink()  # 删除文件
                deleted += 1
                print(f'已删除: {fpath}')
            except Exception as e:
                print(f'删除失败: {fpath} | 错误: {e}')

print(f'\n操作完成 ✔️  成功删除 {deleted} 个文件，未找到 {missing} 个文件夹下的 mat 文件。')

