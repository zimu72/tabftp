# Requirements Document

## Introduction

本文档定义了将 TabFTP（基于 FileZilla 的 FTP 客户端）从 Linux 构建环境迁移到 Windows 平台进行编译构建的需求。目标是清理 Linux 相关的编译产物，配置 Windows 构建环境，并生成精简的 Windows 安装包（exe 格式）。

## Glossary

- **TabFTP**: 基于 FileZilla 改造的 FTP 客户端软件
- **Build_System**: Visual Studio 2019/2022 构建系统
- **NSIS**: Nullsoft Scriptable Install System，用于创建 Windows 安装程序
- **Dependencies**: 项目依赖库，包括 libfilezilla、wxWidgets、GnuTLS、SQLite3 等
- **Linux_Artifacts**: Linux 平台编译产生的中间文件和产物
- **AppImage**: Linux 平台的应用打包格式
- **vcpkg**: Microsoft 的 C++ 包管理器

## Requirements

### Requirement 1: 清理 Linux 编译产物

**User Story:** As a developer, I want to clean up all Linux-specific build artifacts, so that the project is ready for a clean Windows build.

#### Acceptance Criteria

1. WHEN the cleanup script is executed, THE Build_System SHALL remove all `.o` object files from the source directories
2. WHEN the cleanup script is executed, THE Build_System SHALL remove all `.lo` libtool object files
3. WHEN the cleanup script is executed, THE Build_System SHALL remove all `.la` libtool archive files
4. WHEN the cleanup script is executed, THE Build_System SHALL remove all `.gch` precompiled header files
5. WHEN the cleanup script is executed, THE Build_System SHALL remove all `.deps` dependency directories
6. WHEN the cleanup script is executed, THE Build_System SHALL remove all `.libs` library directories
7. WHEN the cleanup script is executed, THE Build_System SHALL remove AppImage related files (`.AppImage`, `AppDir`, `squashfs-root`)
8. WHEN the cleanup script is executed, THE Build_System SHALL remove Linux-specific executables without extensions in `src/interface/`
9. THE Build_System SHALL preserve all source code files (`.cpp`, `.h`, `.mm`)
10. THE Build_System SHALL preserve Visual Studio project files (`.sln`, `.vcxproj`)

### Requirement 2: 配置 Windows 依赖项

**User Story:** As a developer, I want to configure all required dependencies for Windows build, so that the project can compile successfully.

#### Acceptance Criteria

1. THE Dependencies SHALL include libfilezilla version 0.51.1 or higher
2. THE Dependencies SHALL include wxWidgets version 3.2.1 or higher with unicode support
3. THE Dependencies SHALL include GnuTLS for TLS/SSL support
4. THE Dependencies SHALL include SQLite3 for database functionality
5. THE Dependencies SHALL include Nettle and Hogweed for cryptographic operations
6. WHEN configuring dependencies, THE Build_System SHALL create a `Dependencies.props` file with correct paths
7. THE Dependencies.props file SHALL specify include paths for all required libraries
8. THE Dependencies.props file SHALL specify library paths for all required libraries

### Requirement 3: Visual Studio 项目配置

**User Story:** As a developer, I want the Visual Studio solution to be properly configured, so that I can build the project in Release mode.

#### Acceptance Criteria

1. THE Build_System SHALL support x64 Release configuration
2. THE Build_System SHALL compile the engine project as a static library
3. THE Build_System SHALL compile the commonui project as a static library
4. THE Build_System SHALL compile the pugixml project as a static library
5. THE Build_System SHALL compile the interface project as the main executable
6. WHEN building in Release mode, THE Build_System SHALL enable optimizations for smaller binary size
7. WHEN building in Release mode, THE Build_System SHALL strip debug symbols

### Requirement 4: 创建 Windows 安装包

**User Story:** As a developer, I want to create a Windows installer package, so that users can easily install TabFTP.

#### Acceptance Criteria

1. THE NSIS installer SHALL include the main TabFTP executable
2. THE NSIS installer SHALL include fzsftp.exe for SFTP support
3. THE NSIS installer SHALL include fzputtygen.exe for key generation
4. THE NSIS installer SHALL include all required DLL dependencies
5. THE NSIS installer SHALL include resource files (icons, themes, sounds)
6. THE NSIS installer SHALL include localization files (.mo files)
7. THE NSIS installer SHALL use LZMA compression for smaller package size
8. THE NSIS installer SHALL support both per-user and all-users installation
9. THE NSIS installer SHALL create Start Menu shortcuts
10. THE NSIS installer SHALL register uninstaller in Windows registry
11. IF unnecessary files are detected, THEN THE NSIS installer SHALL exclude them to minimize package size

### Requirement 5: 优化安装包大小

**User Story:** As a developer, I want the installer to be as small as possible, so that users can download it quickly.

#### Acceptance Criteria

1. THE Build_System SHALL exclude debug symbols from the final build
2. THE Build_System SHALL exclude unused icon themes (keep only default theme)
3. THE Build_System SHALL exclude unused localization files (keep only essential languages)
4. THE Build_System SHALL use static linking where possible to reduce DLL count
5. THE NSIS installer SHALL use maximum LZMA compression
6. WHEN packaging, THE Build_System SHALL exclude development files (headers, .lib files)
7. WHEN packaging, THE Build_System SHALL exclude documentation files not needed at runtime

### Requirement 6: 构建脚本自动化

**User Story:** As a developer, I want automated build scripts, so that I can easily rebuild the project.

#### Acceptance Criteria

1. THE Build_System SHALL provide a PowerShell script for cleaning Linux artifacts
2. THE Build_System SHALL provide a batch script for building the Visual Studio solution
3. THE Build_System SHALL provide a script for creating the NSIS installer
4. WHEN an error occurs during build, THE Build_System SHALL display a clear error message
5. WHEN the build completes successfully, THE Build_System SHALL display the output file location
