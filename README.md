# 家庭记账本 Android APK

这是一个轻量级家庭记账 Android 应用，项目位于 `C:\Users\Administrator\Desktop\money`。应用使用原生 Android `WebView` 承载本地 `HTML/CSS/JavaScript` 页面，数据保存在手机本地浏览器存储中，可离线使用。

## 功能

- 快速记账：打开 App 后优先显示收入 / 支出分类，点击分类即可新增记录。
- 分类管理：支持收入分类、日常刚需、生活消费、固定开销、其他等支出分类。
- 自定义分类：可新增自定义收入或支出分类。
- 删除保护：分类和记录右滑后显示红色 `×`，点击后会二次确认再删除。
- 分类栏排序：长按“收入、日常刚需、生活消费、固定开销、其他”等栏标题，可上下拖动调整顺序。
- 月度汇总：按选择月份显示当月记录列表、总收入、总支出和结余。
- 记录周期：可设置开始日期和结束日期，并统计该周期内总收入、总支出和结余。
- 导出表格：底部提供导出 Excel/CSV 表格功能，包含周期统计和全部记录。

## 目录结构

```text
money/
├─ app/
│  └─ src/main/
│     ├─ AndroidManifest.xml
│     ├─ assets/index.html              # 主要页面、样式和 JS 逻辑
│     ├─ java/com/example/money/
│     │  └─ MainActivity.java           # WebView 容器和导出桥接
│     └─ res/
│        ├─ drawable/ic_launcher.xml
│        └─ values/
│           ├─ strings.xml
│           └─ styles.xml
├─ build-apk.ps1                        # 本地 APK 构建脚本
└─ .gitignore                           # 忽略构建产物和本地密钥
```

## 构建 APK

在 PowerShell 中进入项目目录后执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\build-apk.ps1
```

构建完成后会生成未签名的 `family-money-book.apk`。如果设置了 `SIGNING_KEYSTORE`、`SIGNING_STOREPASS`、`SIGNING_KEYPASS` 和 `SIGNING_ALIAS`，脚本会继续完成签名。

脚本会执行资源编译、Java 编译、DEX 打包、zipalign、签名和签名校验。

## 安装

将 `family-money-book.apk` 传到安卓手机后安装即可。首次安装本地 APK 时，手机可能需要允许“安装未知来源应用”。

## 技术说明

- 包名：`com.example.money`
- 最低 Android 版本：`minSdkVersion 23`
- 目标 Android 版本：`targetSdkVersion 35`
- UI 技术：本地 `assets/index.html`
- 数据存储：`localStorage`
- 导出方式：JavaScript 生成 CSV 内容，通过 Android `ACTION_CREATE_DOCUMENT` 保存文件

## 注意事项

- 当前数据保存在本机 App 的 WebView 本地存储中，卸载 App 可能会清除数据。
- 导出的表格实际为 CSV 格式，可用 Excel、WPS 或 Numbers 打开。
- 若修改 `index.html` 或 `MainActivity.java`，需要重新执行 `build-apk.ps1` 生成新的 APK。
