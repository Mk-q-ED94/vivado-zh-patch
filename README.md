# Vivado 界面汉化补丁

这是一个面向 Windows 的非官方 Vivado 部分界面汉化补丁。它使用 Java agent 翻译运行时界面文字，支持向已打开的 Vivado 窗口注入，也可以在启动时加载。补丁不包含 Vivado 程序或 AMD 的库文件，也不改写 Vivado 安装目录。

> 目前只在 Windows 的 Vivado 2025.2 上验证了界面加载、实时注入、部分导航和项目向导。其他版本采用通用兼容模式，尚未进行端到端测试。部分界面、日志、代码和专业术语仍显示英文。

## 使用

1. 从 GitHub 的 **Code → Download ZIP** 下载并完整解压，保留所有文件的相对位置。
2. 双击 `one_click.bat`。它会尝试对已打开的 Vivado 窗口注入；没有可注入窗口时会查找已安装的 Vivado 并启动汉化版。
3. 如果同时打开多个 Vivado 窗口，请按照提示选择；输入 `0` 可启动新窗口。如果当前窗口已加载旧补丁或不允许注入，脚本会保留原窗口，尝试打开新的汉化窗口。

实时注入会在选中的 Vivado 进程内加载本项目组件，需要有权访问该进程，且目标 JVM 支持 Java Attach。启动方式会在当前启动进程中设置 `JAVA_TOOL_OPTIONS`；不会修改系统级环境变量。启动新窗口时，请保留命令窗口直至 Vivado 退出。

保存工作并退出汉化版后，从 Vivado 原有快捷方式启动即可恢复原版。注入不是可在运行中卸载的插件。如果发现界面或功能异常，请改用原版。

## 版本与兼容性

| 项目 | 状态 |
| --- | --- |
| Windows + Vivado 2025.2 | 已检查启动、注入、重复注入保护、项目向导及部分导航操作 |
| Java 11、21 | 使用 Vivado 附带的运行时完成组件基础自检 |
| Java 8 | 编译目标为 Java 8；尚未在真实 Java 8 运行时测试 |
| 其他 Vivado 版本 | 通用控件翻译属实验性；2025.2 流程导航的内部类适配不会用于未知版本 |

不同版本可能调整界面内部实现；字节码可加载不等于所有界面和功能均已兼容。补丁不会遍历编辑器、表格、列表或普通树的数据渲染区域，也不会替换 Verilog 源文件、Tcl 命令或 Vivado 的日志文字；汉化后的显示文本仍可能影响少数依赖文本的操作，请使用前备份重要工程。

仓库的 Windows GitHub Actions 包含 Java 8、11、17、21 的自动化自检，以及使用伪安装目录的启动脚本测试。自检不包含 Vivado 程序本身；各版本的实际运行结果请查看 Actions，不应据此推断所有 Vivado 版本均已通过验证。

## 查找安装与参数

没有选中已运行窗口时，脚本先查找 `-VivadoRoot`、`XILINX_VIVADO`、`VIVADO_HOME`，再查找各盘常见 AMDDesignTools/Xilinx 目录和 `PATH`；有多个安装版本时选择版本号较新的候选。如果自动查找不到，可以手动指定包含 `bin\vivado.bat` 的 Vivado 根目录：

```powershell
.\one_click.bat -StartNew -VivadoRoot "D:\Apps\Vivado\2025.2"
```

`-StartNew` 启动新窗口；`-ProcessId 12345` 指定正在运行的 Vivado 主窗口 PID，两者不能同时使用。文件夹路径支持中文和空格；显式指定的 `-VivadoRoot` 无效时会报错，不会切换到其他安装。实时注入若不可用，脚本会提示并回退为启动新窗口。

## 从源码构建

仓库中附有由本项目源码编译的 `vivado-zh-agent.jar`，供下载 ZIP 后直接使用；不包含 AMD 程序。也可用 JDK 9 或更新版本自行构建，示例：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -JdkHome "C:\path\to\jdk"
```

省略 `-JdkHome` 时，脚本尝试使用 `JAVA_HOME` 或 `PATH`。构建使用 `javac --release 8`，先对临时产物执行无界面自检，成功后才覆盖仓库中的 JAR。确保没有运行中的 Vivado 正在使用该 JAR。已注入进程的词表不会自动刷新，需要重新启动并加载补丁。

## 文件说明

- `one_click.bat`、`one_click.ps1`：启动、检测与实时注入入口。
- `src/VivadoChineseAgentV2.java`：界面翻译组件。
- `src/VivadoAttach.java`：调用 Java Attach 的小工具。
- `src/TranslationSelfTest.java`：基础控件、自检与动作命令保护检查。
- `translations.tsv`：UTF-8 词表，每行英文和中文以制表符分隔。
- `build.ps1`、`manifest.mf`：构建与 agent 清单。
- `tests/launcher.tests.ps1`：启动脚本的隔离测试；不会启动真正的 Vivado。
- `tests/build.tests.ps1`：验证构建自检失败时保留原 JAR。

本项目可能生成 `patch.log`；默认不会上传日志或用户工程。诊断模式可能记录界面节点及路径，请检查日志后再分享。

## 许可证与商标

本项目原创代码和词表采用 [MIT License](LICENSE)。Vivado 是 AMD 的产品；本项目与 AMD 无关，也不授予 AMD 软件的任何许可。
