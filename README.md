# Xiaomi-13-Series_AutoBuild_HyperOS_Public

Xiaomi 13 系列机型 HyperOS 移植包自动构建脚本。

## 原作者

本项目基于原作者项目修改而来，感谢原作者的贡献：

- 原始项目：[imHawthorne/Build_local_HyperOS](https://github.com/imHawthorne/Build_local_HyperOS)

## 支持机型

| 机型 | 机型代号 |
| --- | --- |
| 小米 13 | `fuxi` |
| 小米 13 Pro | `nuwa` |
| 小米 13 Ultra | `ishtar` |

## 使用方法

1. 安装依赖并配置工具权限（Debian / Ubuntu）：

   ```bash
   bash setup.sh
   ```

2. 下载固件包（底包 Stock + 移植包 Migration），放入 `downloads/` 目录：

   ```bash
   bash rom_download.sh
   ```

3. 执行构建：

   ```bash
   # 多机型批量构建（交互式多选机型）
   bash build_all.sh            # 全程交互：底包(多选) → 移植包 → 打包模式
   bash build_all.sh 1          # 跳过交互，直接指定打包模式（1=常规 2=DSU 3=都要）

   # 或单机型交互式构建
   bash Build_local_HyperOS.sh
   ```

4. 构建产物输出至 `zip/` 目录。

## 固件包摆放

固件包放在 `downloads/` 根目录或其子目录均可，按文件名自动扫描分类：

- **底包 Stock**：文件名含机型代号（`ishtar` / `nuwa` / `fuxi`）
- **移植包 Migration**：文件名不含机型代号的 zip

## 目录结构

```
├── Build_local_HyperOS.sh   # 单机型主构建脚本
├── build_all.sh             # 多机型批量构建
├── rom_download.sh          # 固件包多线程下载
├── setup.sh                 # 依赖安装与工具权限配置
├── common_files/            # 公共资源文件
├── mods/                    # 独立功能模块（马达修复、内核替换等）
├── tools/                   # 二进制工具 / APKEditor / 刷机脚本 / Recovery
└── downloads/               # 固件包（运行时自建）
```
