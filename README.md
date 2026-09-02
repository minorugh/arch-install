# arch-install

Let's note CF-LX3 用の Arch Linux 環境構築リポジトリです。
Debian機（P1メイン / X250サブ）とは完全に独立した**単独機**として構築します。
dotfiles・SSH鍵・GPG秘密鍵は一切共有しません。

このリポジトリはP1側で作成・編集し、Let's note側は最後にcloneして使うだけの
想定です（public リポジトリなので、cloneに認証は不要です）。

---

## 構成

```
arch-install/
├── README.md          このファイル
├── make-install/       USBインストールメディア作成
│   ├── make-usb-arch.sh
│   └── Makefile
├── Makefile            Arch環境構築本体
├── dotfiles/            .zshrc/.vimrc/.gitconfig（このリポジトリ専用の最小構成）
└── docs/                作業記録・引き継ぎメモ
    ├── Arch_Linux_インストール作業記録.md
    └── arch-standalone-handover.md
```

---

## 使い方

### 1. USBメディア作成（別マシンで実施）

```bash
cd make-install
make usb-arch
```

isoが無ければ自動ダウンロード・検証、USBは自動検出のうえ確認して書き込みます。
作り直したいときは `make fresh-arch`。

### 2. archinstall

USBから起動し、`archinstall` でXfce + sudoユーザーまで作成します
（詳細手順は `docs/Arch_Linux_インストール作業記録.md` 参照）。

### 3. このリポジトリをclone

archinstall直後の環境には`git`すら入っていません。まず1行だけ手打ちします。

```bash
sudo pacman -Sy --noconfirm git
git clone https://github.com/minorugh/arch-install.git ~/src/github.com/minorugh/arch-install
cd ~/src/github.com/minorugh/arch-install
```

### 4. 環境構築

```bash
make base         # 基本パッケージ・日本語ロケール一括導入（裸環境から動く）
make sudo-setup   # wheelグループのsudo有効化
make yay          # AURヘルパー導入
make aur          # dropbox・fcitx5-mozc-ut・emacs-mozc導入
make zsh-default  # ログインシェルをzshに
```

`make aur`のあと、メニューからDropboxを起動して初期設定・同期してください。

### 5. Emacs自家ビルド（任意・時間がかかります）

```bash
make emacs-stable
```

### 6. SSH鍵（Let's note専用に新規生成）

```bash
make ssh-setup
```

画面の案内に従ってGitHubに公開鍵を登録し、`~/.ssh/config`を追記してください。

### 7. dotfiles展開

```bash
make init
```

`.gitconfig`の`user.name`/`user.email`は展開後に書き換えてください。

---

## sudoが効かないとき

archinstallでsudo権限付きユーザーを作成したはずでも、まれに`wheel`グループの
有効化が反映されていないことがあります。

```bash
sudo -v
```

これが通らない場合、rootでログインし直して以下を確認してください。

```bash
groups ${USER}                      # wheelに入っているか確認
usermod -aG wheel ${USER}           # 入っていなければ追加
EDITOR=nano visudo                  # %wheel ALL=(ALL:ALL) ALL の行頭#を確認・削除
```

---

## 段階的に導入するもの（今は入れない）

「裸の安定構築」を先に固めてから、以下は状況を見ながら個別に判断して追加します。
詳細は `docs/arch-standalone-handover.md` を参照。

- `.xprofile` / `.Xmodmap`（キーボード・X周りの調整。CF-LX3実機のkeycode要確認）
- `.autostart.sh`（Debian機ではDropbox経由の復元・keychain自動化等、共有前提の設計。書き直しが必要）
- neomutt関連
- 自作elispパッケージ群（git-peek, gcal-dashboard, dashboard-widget-extensions等。
  個別に独立リポジトリとして公開済みのため、必要になった時点で個別にclone）

## 既知の懸案

- pacman版emacsとの共存は avoid 済み（`base`にemacsを含めていない）。
  Let's note側での自家ビルド動作確認は次回セッションで実施
- keychainのエージェントが原因不明で時々死ぬ問題が過去にあった（未解決、再発時は
  `keychain --stop all && rm -rf ~/.ssh/agent ~/.keychain && keychain <鍵>` でリセット）
