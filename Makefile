### Arch Linux 環境構築 (Let's note CF-LX3 / Arch単独機)
# Debian機（P1/X250）とは完全に独立。dotfiles・SSH鍵・秘密鍵の共有は一切行わない。
# archinstallでXfce + sudoユーザー作成直後の「裸」の状態から動く前提で設計している
# （base-devel/git/wget/nano/vim/CJKフォント等, archinstallの最小構成には
#   一切入っていないため、bootstrap相当の内容を base に統合済み）。
#
# 前提: archinstall で Xfce + sudoユーザー作成済み、ネット接続済み
# 参考: docs/Arch_Linux_インストール作業記録.md の「改善版：0段階」
#       docs/arch-standalone-handover.md

########################################################
## 変数定義
########################################################
PACMAN       := sudo pacman -S --needed --noconfirm
AUR          := yay -S --needed --noconfirm
EMACS_VER    := 31.1

# 公式リポジトリで揃うもの（bootstrap相当を含む）
# emacsは含めない: emacs-stable でソースビルドする方針のため、
# pacman版と自家ビルド版の共存によるPATH競合・.eln-cacheの汚染を
# 構造的に避ける（詳細: docs/arch-standalone-handover.md 3章）
PACKAGES     := base-devel git wget nano vim networkmanager
PACKAGES     += noto-fonts-cjk noto-fonts-emoji ttf-nerd-fonts-symbols
PACKAGES     += zsh gnome-terminal openssh keychain chromium
PACKAGES     += fcitx5 fcitx5-configtool fcitx5-gtk fcitx5-qt

# 汎用開発ツール（アプリ系は含めない。GUIアプリは別途個別に判断する）
# sxiv は upstream終了・Arch公式から削除済みのため後継のnsxivを使用
# e2ps は不要と判明（EmacsのPS-print→CUPS直送のため変換ツールは要らない）
PACKAGES     += curl unarchiver unzip evince tig rsync xclip trash-cli
PACKAGES     += automake autoconf fzf nsxiv hugo xdotool nodejs npm
PACKAGES     += xfce4-screenshooter pinta keepassxc light-locker

# 未確定・保留
# - icons: 具体的に何のパッケージか要確認（アイコンテーマ名？）
# - gist: pacman/AURのパッケージではなくgemで入れるツールの可能性が高い。要確認

# AUR経由のみのもの
# fcitx5-mozc-ut + emacs-mozc: 分離型の組み合わせ。
# 公式版fcitx5-mozc（一体型）とemacs-mozcはファイル競合するため使わない
# （詳細: docs/arch-standalone-handover.md 4章）
# perl-net-sftp-foreign: upsftp.pl（GH共通デプロイ用）が要求するPerlモジュール
AUR_PACKAGES := dropbox fcitx5-mozc-ut emacs-mozc cmigemo arc-gtk-theme nkf
AUR_PACKAGES += perl-net-sftp-foreign onlyoffice-bin
AUR_PACKAGES += claude-desktop chatgpt-desktop

.DEFAULT_GOAL := help

########################################################
## エントリーポイント
########################################################
.PHONY: all help base yay aur sudo-setup zsh-default theme-setup emacs-stable ssh-setup github init git emacs-toggle emacs-start power-menu tile-toggle make-run

help: ## ターゲット一覧を表示
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

all: base sudo-setup yay aur zsh-default theme-setup ## base→sudo-setup→yay→aur→zsh-default→theme-setup を一括実行
# emacs-stable/ssh-setup/init はビルド時間・対話入力を伴うため手動で個別実行すること

########################################################
## 基本パッケージ（bootstrap統合）
########################################################
base: ## 基本パッケージ一括インストール（archinstall直後の裸環境から動く前提）
	sudo pacman -Syu --noconfirm
	$(PACMAN) $(PACKAGES)
	sudo sed -i 's/^#ja_JP.UTF-8/ja_JP.UTF-8/' /etc/locale.gen
	sudo locale-gen
	sudo localectl set-locale LANG=ja_JP.UTF-8
	sudo sed -i '/pam_gnome_keyring/d' /etc/pam.d/lightdm /etc/pam.d/lightdm-autologin 2>/dev/null || true
	@echo "✓ 基本パッケージ・日本語ロケールの導入完了"
	@echo "  PAMのgnome-keyring自動起動（keychainと衝突する）は無効化済み"
	@echo "  もし sudo でここまで到達できなかった場合は README.md の"
	@echo "  「sudoが効かないとき」を参照してください"

########################################################
## AURヘルパー・AURパッケージ
########################################################
yay: ##! AURヘルパー(yay)をソースからビルドしてインストール
	rm -rf /tmp/yay
	git clone https://aur.archlinux.org/yay.git /tmp/yay
	cd /tmp/yay && makepkg -si --noconfirm
	rm -rf /tmp/yay

aur: ##! AUR経由でdropbox・fcitx5-mozc-ut・emacs-mozc・cmigemo・arc-gtk-theme・nkf・perl-net-sftp-foreignをインストール（対話プロンプトあり）
	$(AUR) $(AUR_PACKAGES)
	sudo pacman -Rdd --noconfirm emacs 2>/dev/null || true
	sudo sed -i '/pam_gnome_keyring/d' /etc/pam.d/lightdm /etc/pam.d/lightdm-autologin 2>/dev/null || true
	@echo "✓ emacs-mozcの依存で入るpacman版emacsは自動除去しました（自家ビルド版のみ残す）"
	@echo "✓ PAMのgnome-keyring自動起動（keychainと衝突する）は無効化済み"
# 導入後、メニューからDropboxを起動して初期設定・同期を行うこと

########################################################
## システム設定
########################################################
sudo-setup: ## sudoグループ(wheel)の有効化
	sudo sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
	sudo usermod -aG wheel $$USER
	@echo "✓ wheelグループのsudoを有効化しました。反映には再ログインが必要です。"

zsh-default: ## ログインシェルをzshに変更
	sudo chsh -s /usr/bin/zsh $$USER
	@echo "✓ 次回ログインからzshが有効になります。"

theme-setup: ## ウィンドウマネージャーと外観を Arc-Dark に変更
	xfconf-query -c xfwm4 -p "/general/theme" -n -t string -s "Arc-Dark"
	xfconf-query -c xfce4-appearance -p "/theme" -n -t string -s "Arc-Dark"
	@echo "✓ ウィンドウ枠(xfwm4)と外観テーマを Arc-Dark に自動設定しました"

########################################################
## Emacs 自家ビルド
########################################################
emacs-stable: ##! Emacs $(EMACS_VER) のソースビルド（依存パッケージも一括導入）
	sudo pacman -S --needed --noconfirm \
	  base-devel autoconf texinfo pkgconf \
	  gnutls jansson harfbuzz libxml2 gtk3 libgccjit \
	  ncurses sqlite tree-sitter \
	  libjpeg-turbo libpng giflib libtiff librsvg libxpm zlib
	mkdir -p ~/src
	cd ~/src && \
	wget -c https://ftpmirror.gnu.org/emacs/emacs-$(EMACS_VER).tar.gz && \
	tar xvfz emacs-$(EMACS_VER).tar.gz && \
	cd emacs-$(EMACS_VER) && \
	./configure \
	  --with-native-compilation=aot \
	  --with-x-toolkit=gtk3 \
	  --without-xim \
	  --without-gsettings \
	  --without-dbus \
	  --without-toolkit-scroll-bars \
	  --without-imagemagick \
	  --without-mailutils \
	  --without-pop \
	  --without-gpm \
	  --without-selinux \
	  --without-compress-install && \
	NATIVE_FULL_AOT=1 make -j$(shell nproc) && \
	sudo make install
	sudo sed -i 's|^Exec=emacs %F|Exec=/usr/local/bin/emacs-start.sh|' /usr/local/share/applications/emacs.desktop
	@echo "✓ Emacs $(EMACS_VER) を /usr/local/bin/emacs にインストールしました"
	@echo "  アンインストール: ~/src/emacs-$(EMACS_VER) で sudo make uninstall && make distclean"

########################################################
## SSH鍵（Let's note専用に新規生成。Debian機の鍵は流用しない）
########################################################
ssh-setup: ##! SSH鍵を新規生成し、GitHub登録・keychain設定までを案内する
	mkdir -p ~/.ssh
	test -f ~/.ssh/id_ed25519_arch || ssh-keygen -t ed25519 -N "" -C "archlinux-cf-lx3" -f ~/.ssh/id_ed25519_arch
	@echo ""
	@echo "1) 以下の公開鍵をGitHubに登録してください"
	@echo "   Settings > SSH and GPG keys > New SSH key"
	@echo "----------------------------------------------------------"
	@cat ~/.ssh/id_ed25519_arch.pub
	@echo "----------------------------------------------------------"
	@echo "2) 登録できたら ~/.ssh/config に以下を追記してください"
	@echo ""
	@echo "Host github.com"
	@echo "    HostName github.com"
	@echo "    User git"
	@echo "    IdentityFile ~/.ssh/id_ed25519_arch"
	@echo "    IdentitiesOnly yes"
	@echo ""
	@echo "3) 追記できたら次を実行してください"
	@echo "   keychain ~/.ssh/id_ed25519_arch && ssh -T git@github.com"

########################################################
## bin/ スクリプト（シンボリックリンク＋xfconf-queryショートカット登録）
# P1由来のdotfiles（~/src/github.com/minorugh/dotfiles）を参照する。
# このリポジトリ自身にはbin/実体を持たない。
########################################################
DOTFILES_DIR := $(HOME)/src/github.com/minorugh/dotfiles
BIN_LINK = sudo ln -vsfn $(DOTFILES_DIR)/bin/$(1) /usr/local/bin/$(2) && sudo chmod +x /usr/local/bin/$(2)

emacs-toggle: ## emacs-toggle のリンク作成 + F12ショートカット登録（Emacs最小化・復元）
	$(call BIN_LINK,emacs-toggle,emacs-toggle)
	xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/F12" -n -t string -s "emacs-toggle"

emacs-start: ## emacs-start.sh のリンク作成（autostart.sh から呼ばれる起動ラッパー）
	$(call BIN_LINK,emacs-start.sh,emacs-start.sh)

power-menu: ## power-menu.sh のリンク作成 + 全角半角ショートカット登録（電源メニュー）
	$(call BIN_LINK,power-menu.sh,power-menu.sh)
	xfconf-query -c xfce4-keyboard-shortcuts \
		-p "/commands/custom/Zenkaku_Hankaku" -n -t string \
		-s 'gnome-terminal --window --geometry=80x24+2000+100 -- bash -c "power-menu.sh"'

tile-toggle: ## tile-toggle.sh のリンク作成 + F15ショートカット登録（左右タイル切替）
	$(call BIN_LINK,tile-toggle.sh,tile-toggle)
	xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/F15" -n -t string -s "tile-toggle"

make-run: ## make-run.sh のリンク作成（Emacs経由のmake実行を安全化）
	$(call BIN_LINK,make-run.sh,make-run.sh)

########################################################
## dotfiles(P1由来)のclone
########################################################
github: ## dotfilesリポジトリをHTTPSでclone（初回のみ。以降はgit pullで更新）
	mkdir -p $(HOME)/src/github.com/minorugh
	git clone https://github.com/minorugh/dotfiles.git $(DOTFILES_DIR)
	@echo "✓ dotfiles を clone しました（編集・pushはP1のみ、Archはpull専用）"

########################################################
## dotfiles展開（P1由来。~/src/github.com/minorugh/dotfiles を
## 事前にcloneしておくこと。編集・pushはP1のみ、Archはpull専用）
########################################################
init: ## dotfiles(P1由来)をシンボリックリンク展開
	for item in zshrc Xmodmap gitconfig vimrc; do \
		test -f $(DOTFILES_DIR)/.$$item && ln -vsf $(DOTFILES_DIR)/.$$item $(HOME)/.$$item; \
	done
	test -L $(HOME)/.emacs.d || rm -rf $(HOME)/.emacs.d
	ln -vsfn $(DOTFILES_DIR)/.emacs.d $(HOME)/.emacs.d
	@echo "✓ dotfiles(P1由来)を展開しました"

latex: ## Arch Linux 用の LaTeX 環境構築とシンボリックリンク作成
	sudo pacman -S --needed --noconfirm texlive-basic texlive-bin texlive-latex texlive-langjapanese
	sudo ln -vsfn $(DOTFILES_DIR)/tex/dvpd.sh /usr/local/bin
	sudo chmod +x /usr/local/bin/dvpd.sh
	sudo mkdir -p /usr/share/texmf-dist/tex/platex
	sudo ln -vsfn $(DOTFILES_DIR)/tex/platex/my-sty /usr/share/texmf-dist/tex/platex/
	sudo mktexlsr
	sudo fmtutil-sys --byfmt platex
	sudo fmtutil-sys --byfmt uplatex

########################################################
## arch-install自身のcommit・push
## （dotfiles/git/Makefile の archlinux 分岐から呼ばれる）
########################################################
git: ## commit・push（arch-installはArch機がメインなので常にpush）
	git add -A
	git diff --cached --quiet || git commit -m "auto: $$(date '+%Y-%m-%d %H:%M:%S')"
	git push

# ------------------------------------------------------------
# [Read-only] This file opens in read-only mode automatically.
# Toggle editable: C-c C-e  or  qq
# タブ崩れなどの構文エラー確認（missing separator対策）
#   make -n >/dev/null
# ------------------------------------------------------------
# Local Variables:
# buffer-read-only: t
# End:
