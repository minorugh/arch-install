########################################################
### Arch Linuxインストール用USBメディア作成
# make-usb-arch.sh を実行し、USBメモリにArch Linuxイメージを書き込む。
# isoはisohybrid形式のためdd直書きでOK（Rufus/Ventoy等は不要）。
# Archはローリングリリースのため、ダウンロードURLが常に最新版を指す
# （固定名 archlinux-x86_64.iso）。バージョン確認という概念自体が無い。
########################################################

.PHONY: usb-arch fresh-arch

usb-arch: ##! 新規または予備のインストールメディアを作成する
	bash make-usb-arch.sh

fresh-arch: ##! 最新isoで作り直す（古いisoを削除後、make usb-arch を実行）
	@read -p "既存のisoを削除して最新版で作り直します。よろしいですか？ [y/N]: " ans; \
	if [ "$$ans" != "y" ] && [ "$$ans" != "Y" ]; then echo "中止しました。"; exit 1; fi
	rm -rf "$(HOME)/tmp/archiso"
	$(MAKE) usb-arch

# ------------------------------------------------------------
# [Read-only] This file opens in read-only mode automatically.
# Toggle editable: C-c C-e  or  qq
# タブ崩れなどの構文エラー確認（missing separator対策）
#   make -n >/dev/null
# ------------------------------------------------------------
# Local Variables:
# buffer-read-only: t
# End:
