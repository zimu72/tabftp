# Design Document: Linux Build and Packaging

## Overview

本设计文档描述了在 Linux 系统上清理 Windows 构建产物、重新编译 TabFTP，并构建 deb、AppImage、rpm 包的技术方案。设计采用保守策略，优先确保在各种 Linux 发行版上的兼容性和稳定运行。

核心设计原则：
1. **完整依赖打包**：将所有运行时依赖打包进安装包，避免依赖目标系统的库版本
2. **自包含运行**：使用自带的动态链接器确保库加载的一致性
3. **跨发行版兼容**：AppImage 采用完全自包含方案，DEB/RPM 采用最小依赖声明

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Build Pipeline                                │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────────┐ │
│  │  Clean   │ → │Configure │ → │  Build   │ → │   Package    │ │
│  │  Stage   │   │  Stage   │   │  Stage   │   │   Stage      │ │
│  └──────────┘   └──────────┘   └──────────┘   └──────────────┘ │
│       │              │              │               │           │
│       ▼              ▼              ▼               ▼           │
│  Remove Win    Check deps     Compile src    Create packages   │
│  artifacts     Run configure  Link binaries  Bundle deps       │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    Package Outputs                               │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │  AppImage   │  │    DEB      │  │    RPM      │             │
│  │ (Portable)  │  │ (Debian)    │  │ (RedHat)    │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│        │                │                │                      │
│        ▼                ▼                ▼                      │
│  Self-contained    /opt/tabftp     /opt/tabftp                 │
│  with ld-linux     + symlinks      + symlinks                  │
└─────────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. Clean Component (clean_build.sh)

负责清理 Windows 构建产物，为 Linux 构建准备干净的环境。

```bash
# 接口定义
clean_build() {
    # 输入: 项目根目录
    # 输出: 清理后的项目目录
    # 副作用: 删除所有 Windows 构建产物
}
```

清理目标：
- `.o`, `.lo`, `.la` 目标文件
- `.exe`, `.dll` Windows 可执行文件
- `config.status`, `config.log`, `config.h` 配置缓存
- `.libs/`, `.deps/` 目录内容
- `*.gch` 预编译头文件
- `libtool` 生成的文件

### 2. Build Component (build_linux.sh)

负责在 Linux 上编译 TabFTP。

```bash
# 接口定义
build_linux() {
    # 输入: 清理后的源代码目录
    # 输出: 编译后的可执行文件和库
    # 依赖: libfilezilla, wxWidgets, nettle, sqlite3, libdbus, GTK3
}
```

编译流程：
1. 运行 `autoreconf -i` (如需要)
2. 运行 `./configure` 配置构建
3. 运行 `make -j$(nproc)` 并行编译
4. 验证生成的可执行文件

### 3. Dependency Bundler Component

负责收集所有运行时依赖。

```bash
# 接口定义
bundle_dependencies() {
    # 输入: 可执行文件列表
    # 输出: 依赖库目录
    # 方法: ldd 分析 + 递归复制
}
```

依赖收集策略：
- 使用 `ldd` 分析所有可执行文件
- 复制所有非 glibc 核心库
- 包含 GTK 主题引擎和图标
- 包含 gdk-pixbuf 加载器
- 包含 glib schemas
- 包含翻译文件 (.mo)

### 4. AppImage Builder Component

负责构建 AppImage 格式的便携包。

```bash
# 接口定义
build_appimage() {
    # 输入: 编译后的程序和依赖
    # 输出: TabFTP-x86_64.AppImage
}
```

AppImage 结构：
```
AppDir/
├── AppRun                 # 启动脚本
├── tabftp.desktop         # 桌面文件
├── tabftp.png             # 应用图标
└── usr/
    ├── bin/
    │   ├── tabftp         # 主程序
    │   ├── fzsftp         # SFTP 辅助程序
    │   └── fzputtygen     # 密钥生成器
    ├── lib/
    │   ├── ld-linux-x86-64.so.2  # 动态链接器
    │   ├── lib*.so*              # 所有依赖库
    │   └── gdk-pixbuf-2.0/       # 图像加载器
    └── share/
        ├── tabftp/resources/     # 程序资源
        └── glib-2.0/schemas/     # GLib schemas
```

### 5. DEB Builder Component

负责构建 Debian/Ubuntu 安装包。

```bash
# 接口定义
build_deb() {
    # 输入: 编译后的程序和依赖
    # 输出: tabftp_VERSION_amd64.deb
}
```

DEB 包结构：
```
deb-root/
├── DEBIAN/
│   ├── control           # 包元数据
│   ├── postinst          # 安装后脚本
│   └── postrm            # 卸载后脚本
├── opt/
│   └── tabftp/           # 程序文件
│       ├── bin/
│       ├── lib/
│       └── share/
└── usr/
    ├── bin/
    │   └── tabftp -> /opt/tabftp/bin/tabftp
    └── share/
        └── applications/
            └── tabftp.desktop
```

### 6. RPM Builder Component

负责构建 Red Hat/Fedora/CentOS 安装包。

```bash
# 接口定义
build_rpm() {
    # 输入: 编译后的程序和依赖
    # 输出: tabftp-VERSION.x86_64.rpm
}
```

## Data Models

### Package Metadata

```yaml
Package:
  name: tabftp
  version: 3.69.5
  architecture: amd64/x86_64
  maintainer: TabFTP Team
  description: TabFTP FTP/SFTP Client
  homepage: https://tabftp.org
  license: GPL-2.0+
```

### Dependency List

```yaml
BuildDependencies:
  - libfilezilla-dev >= 0.51.1
  - libwxgtk3.2-dev >= 3.2.1
  - libnettle-dev >= 3.1
  - libsqlite3-dev >= 3.7
  - libdbus-1-dev
  - libgtk-3-dev
  - pkg-config
  - g++ >= 7

RuntimeDependencies:
  - libc6
  - libstdc++6
  - libgcc-s1
  - bash
```

### File Mapping

```yaml
Binaries:
  - src: src/interface/.libs/tabftp
    dst: bin/tabftp
  - src: src/putty/fzsftp
    dst: bin/fzsftp
  - src: src/putty/fzputtygen
    dst: bin/fzputtygen

Libraries:
  - src: src/engine/.libs/libfzclient-private*.so*
    dst: lib/
  - src: src/commonui/.libs/libfzclient-commonui-private*.so*
    dst: lib/

Resources:
  - src: src/interface/resources/
    dst: share/tabftp/resources/
  - src: locales/*.mo
    dst: share/locale/
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Clean Operation Preserves Source Files
*For any* project directory containing source files and Windows build artifacts, after executing the clean operation, all source files (.cpp, .h, .c, .am, .ac) SHALL remain intact while all Windows artifacts (.exe, .dll, .o, .lo, .la) SHALL be removed.
**Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5**

### Property 2: Build Output Completeness
*For any* successful build execution, the build system SHALL produce all required executables (tabftp, fzsftp, fzputtygen) and private libraries (libfzclient-private.so, libfzclient-commonui-private.so).
**Validates: Requirements 3.2, 3.3, 3.4, 3.5**

### Property 3: Dependency Collection Completeness
*For any* executable in the package, running `ldd` on it within the package environment SHALL show all dependencies resolved to libraries within the package directory (except for basic system libraries like linux-vdso.so).
**Validates: Requirements 4.1, 4.2**

### Property 4: AppImage Self-Containment
*For any* AppImage package, the AppDir SHALL contain: (1) AppRun script, (2) .desktop file, (3) application icon, (4) all executables, (5) all required libraries including ld-linux, (6) gdk-pixbuf loaders, (7) glib schemas.
**Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.6**

### Property 5: DEB Package Structure Validity
*For any* DEB package, the package SHALL contain: (1) valid DEBIAN/control file with required fields, (2) files installed to standard paths (/opt/tabftp or /usr), (3) proper symlinks for command-line access.
**Validates: Requirements 6.1, 6.2, 6.3**

### Property 6: RPM Package Structure Validity
*For any* RPM package, the package SHALL contain: (1) valid spec file with required sections, (2) files installed to standard paths, (3) proper dependency declarations.
**Validates: Requirements 7.1, 7.2, 7.3**

### Property 7: Build Script Error Handling
*For any* build script execution, if any step fails (configure, make, package), the script SHALL immediately stop execution and return a non-zero exit code with error message.
**Validates: Requirements 8.2, 8.4**

## Error Handling

### Build Errors

| Error Type | Detection | Recovery |
|------------|-----------|----------|
| Missing dependency | configure fails | Display install instructions |
| Compilation error | make returns non-zero | Show error log, stop build |
| Linking error | make returns non-zero | Check library paths |
| Package tool missing | Command not found | Install required tool |

### Runtime Errors (AppImage)

| Error Type | Detection | Recovery |
|------------|-----------|----------|
| Library not found | ldd shows missing | Bundle missing library |
| Wrong glibc version | Segfault on start | Use bundled ld-linux |
| GTK theme missing | UI looks broken | Bundle theme files |
| Pixbuf loader missing | Images not shown | Bundle loaders |

### Error Messages

```bash
# 依赖缺失
echo "ERROR: libfilezilla not found. Install with:"
echo "  Ubuntu/Debian: sudo apt install libfilezilla-dev"
echo "  Fedora: sudo dnf install libfilezilla-devel"

# 编译失败
echo "ERROR: Compilation failed. Check the error above."
echo "  Common fixes:"
echo "  - Ensure all dependencies are installed"
echo "  - Run 'make clean' and try again"

# 打包工具缺失
echo "ERROR: appimagetool not found. Download from:"
echo "  https://github.com/AppImage/AppImageKit/releases"
```

## Testing Strategy

### Unit Tests
- 验证清理脚本正确删除目标文件
- 验证依赖检查脚本正确识别缺失依赖
- 验证文件复制脚本正确处理符号链接

### Integration Tests
- 完整构建流程测试（从清理到打包）
- AppImage 在不同发行版上的启动测试
- DEB 包安装和卸载测试
- RPM 包安装和卸载测试

### Property-Based Tests
- 使用 bash 脚本验证文件系统状态
- 验证包内容完整性
- 验证依赖解析正确性

### Test Configuration
- 测试框架：bash 脚本 + 断言函数
- 最小测试迭代：每个属性测试至少运行一次完整构建
- 测试标签格式：**Feature: linux-build-packaging, Property N: property_text**
