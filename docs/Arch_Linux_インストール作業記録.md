# Arch Linux インストール作業記録

## 2026-09-01

### 対象
Panasonic Let's note CF-LX3

### インストール前

Arch Linux のインストールUSBから起動。

起動時に、

> 署名されていない起動デバイスが選択されました。セキュアブートの設定を確認してください

という警告が表示された。

BIOSのセキュリティ設定を確認したところ、**セキュアブート**の項目を発見。

- セキュアブート：無効
- Boot Mode：通常のまま

設定後、Arch LinuxのインストールUSBから正常に起動できた。

### ディスク確認

`lsblk` で確認。

内蔵ディスク：

```text
/dev/sda
├─sda1   600M
├─sda2   260M
├─sda3   128M
├─sda4   215.4G
├─sda5   865M
└─sda6    15.6G
```

`/dev/sdb` はインストールUSB。

今回はWindowsを残さず、**/dev/sdaを丸ごとArch Linux用にする**方針とした。

### archinstall

`archinstall` を使用してインストール。

ネットワーク設定では当初Wi-Fiを使用しようとしたが接続できなかった。

Wi-Fi環境：

- Intel Wireless 7260
- インターフェース：`wlan0`
- ドライバ：`iwlwifi`
- `rfkill` に問題なし
- SSIDは検出可能
- `iwctl` で接続すると `Operation failed`
- iwdログに `invalid HE capabilities` が出ていた

Wi-Fi接続には時間がかかったため、**有線LANに切り替えた**。

有線インターフェース：

```text
enp0s25
```

有線接続後、`archinstall` のNetwork configurationで **NetworkManager** を選択。

### パーティション

`Partitioning` では、

**Use a best-effort default partition layout**

を選択。

対象ディスクは `/dev/sda`。

メインファイルシステムは **ext4**。

LVMおよびDisk encryptionは使用しない。

既存のWindowsパーティションは削除し、Arch専用ディスクとして構成。

### ユーザー設定

`User account` から通常ユーザーを作成。

sudo権限を付与。

root passwordを必須にするのではなく、**sudo権限を持つ通常ユーザーを使用する構成**とした。

### インストール完了

`Install` が `Ready` になったことを確認してインストール実行。

インストール完了後、

```text
Installation completed
```

を確認。

`Reboot system` を選択して再起動。

インストールUSBを抜き、内蔵ディスクからArch Linuxが起動することを確認。

### GUI

初回起動時はTTYの `login:` が表示された。

ログイン後、GUI環境がまだ起動していなかったため、Xfce / Xorg / LightDMを追加インストール。

```text
xorg
xfce4
lightdm
lightdm-gtk-greeter
```

を導入。

LightDMのログイン画面まで起動。

LightDMでは、パスワード入力後に **Enterではログインできなかったが、Loginボタンをクリックすると正常にログインできた**。

TTYでは同じユーザー名・パスワードで正常にログインできることも確認済み。

最終的に **XfceのGUIデスクトップが正常起動**。

### デスクトップ背景

`archlinux-wallpaper` をインストール。

Xfceの背景設定からArch Linuxの壁紙を選択。

現在は、

**中央にArch Linuxロゴ＋「Arch Linux」**

が表示される壁紙を使用。

### 現在の状態（2026-09-01時点）

- Windows：削除済み
- Arch Linux：インストール済み
- 内蔵ディスク：Arch専用
- Xfce：起動済み
- LightDM：起動済み
- 有線LAN：使用可能
- Wi-Fi：未解決
- 日本語キーボード設定：要調整
- sudoパスワード省略設定：未完了
- Xfce環境：基本的なGUI起動まで完了

### 次回やること（2026-09-01時点で予定していたこと）

1. 日本語キーボード配列を恒久設定
2. Wi-Fi（Intel Wireless 7260）の接続確認・必要なら対処
3. sudoのパスワード入力を省略する設定
4. Xfceの基本設定
5. 日本語入力（Mozc等）の設定
6. 必要なアプリケーションの導入
7. 不要なパッケージ・サービスの整理

---

## 本日の所感（2026-09-01）

WindowsからArch Linuxへの移行は完了。

特に、Wi-Fi接続でかなり時間を使ったが、有線LANへ切り替えることでインストールを完了できた。

**CF-LX3 + Arch Linux + Xfce がGUIで起動するところまで到達。**

今日はここまで。

---

## 反省点（2026-09-02〜03の作業を経て）

archinstallでXfce + sudoユーザーまで作成した直後の環境には、**dotfilesリポジトリのMakefileを動かす前提となる基本コマンドが一切入っていなかった**。具体的には以下がすべて未インストールだった。

- `git`
- `make`
- `wget`
- `nano`
- `vim`
- （その他、archinstallのデフォルトプロファイルでは`base`パッケージ群の最小構成のみが入り、`base-devel`相当は入らない）

このため、手順書通りに`git clone`から始めようとするたびに「コマンドが見つからない」で毎回つまずいた。加えて、

- **sudo**: archinstallでsudo権限付きユーザーを作成したはずが、実際にsudoコマンドを使う段になって権限周りで詰まる場面があった（wheelグループの有効化がされているか、`/etc/sudoers`の該当行がコメントアウトされたままか、要確認）
- **日本語フォント**: 初期状態ではCJKフォントが一切入っておらず、日本語が豆腐（文字化け）表示になっていた

これらは「dotfilesを使って環境を作る」という手順そのものより手前の、**OS標準インストール直後に手動で埋めるべき最小ギャップ**である。次回（あるいは別機での再インストール時）は、dotfilesリポジトリをcloneする前に、この最小ギャップを埋める工程を明示的な0段階として独立させておく。

## 改善版：0段階（dotfiles導入前の最小ブートストラップ）

archinstallでXfce + sudoユーザー作成が完了した直後、**dotfilesリポジトリに触れる前に**、TTYまたはXfceのターミナルから以下を実行する。

### 0-1. sudoが実際に使えるか確認

```bash
sudo -v
```

パスワード入力を求められ、エラーなく通ればOK。エラーが出る場合は、rootでログインし直して以下を確認・修正する。

```bash
# wheelグループに所属しているか確認
groups ${USER}

# 所属していなければ追加
usermod -aG wheel ${USER}

# /etc/sudoers で %wheel の行が有効化されているか確認
EDITOR=nano visudo
# 次の行の先頭コメント(#)が外れていることを確認
# %wheel ALL=(ALL:ALL) ALL
```

### 0-2. 基本コマンド群を導入

archinstallの最小構成には`base-devel`（gcc/make等のビルドツール一式）が含まれないため、明示的に入れる。

```bash
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm base-devel git wget nano vim networkmanager
```

`--needed`を付けることで、既に入っているパッケージはスキップされ、再実行しても安全。

### 0-3. 日本語フォント・ロケール確認

```bash
sudo pacman -S --needed --noconfirm noto-fonts-cjk noto-fonts-emoji
```

ロケールが`ja_JP.UTF-8`で生成・設定済みか確認（archinstall時点で未設定なら追加）。

```bash
locale -a | grep ja_JP
# 出力が無ければ
sudo sed -i 's/^#ja_JP.UTF-8/ja_JP.UTF-8/' /etc/locale.gen
sudo locale-gen
localectl set-locale LANG=ja_JP.UTF-8
```

### 0-4. ここまで終わったらdotfilesへ

上記0-1〜0-3が完了した時点で、初めて`git clone`以降のarch-dotfiles側のMakefile手順（`make base`等）に進む。dotfiles側の`make base`ターゲットにも、上記のうち`base-devel`/`git`/`wget`/`nano`/`vim`を含めて重複導入しておくと、0段階を飛ばして着手した場合の保険になる（`--needed`前提なので二重実行しても害はない）。
