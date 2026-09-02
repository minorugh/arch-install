### Arch Linux 環境構築 (Let's note CF-LX3 / Arch単独機)
# Debian機（P1/X250）とは完全に独立。dotfiles・SSH鍵・秘密鍵の共有は一切行わない。
# archinstallでXfce + sudoユーザー作成直後の「裸」の状態から動く前提で設計している
# （base-devel/git/wget/nano/vim/CJKフォント等、archinstallの最小構成には
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
PACKAGES     += noto-fonts-cjk noto-fonts-emoji
PACKAGES     += zsh gnome-terminal openssh keychain chromium
PACKAGES     += fcitx5 fcitx5-configtool fcitx5-gtk fcitx5-qt

# AUR経由のみのもの
# fcitx5-mozc-ut + emacs-mozc: 分離型の組み合わせ。
# 公式版fcitx5-mozc（一体型）とemacs-mozcはファイル競合するため使わない
# （詳細: docs/arch-standalone-handover.md 4章）
AUR_PACKAGES := dropbox fcitx5-mozc-ut emacs-mozc

.DEFAULT_GOAL := help

########################################################
## エントリーポイント
########################################################
.PHONY: all help base yay aur sudo-setup zsh-default emacs-stable ssh-setup init

help: ## ターゲット一覧を表示
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

all: base sudo-setup yay aur zsh-default ## base→sudo-setup→yay→aur→zsh-default を一括実行
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
	@echo "✓ 基本パッケージ・日本語ロケールの導入完了"
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

aur: ##! AUR経由でdropbox・fcitx5-mozc-ut・emacs-mozcをインストール（対話プロンプトあり）
	$(AUR) $(AUR_PACKAGES)
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
	@echo "✓ Emacs $(EMACS_VER) を /usr/local/bin/emacs にインストールしました"
	@echo "  アンインストール: ~/src/emacs-$(EMACS_VER) で sudo make uninstall && make distclean"

########################################################
## SSH鍵（Let's note専用に新規生成。Debian機の鍵は流用しない）
########################################################
ssh-setup: ##! SSH鍵を新規生成し、GitHub登録・keychain設定までを案内する
	mkdir -p ~/.ssh
	test -f ~/.ssh/id_ed25519_arch || ssh-keygen -t ed25519 -C "archlinux-cf-lx3" -f ~/.ssh/id_ed25519_arch
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
## dotfiles展開（このリポジトリ自身のもののみ。P1のdotfilesは参照しない）
########################################################
init: ## dotfiles/ 配下をシンボリックリンク展開
	for item in zshrc vimrc gitconfig; do \
		ln -vsf $(CURDIR)/dotfiles/.$$item $(HOME)/.$$item; \
	done
	@echo "✓ dotfilesを展開しました"
	@echo "  .gitconfig の user.name / user.email は各自書き換えてください"

# ------------------------------------------------------------
# [Read-only] This file opens in read-only mode automatically.
# Toggle editable: C-c C-e  or  qq
# タブ崩れなどの構文エラー確認（missing separator対策）
#   make -n >/dev/null
# ------------------------------------------------------------
# Local Variables:
# buffer-read-only: t
# End:
