#!/bin/bash
# ロゴ輝度制限を Apple 標準に戻す。
# com.apple.CoreBrightness の制限キー2つを削除し、corebrightnessd を再起動する。
set -euo pipefail

sudo defaults delete com.apple.CoreBrightness LEPWMLuxToMinNitsRestrictionMapping 2>/dev/null || true
sudo defaults delete com.apple.CoreBrightness LEPWMLuxToMaxNitsRestrictionMapping 2>/dev/null || true
sudo killall corebrightnessd
echo "制限を標準に戻しました (corebrightnessd 再起動済み)"
