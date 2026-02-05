# Implementation Plan: Linux Build and Packaging

## Overview

本实现计划将设计文档转化为可执行的编码任务，按顺序执行清理、编译、打包步骤。每个任务都是独立的脚本或配置文件，最终整合为一键式构建脚本。

## Tasks

- [x] 1. 创建清理脚本
  - [x] 1.1 创建 clean_windows_build.sh 脚本
    - 删除所有 .o, .lo, .la 目标文件
    - 删除所有 .exe, .dll Windows 文件
    - 删除 config.status, config.log, config.h 配置缓存
    - 清理 .libs/, .deps/ 目录
    - 删除 *.gch 预编译头文件
    - 保留源代码和构建脚本
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

- [x] 2. 创建依赖检查脚本
  - [x] 2.1 创建 check_dependencies.sh 脚本
    - 检查 libfilezilla >= 0.51.1
    - 检查 wxWidgets >= 3.2.1
    - 检查 nettle >= 3.1
    - 检查 sqlite3 >= 3.7
    - 检查 libdbus
    - 检查 GTK3 开发库
    - 提供缺失依赖的安装指令
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_

- [x] 3. 执行 Linux 编译
  - [x] 3.1 运行清理脚本清除 Windows 构建产物
    - 执行 clean_windows_build.sh
    - 验证清理结果
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_
  - [x] 3.2 运行依赖检查并安装缺失依赖
    - 执行 check_dependencies.sh
    - 根据提示安装缺失依赖
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_
  - [x] 3.3 配置和编译项目
    - 运行 autoreconf -i (如需要)
    - 运行 ./configure
    - 运行 make -j$(nproc)
    - 验证生成的可执行文件
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [x] 4. Checkpoint - 确保编译成功
  - 验证 tabftp, fzsftp, fzputtygen 可执行文件存在
  - 验证私有库文件存在
  - 如有问题请咨询用户

- [x] 5. 创建依赖收集脚本
  - [x] 5.1 创建 bundle_dependencies.sh 脚本
    - 使用 ldd 分析可执行文件依赖
    - 复制所有非系统核心库
    - 复制 gdk-pixbuf 加载器
    - 复制 glib schemas
    - 复制翻译文件
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

- [x] 6. 创建 AppImage 构建脚本
  - [x] 6.1 创建 build_appimage.sh 脚本
    - 创建 AppDir 目录结构
    - 复制可执行文件和库
    - 创建 AppRun 启动脚本
    - 复制 .desktop 文件和图标
    - 配置 gdk-pixbuf 加载器缓存
    - 使用 appimagetool 生成 AppImage
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

- [x] 7. 创建 DEB 包构建脚本
  - [x] 7.1 创建 build_deb.sh 脚本
    - 创建 deb-root 目录结构
    - 创建 DEBIAN/control 文件
    - 创建 postinst 和 postrm 脚本
    - 复制程序文件到 /opt/tabftp
    - 创建 /usr/bin 符号链接
    - 创建 .desktop 文件
    - 使用 dpkg-deb 生成 .deb 包
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [x] 8. 创建 RPM 包构建脚本
  - [x] 8.1 创建 build_rpm.sh 脚本
    - 创建 RPM spec 文件
    - 设置 rpmbuild 目录结构
    - 复制程序文件
    - 使用 rpmbuild 生成 .rpm 包
    - _Requirements: 7.1, 7.2, 7.3_

- [x] 9. 创建一键式构建脚本
  - [x] 9.1 创建 build_all_packages.sh 主脚本
    - 整合所有构建步骤
    - 添加进度输出
    - 添加错误处理和中断机制
    - 生成所有包到 dist/ 目录
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [x] 10. Checkpoint - 验证所有包
  - ✅ 验证 AppImage 文件存在且可执行: dist/TabFTP-1.0.0-x86_64.AppImage (105MB)
  - ✅ 验证 DEB 包结构正确: dist/tabftp_1.0.0_amd64.deb (35MB)
  - ✅ 验证 RPM 包结构正确: dist/tabftp-1.0.0-1.x86_64.rpm (50MB)
  - RPM 使用 alien 工具从 DEB 转换生成

- [ ]* 11. 编写验证测试脚本
  - [ ]* 11.1 创建 verify_packages.sh 测试脚本
    - **Property 1: Clean Operation Preserves Source Files**
    - **Property 2: Build Output Completeness**
    - **Property 3: Dependency Collection Completeness**
    - **Property 4: AppImage Self-Containment**
    - **Property 5: DEB Package Structure Validity**
    - **Property 6: RPM Package Structure Validity**
    - **Property 7: Build Script Error Handling**
    - **Validates: Requirements 1.1-8.5**

## Notes

- 任务标记 `*` 的为可选任务，可跳过以加快 MVP 构建
- 每个任务都引用了具体的需求以便追溯
- Checkpoint 任务用于增量验证
- 属性测试验证通用正确性属性
- 单元测试验证具体示例和边界情况
