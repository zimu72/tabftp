# Implementation Plan: Windows Build for TabFTP

## Overview

本实施计划将 TabFTP 从 Linux 构建环境迁移到 Windows 平台，包括清理 Linux 产物、配置依赖、编译项目和创建安装包。

## Tasks

- [x] 1. 清理 Linux 编译产物
  - [x] 1.1 创建 PowerShell 清理脚本 `clean-linux-artifacts.ps1`
  - [x] 1.2 执行清理脚本

- [x] 2. 配置 Windows 构建环境
  - [x] 2.1 检查并安装必要的构建工具 (MSYS2 MinGW64)
  - [x] 2.2 安装缺失的依赖 (sqlite3, pugixml, pkg-config)
  - [x] 2.3 修复 Makefile.am 中的 pugixml 链接问题

- [x] 3. 编译项目
  - [x] 3.1 运行 configure --disable-locales
  - [x] 3.2 修复编译错误 (Mainfrm.cpp, sftp_crypt_info_dlg.cpp)
  - [x] 3.3 执行 make -j4 编译

- [x] 4. 准备安装包内容
  - [x] 4.1 更新 data/Makefile.am 中的可执行文件名
  - [x] 4.2 收集 DLL 依赖

- [x] 5. 创建 NSIS 安装包
  - [x] 5.1 更新 install.nsi.in 中的文件名和图标引用
  - [x] 5.2 运行 makensis 创建安装包

- [x] 6. 修复问题
  - [x] 6.1 修复命令行启动时进程残留问题 (FileZilla.cpp)
  - [x] 6.2 修复控制台窗口问题 (添加 -mwindows 链接标志)

- [x] 7. 启动速度优化
  - [x] 7.1 减少 IPC 连接超时 (从 1000ms 减少到 200ms)
  - [x] 7.2 延迟加载队列数据 (使用 CallAfter 延迟 LoadQueue)

## 完成结果

✅ 安装包已生成: `data/TabFTP_setup.exe` (31 MB)

## 启动优化说明

### 已实施的优化:

1. **IPC 超时优化**: 将单实例检测的 IPC 连接超时从 1000ms 减少到 200ms，本地 IPC 通信应该非常快
2. **延迟队列加载**: 使用 `CallAfter` 将队列数据加载延迟到主窗口显示后执行，提升感知启动速度

### 启动时间分析 (使用 --debug-startup 参数):

主要耗时操作:
- 驱动器枚举 (已在后台线程)
- 队列数据库加载 (已优化为延迟加载)
- 布局缓存加载 (WrapEngine)
- wxWidgets 初始化
