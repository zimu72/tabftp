# TabFTP Windows 构建指南

## 构建环境

Visual Studio 2022 Build Tools 
MSBuild
MSVC 编译器
Windows SDK
NSIS
依赖库 - 需要配置

## 依赖库获取

TabFTP 需要以下依赖库。有两种方式获取：

### 方式一：使用预编译的 FileZilla 依赖包（推荐）

FileZilla 官方提供了预编译的依赖包，这是最简单的方式：

1. 访问 https://download.filezilla-project.org/client/
2. 下载对应版本的依赖包（通常命名为 `FileZilla_x.xx.x_win64_deps.zip`）
3. 解压到 `C:\libs\filezilla-deps\`

### 方式二：手动编译依赖（复杂）

如果需要手动编译，需要以下库：

#### 1. libfilezilla (必需)
- 下载: https://lib.filezilla-project.org/
- 版本要求: >= 0.51.1
- 编译说明: 需要先编译 GnuTLS

#### 2. wxWidgets (必需)
- 下载: https://www.wxwidgets.org/downloads/
- 版本要求: >= 3.2.1
- 编译命令:
```batch
cd wxWidgets-3.2.x\build\msw
nmake /f makefile.vc BUILD=release SHARED=0 UNICODE=1 TARGET_CPU=X64
```

#### 3. GnuTLS (必需)
- 下载: https://www.gnutls.org/download.html
- 建议使用预编译版本

#### 4. SQLite3 (必需)
- 下载: https://www.sqlite.org/download.html
- 下载 amalgamation 版本

#### 5. Nettle/Hogweed (必需)
- 通常包含在 GnuTLS 中

## 配置 Dependencies.props

创建 `src\Dependencies.props` 文件，内容如下：

```xml
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="4.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <ImportGroup Label="PropertySheets" />
  <PropertyGroup Label="UserMacros">
    <!-- 根据你的实际路径修改 -->
    <libfilezilla_include>C:\libs\libfilezilla\include</libfilezilla_include>
    <libfilezilla_lib>C:\libs\libfilezilla\lib</libfilezilla_lib>
    <wxwidgets_include>C:\libs\wxWidgets\include;C:\libs\wxWidgets\include\msvc</wxwidgets_include>
    <wxwidgets_lib>C:\libs\wxWidgets\lib\vc_x64_lib</wxwidgets_lib>
    <gnutls_include>C:\libs\gnutls\include</gnutls_include>
    <gnutls_lib>C:\libs\gnutls\lib</gnutls_lib>
    <sqlite3_include>C:\libs\sqlite3</sqlite3_include>
    <sqlite3_lib>C:\libs\sqlite3</sqlite3_lib>
  </PropertyGroup>
  <PropertyGroup>
    <IncludePath>$(libfilezilla_include);$(gnutls_include);$(sqlite3_include);$(IncludePath)</IncludePath>
    <LibraryPath>$(libfilezilla_lib);$(gnutls_lib);$(sqlite3_lib);$(LibraryPath)</LibraryPath>
  </PropertyGroup>
  <ItemDefinitionGroup />
  <ItemGroup>
    <BuildMacro Include="libfilezilla_include">
      <Value>$(libfilezilla_include)</Value>
    </BuildMacro>
    <BuildMacro Include="libfilezilla_lib">
      <Value>$(libfilezilla_lib)</Value>
    </BuildMacro>
    <BuildMacro Include="wxwidgets_include">
      <Value>$(wxwidgets_include)</Value>
    </BuildMacro>
    <BuildMacro Include="wxwidgets_lib">
      <Value>$(wxwidgets_lib)</Value>
    </BuildMacro>
    <BuildMacro Include="gnutls_include">
      <Value>$(gnutls_include)</Value>
    </BuildMacro>
    <BuildMacro Include="gnutls_lib">
      <Value>$(gnutls_lib)</Value>
    </BuildMacro>
    <BuildMacro Include="sqlite3_include">
      <Value>$(sqlite3_include)</Value>
    </BuildMacro>
    <BuildMacro Include="sqlite3_lib">
      <Value>$(sqlite3_lib)</Value>
    </BuildMacro>
  </ItemGroup>
</Project>
```

## 构建步骤

配置好依赖后，运行以下命令构建：

```batch
:: 设置 Visual Studio 环境
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"

:: 构建 Release 版本
msbuild src\FileZilla.sln /p:Configuration=Release /p:Platform=x64

:: 创建安装包
cd data
makensis install.nsi
```

## 快速开始脚本

运行 `build.bat` 可以自动执行构建过程（需要先配置好依赖）。

## 常见问题

### Q: 找不到 libfilezilla.h
A: 检查 Dependencies.props 中的 libfilezilla_include 路径是否正确

### Q: 链接错误 LNK2019
A: 检查库文件路径是否正确，确保使用的是 x64 版本的库

### Q: wxWidgets 版本不匹配
A: 确保使用 wxWidgets 3.2.1 或更高版本，并且是 Unicode 静态库版本
