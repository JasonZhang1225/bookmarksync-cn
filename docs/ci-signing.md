# CI 固定签名（E2）

## 已配置的身份

- 公钥证书：`signing/BookmarkSync-Signing.crt`。此文件不含私钥，可以提交。
- GitHub 仓库 Secrets：`MACOS_SIGNING_P12_BASE64`、`MACOS_SIGNING_P12_PASSWORD`。
- 本机备份：`~/Library/Application Support/BookmarkSync-Signing/`，包含加密的 `BookmarkSync-Signing.p12`、`p12-password.txt` 和公钥证书；目录仅当前用户可访问。请将整个目录一起妥善备份，密码和证书都不能提交到 Git。
- 证书 SHA-1 指纹：`C46362F9D275F871A0DE17A1D06BE387ED7C981B`（用于选定签名证书，不是文件完整性算法）。
- 证书有效期为生成日起十年。更换证书将改变身份，需要重新授权。

这张证书专用于本项目，不使用用户现有的 Apple Development 私钥。它不是 Developer ID 证书，也不提供 Apple 公证；首次下载安装的系统检查仍可能出现。

## 工作流行为

同仓库 PR 和手动运行会在 XCTest 通过后，从 Secrets 导入证书到一次性钥匙串，签名应用并验证它锚定到上述公钥。缺少或不匹配的证书会使打包失败，不会退回 ad-hoc 签名。临时 P12 和钥匙串在脚本退出时清理，不修改默认或登录钥匙串，不给系统添加信任根。

CI 还复制应用、更改资源并再次签名，验证内容哈希变化，但 designated requirement 保持一致，且更新版能满足旧版的签名要求。Fork PR 只运行编译和测试，不获得签名 Secrets，也不上传应用包。

实际在 macOS 保留“完全磁盘访问”授权，还需对两个签名版本执行一次安装替换实测。签名一致性检查本身不能证明所有系统版本的权限行为。

## 首次切换

从 ad-hoc 版切换到固定证书版时，身份变化，因此需要最后重新授权一次：

1. 完全退出 BookmarkSync，将新包中的应用放入 `/Applications` 替换旧版。
2. 在“系统设置 → 隐私与安全性 → 完全磁盘访问权限”中移除旧条目，再添加当前的 `/Applications/BookmarkSync.app` 并开启权限。
3. 重新启动应用，确认能读取 Safari。
4. 下次安装同一证书签名的新版，检查无需重加权限即可读取 Safari。

系统重置权限、证书更换等情况仍可能需要重新授权，不承诺永久有效。

## 从本机备份恢复 Secrets

在已登录本仓库 GitHub 管理账号的终端中运行（不会把证书内容或密码打印到终端）：

```sh
SIGNING_BACKUP="$HOME/Library/Application Support/BookmarkSync-Signing"
base64 -i "$SIGNING_BACKUP/BookmarkSync-Signing.p12" | gh secret set MACOS_SIGNING_P12_BASE64 --repo JasonZhang1225/bookmarksync-cn
gh secret set MACOS_SIGNING_P12_PASSWORD --repo JasonZhang1225/bookmarksync-cn < "$SIGNING_BACKUP/p12-password.txt"
```

不要在每次构建时生成新证书。若备份丢失，GitHub Secrets 无法直接读回；只能更换证书，并重新授权已安装应用。

参考：[Apple TN3127：签名身份与隐私权限](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)、[Apple TN2206：自签名证书](https://developer.apple.com/library/archive/technotes/tn2206/)。
