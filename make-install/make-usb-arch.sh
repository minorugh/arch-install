#!/bin/bash
set -e

ISO_DIR="$HOME/tmp/archiso"
mkdir -p "${ISO_DIR}"

mapfile -t iso_files < <(find "${ISO_DIR}" -maxdepth 1 -name 'archlinux-x86_64.iso' | sort)

if [ "${#iso_files[@]}" -eq 0 ]; then
  echo "isoが見つからないため、ダウンロードします（数分かかります）。"
  cd "${ISO_DIR}"
  wget https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso
  wget https://geo.mirror.pkgbuild.com/iso/latest/sha256sums.txt
  if ! sha256sum --ignore-missing -c sha256sums.txt; then
    echo "検証に失敗しました。isoが壊れている可能性があります。"
    echo "${ISO_DIR}/archlinux-x86_64.iso を削除してから、もう一度実行してください。"
    exit 1
  fi
  ISO_PATH="${ISO_DIR}/archlinux-x86_64.iso"
else
  ISO_PATH="${iso_files[0]}"
  echo "既存のisoを使用します: ${ISO_PATH}"
fi

mapfile -t usb_disks < <(lsblk -d -b -o NAME,SIZE,MODEL,TRAN -n | awk '{
  tran = $NF
  size = $2
  if (tran == "usb" && size + 0 > 0) {
    name = $1
    model = ""
    for (i = 3; i < NF; i++) {
      model = (model == "") ? $i : model " " $i
    }
    print name "|" size "|" model
  }
}')

usb_count=${#usb_disks[@]}

if [ "$usb_count" -eq 0 ]; then
  echo "USBが検出されませんでした。USBメモリが挿さっているか確認してください。"
  exit 1
fi

if [ "$usb_count" -ge 2 ]; then
  echo "USBが複数検出されました。安全のため処理を中止します。"
  echo "他のUSB機器を外し、書き込み先のUSBだけを挿した状態でやり直してください。"
  printf '検出されたUSB:\n'
  for entry in "${usb_disks[@]}"; do
    IFS='|' read -r name size model <<< "$entry"
    human_size=$(numfmt --to=iec --suffix=B "${size}")
    printf '  /dev/%s  %s  %s\n' "$name" "$human_size" "$model"
  done
  exit 1
fi

IFS='|' read -r name size model <<< "${usb_disks[0]}"
target="/dev/${name}"
human_size=$(numfmt --to=iec --suffix=B "${size}")

echo "検出されたUSB: ${target}  サイズ: ${human_size}  モデル: ${model}"
echo "このUSBの中身は全て消去され、Arch Linuxインストールメディアになります。"
read -r -p "このUSBに書き込みますか？ [y/N]: " answer

if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
  echo "中止しました。何も変更していません。"
  exit 1
fi

echo "書き込み中です。完了まで数十秒〜数分かかります。途中で操作しないでください..."
sudo dd if="${ISO_PATH}" of="${target}" bs=4M status=progress conv=fsync
echo "書き込みが完了しました。"
