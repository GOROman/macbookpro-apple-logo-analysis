#!/bin/bash
# 周囲光によるロゴ輝度制限 (com.apple.CoreBrightness) を解除する。
# Min側マッピングを 0 に、Max側マッピングを事実上無制限 (3.4e38) に倒し、
# corebrightnessd を再起動して反映する。
#
# 注意:
# - 管理者権限が必要
# - 配列の正確な要素構成は機種/版で異なり得る。先に現在値を読み、
#   構造を合わせてから実行すること (README §4/§5)
# - 復旧は restore_brightness_limit.sh (キー削除) で行える
set -euo pipefail

echo "現在の値を保存します: ~/corebrightness-backup-$(date +%Y%m%d-%H%M%S).txt"
defaults read com.apple.CoreBrightness > ~/corebrightness-backup-$(date +%Y%m%d-%H%M%S).txt 2>/dev/null || true

sudo defaults write com.apple.CoreBrightness LEPWMLuxToMinNitsRestrictionMapping -array \
  '<array><real>0</real><real>0</real></array>' \
  '<array><real>3.4e38</real><real>0</real></array>'

sudo defaults write com.apple.CoreBrightness LEPWMLuxToMaxNitsRestrictionMapping -array \
  '<array><real>0</real><real>3.4e38</real></array>' \
  '<array><real>3.4e38</real><real>3.4e38</real></array>'

sudo killall corebrightnessd
echo "制限を解除しました (corebrightnessd 再起動済み)"
