# Requirements Document

## Introduction

本文档定义了在 Linux 系统上清理 Windows 构建产物、重新编译 TabFTP，并构建 deb、AppImage、rpm 包的需求。目标是确保所有依赖都被正确打包，使应用能在各种 Linux 发行版上完美运行。

## Glossary

- **TabFTP**: 基于 FileZilla 修改的 FTP 客户端软件
- **Build_System**: 负责编译和构建软件的系统组件
- **Package_Builder**: 负责创建各种 Linux 包格式的组件
- **Dependency_Bundler**: 负责收集和打包所有运行时依赖的组件
- **AppImage**: 一种便携式 Linux 应用格式，包含所有依赖
- **DEB**: Debian/Ubuntu 系统使用的软件包格式
- **RPM**: Red Hat/Fedora/CentOS 系统使用的软件包格式

## Requirements

### Requirement 1: 清理 Windows 构建产物

**User Story:** 作为开发者，我希望清理所有 Windows 构建产生的文件和配置，以便在 Linux 上进行干净的构建。

#### Acceptance Criteria

1. WHEN Build_System 执行清理操作 THEN Build_System SHALL 删除所有 .o、.lo、.la 目标文件
2. WHEN Build_System 执行清理操作 THEN Build_System SHALL 删除所有 .exe、.dll Windows 可执行文件和库
3. WHEN Build_System 执行清理操作 THEN Build_System SHALL 删除 config.status、config.log 等配置缓存文件
4. WHEN Build_System 执行清理操作 THEN Build_System SHALL 删除 .libs、.deps 目录中的构建产物
5. WHEN Build_System 执行清理操作 THEN Build_System SHALL 保留源代码文件和构建脚本

### Requirement 2: Linux 编译环境配置

**User Story:** 作为开发者，我希望正确配置 Linux 编译环境，以便成功编译 TabFTP。

#### Acceptance Criteria

1. WHEN Build_System 检查依赖 THEN Build_System SHALL 验证 libfilezilla >= 0.51.1 已安装
2. WHEN Build_System 检查依赖 THEN Build_System SHALL 验证 wxWidgets >= 3.2.1 已安装
3. WHEN Build_System 检查依赖 THEN Build_System SHALL 验证 nettle >= 3.1 已安装
4. WHEN Build_System 检查依赖 THEN Build_System SHALL 验证 sqlite3 >= 3.7 已安装
5. WHEN Build_System 检查依赖 THEN Build_System SHALL 验证 libdbus 已安装
6. WHEN Build_System 检查依赖 THEN Build_System SHALL 验证 GTK3 开发库已安装
7. IF 任何依赖缺失 THEN Build_System SHALL 提供安装指令

### Requirement 3: Linux 编译构建

**User Story:** 作为开发者，我希望在 Linux 上成功编译 TabFTP，生成可执行文件。

#### Acceptance Criteria

1. WHEN Build_System 执行 configure THEN Build_System SHALL 检测到 Linux 平台并配置相应选项
2. WHEN Build_System 执行 make THEN Build_System SHALL 编译所有源文件生成目标文件
3. WHEN Build_System 完成编译 THEN Build_System SHALL 生成 tabftp 主程序
4. WHEN Build_System 完成编译 THEN Build_System SHALL 生成 fzsftp 和 fzputtygen 辅助程序
5. WHEN Build_System 完成编译 THEN Build_System SHALL 生成所有私有库文件

### Requirement 4: 依赖收集与打包

**User Story:** 作为开发者，我希望收集所有运行时依赖，确保应用在目标系统上能独立运行。

#### Acceptance Criteria

1. WHEN Dependency_Bundler 收集依赖 THEN Dependency_Bundler SHALL 使用 ldd 分析所有可执行文件的依赖
2. WHEN Dependency_Bundler 收集依赖 THEN Dependency_Bundler SHALL 复制所有非系统核心库
3. WHEN Dependency_Bundler 收集依赖 THEN Dependency_Bundler SHALL 包含 GTK 主题和图标依赖
4. WHEN Dependency_Bundler 收集依赖 THEN Dependency_Bundler SHALL 包含 gdk-pixbuf 加载器
5. WHEN Dependency_Bundler 收集依赖 THEN Dependency_Bundler SHALL 包含 glib schemas
6. WHEN Dependency_Bundler 收集依赖 THEN Dependency_Bundler SHALL 包含所有翻译文件

### Requirement 5: AppImage 包构建

**User Story:** 作为开发者，我希望构建 AppImage 格式的包，使应用能在任何 Linux 发行版上运行。

#### Acceptance Criteria

1. WHEN Package_Builder 构建 AppImage THEN Package_Builder SHALL 创建符合 AppImage 规范的目录结构
2. WHEN Package_Builder 构建 AppImage THEN Package_Builder SHALL 包含 AppRun 启动脚本
3. WHEN Package_Builder 构建 AppImage THEN Package_Builder SHALL 包含 .desktop 文件
4. WHEN Package_Builder 构建 AppImage THEN Package_Builder SHALL 包含应用图标
5. WHEN Package_Builder 构建 AppImage THEN Package_Builder SHALL 使用 appimagetool 生成最终 AppImage 文件
6. WHEN AppImage 在目标系统运行 THEN AppImage SHALL 正确设置库路径和环境变量
7. WHEN AppImage 在目标系统运行 THEN AppImage SHALL 能够启动 GUI 界面

### Requirement 6: DEB 包构建

**User Story:** 作为开发者，我希望构建 DEB 格式的包，供 Debian/Ubuntu 用户安装。

#### Acceptance Criteria

1. WHEN Package_Builder 构建 DEB THEN Package_Builder SHALL 创建符合 Debian 规范的控制文件
2. WHEN Package_Builder 构建 DEB THEN Package_Builder SHALL 正确声明包依赖关系
3. WHEN Package_Builder 构建 DEB THEN Package_Builder SHALL 将文件安装到标准 Linux 路径
4. WHEN Package_Builder 构建 DEB THEN Package_Builder SHALL 包含 postinst 和 postrm 脚本
5. WHEN DEB 包安装后 THEN 用户 SHALL 能从应用菜单启动 TabFTP

### Requirement 7: RPM 包构建

**User Story:** 作为开发者，我希望构建 RPM 格式的包，供 Red Hat/Fedora/CentOS 用户安装。

#### Acceptance Criteria

1. WHEN Package_Builder 构建 RPM THEN Package_Builder SHALL 创建符合 RPM 规范的 spec 文件
2. WHEN Package_Builder 构建 RPM THEN Package_Builder SHALL 正确声明包依赖关系
3. WHEN Package_Builder 构建 RPM THEN Package_Builder SHALL 将文件安装到标准 Linux 路径
4. WHEN RPM 包安装后 THEN 用户 SHALL 能从应用菜单启动 TabFTP

### Requirement 8: 构建脚本自动化

**User Story:** 作为开发者，我希望有自动化脚本来执行整个构建和打包流程。

#### Acceptance Criteria

1. THE Build_System SHALL 提供一键式构建脚本
2. WHEN 构建脚本执行 THEN Build_System SHALL 按顺序执行清理、编译、打包步骤
3. WHEN 构建脚本执行 THEN Build_System SHALL 输出清晰的进度信息
4. IF 任何步骤失败 THEN Build_System SHALL 停止执行并报告错误
5. WHEN 构建完成 THEN Build_System SHALL 在指定目录生成所有包文件
