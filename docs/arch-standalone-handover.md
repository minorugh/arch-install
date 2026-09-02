# Arch単独機再構築 引き継ぎ書

対象機: Let's note CF-LX3（Arch Linux）
前提: Debian2機（P1メイン / X250サブ）とは今後一切共有関係を持たない、独立機として再構築する

---

## 1. 決定済みの方針

- 既存の`dotfiles/arch-install`（Debian機とenv-import/dotfilesを共有する「サブ機」前提の構成）は破棄する
- GitHubに新規リポジトリ **arch-dotfiles** を立て、単独機として管理する
- **env-importは共用しない**。Arch機のSSH鍵は**新規にArch専用として生成**する（Debian機の鍵の流用・復元はしない）
- 自作elispパッケージ群（git-peek, gcal-dashboard, dashboard-widget-extensions等）は独立リポジトリとして既に公開済みのため、これらは今まで通り個別cloneで導入すればよく、「共有しない」対象には含まれない
- 構築の進め方: **まずほぼ裸の状態で構築し、安定動作を確認してから**、他の設定・自作パッケージ導入は**段階的に**行う（一気に全部入れて崩れると切り分けが困難になるため）

## 2. 現在のMakefile（arch-install/Makefile）の評価

そのまま流用してよいターゲット（Debian機との共有に依存していない）:

- `base`（pacman基本パッケージ）
- `yay`（AURヘルパー導入）
- `aur`（Dropbox等AUR経由パッケージ）
- `sudo-setup`
- `zsh-default`
- `emacs-stable`（Emacsソースビルド）

作り直しが必要なターゲット（Debian機との共有・pull専用サブ機前提の設計）:

- `gpg` / `env-restore`（env-importからの秘密鍵・Dropbox bundle復元 → 廃止し、Arch機上でSSH鍵を新規生成する処理に置き換え）
- `ssh`（復元ではなく生成＋GitHubへの公開鍵登録の案内に変更）
- `switch-ssh`（HTTPS→SSH切り替えの前提が変わるため書き直し）
- `push-block`（サブ機はpull専用という上下関係の産物。単独機では不要、通常はpush可能な運用にする）

`help`/`init`のようなドキュメント兼実行ターゲットの形式自体（メンテ・記録用にリストア可能にしておく）は維持する方針。

### 追加で判明した前提条件（重要）

archinstallでXfce + sudoユーザー作成が完了した直後の環境には、`git`/`make`/`wget`/`nano`/`vim`はおろか`base-devel`すら入っていなかった。加えてsudo権限の実効性、日本語フォント（CJK）も未整備だった。このため`arch-install/Makefile`（ないし新arch-dotfiles/Makefile）を動かす**前段階**として、以下の0段階ブートストラップを手順書の先頭に明記する必要がある。詳細手順は`Arch_Linux_インストール作業記録.md`の「改善版：0段階」を参照。

1. `sudo -v`でsudoが実効しているか確認（ダメならwheelグループ・visudoを手動修正）
2. `sudo pacman -S --needed base-devel git wget nano vim networkmanager`
3. `sudo pacman -S --needed noto-fonts-cjk noto-fonts-emoji`＋ロケール確認
4. ここまで終えて初めて`git clone`〜`make base`以降に進む

`base`ターゲット自体にもこれらのパッケージ（`base-devel`/`git`/`wget`/`nano`/`vim`/CJKフォント）を含めておくと、0段階を飛ばして着手された場合の保険になる（`--needed`前提なら二重実行しても無害）。

## 3. Emacs自家ビルド（ビルド完了・要確認事項あり）

- `--without-xim` `--with-native-compilation=aot` で、既に導入済みだったものと同じ31.1を自家ビルドし、`sudo make install`まで完了。表面上は起動している。
- **懸念**: `--without-xim`が効いていない疑いがある（fcitx5-mozcが引き続き入力を横取りしている可能性）。原因として、pacman版emacs（先にインストールされていたもの）と自家ビルド版が共存しており、**実際に起動しているのがpacman版（XIM有効）のままである**可能性が高い。

### 次回セッションでの確認・対処手順

1. 実行されているバイナリの特定
   ```bash
   which -a emacs
   type -a emacs
   ```
   `/usr/local/bin/emacs`（自家ビルド）と`/usr/bin/emacs`（pacman版）が両方出てくる場合、PATH上どちらが先に解決されるかを確認する。Archのデフォルト`$PATH`は`/usr/local/bin`が`/usr/bin`より前に来るのが通常だが、`.zshrc`等で上書きされていないか確認。

2. 実際に起動しているバイナリがXIM有りでビルドされていないか確認
   ```bash
   emacs -Q --batch --eval '(princ system-configuration-options)'
   ```
   出力に`--without-xim`が含まれているかを見る。含まれていなければ、今起動しているのはpacman版（またはXIM有効でビルドされた別バイナリ）。

3. GUIランチャー（Xfceメニュー・.desktopファイル）が固定パスを指していないか確認
   ```bash
   grep -r "Exec=emacs" /usr/share/applications/ ~/.local/share/applications/ 2>/dev/null
   ```
   `Exec=/usr/bin/emacs`のように固定パスが指定されている場合、ターミナルからの起動とメニューからの起動で挙動が変わる原因になる。

4. pacman版との共存を続けるか、削除して自家ビルド版に一本化するかを決める
   - 一本化する場合:
     ```bash
     sudo pacman -R emacs
     ```
     （依存関係で他パッケージが巻き込まれないか`-R`実行前に確認。emacs-mozcがemacsパッケージへの依存を持っていないか要注意）
   - 共存させたままにする場合は、`.zshrc`等で`alias emacs=/usr/local/bin/emacs`のように明示的にバイナリを固定し、GUIランチャーの`.desktop`ファイルも自家ビルド版のパスに書き換える

5. 上記対処後、`emacs -Q --batch --eval '(princ system-configuration-options)'`で`--without-xim`が反映されたバイナリが実際に起動することを確認し、fcitx5-mozcの横取りが解消されるか再テストする

## 4. mozc問題（解決済み）

### 経緯（参考）
- `fcitx5-mozc`（公式リポジトリ版・一体型）を先に導入 → `emacs-mozc`と依存パッケージが衝突
- 原因はArchWiki記載の通り、公式リポジトリの`fcitx5-mozc`/`fcitx-mozc`がサーバーとFcitx連携モジュールを一体化しており、他IMF用パッケージ（`emacs-mozc`等）とファイル競合を起こす設計だったため

### 対処済み
```bash
sudo pacman -Rns fcitx5-mozc
yay -S --needed fcitx5-mozc-ut emacs-mozc
```
AUR分離型（`fcitx5-mozc-ut` + `emacs-mozc`）への切り替えで**衝突は解消し、再インストール・動作確認済み**。

### 残課題
mozc自体は解決したが、Emacs内でfcitx5-mozcが引き続き横取りする挙動が残っている場合、原因は3章の「pacman版emacsとの競合疑い」である可能性が高い。3章の確認・対処が完了すれば、mozc側の設定（`06-mozc.el`）はそのまま機能するはず。

## 5. 「裸」の完了ラインの目安

以下が揃った時点を「裸の安定構築完了」とみなし、以降の設定・自作パッケージ導入に進む:

- 0段階ブートストラップ（sudo/base-devel/git/wget/nano/vim/CJKフォント）完了
- base / yay / aur / sudo-setup / zsh-default 完了
- Emacs自家ビルド（`--without-xim` `--with-native-compilation=aot`）完了、かつ**自家ビルド版が実際に起動していることを確認済み**（3章参照）
- emacs-mozcによるEmacs内日本語入力の動作確認完了（fcitx5の横取りなし）
- （必要なら）fcitx5経由のシステム全体日本語入力の動作確認完了
- 新規SSH鍵生成＋GitHubへの登録、arch-dotfilesリポジトリへのpush確認

## 6.5. 後で導入予定の便利sh・設定群（現時点ではファイル本体は渡さない）

Debian機で使っている以下のスクリプトを段階的に導入予定。内容評価済み・依存関係の見立てのみ記録しておく。実際に着手するステップに来たら、その時点で該当ファイルを改めて貼って進める。

| ファイル | 依存関係の見立て | 導入タイミング |
|---|---|---|
| `.xprofile`（前半: xrdb/setxkbmap/xmodmap部分） | 共有依存なし | 早めに持ち込み可（`.Xresources`経由の`useXIM`設定運用の土台にもなる） |
| `.Xmodmap` | 共有依存なし。ただしCF-LX3実機のkeycodeが前提（ThinkPad/Keychron K3 Max前提の記述あり）と一致するか`xev`で要確認 | `.xprofile`と同時 |
| `.xprofile`（後半: dbus-update-activation-environment/keychain SSH agent部分） | Arch専用の新規SSH鍵生成・keychain設定が前提 | SSH鍵生成完了後 |
| `emacs-start.sh` | `/usr/local/bin/emacs`ハードコード。現在進行中のEmacs競合対処（3章）と直結 | Emacs競合解消と同時 |
| `neomutt.sh` | 共有依存が薄い。neomutt自体の導入が前提 | 「裸」完了後、段階的育成フェーズ |
| `.autostart.sh` | env-import共有(bindfs)・Dropbox経由.mozc/keyrings復元・keychain自動SSH解錠など共有前提の設計。書き直しが必要 | 裸の完了ライン（SSH鍵生成・mozc方針決定・Emacs競合解消）を全て通過した後、書き直しながら導入 |

## 6. まだ決めていない・持ち越しの論点

- arch-dotfilesリポジトリの構成: `.zshrc`/`.emacs.d`本体＋Makefileのみを持たせ、自作elispパッケージ群は今まで通り個別リポジトリとして分離管理する案を提示済み（要確認・決定）
- GPG（コミット署名等）を使うかどうか未決定。これによって`ssh`/新Makefileの鍵生成ターゲットの設計が変わる
- `~/.mozc`（学習辞書・設定データ）をDebian機とDropbox経由でシンボリックリンク共有している。単独機方針として、これも継続共有をやめるか（Arch機はゼロから学習させる、または初回のみコピーして以降独立させる）要検討・未決定
- pacman版emacsとの共存方針（削除して一本化 or alias/desktopファイルで明示的に使い分け）未決定（3章参照）
