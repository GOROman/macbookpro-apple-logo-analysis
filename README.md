# MacBook Pro Appleロゴ バックライト解析と制御方法

PROLED XDRディスプレイ搭載 MacBook Pro（2026年モデル）の天板Appleロゴ発光について、ハードウェア構成とmacOS側の制御経路を解析し、プログラムから制御する方法をまとめた技術資料。

> 本資料は解析に基づく技術情報であり、対象実機での全操作の動作保証はしていない。プライベートフレームワークおよびシステム設定の書き換えを含むため、実施は自己責任で。App Store配布アプリでは使用できない手法を含む。

## 1. 対象ハードウェア

- 発光ロゴを持つのは PROLED XDRディスプレイ搭載 MacBook Pro のみ
- 機種判定は `sysctl hw.model` のモデル識別子で行う

| モデル識別子 |
|---|
| Mac17,10 |
| Mac17,11 |
| Mac17,12 |
| Mac17,13 |

上記以外（Mac Studio等のデスクトップ機を含む）にはロゴバックライト自体が存在しない。

## 2. ハードウェア構成（解析結果）

天板ロゴは内蔵ディスプレイのバックライトとは**独立したPWMチャンネル**を持つ専用バックライトである。

- IOレジストリ上のデバイスツリーパス:

```
IODeviceTree:/arm-io/pwm1/bklb-backlight
```

- `IORegistryEntryFromPath` でこのエントリを開き、`IORegistryEntryCreateCFProperties` で現在のプロパティ（輝度マッピング、フェード時間など）を読み取れる（→ [examples/inspect_logo_backlight.swift](examples/inspect_logo_backlight.swift)）
- 輝度の実体制御は macOS の輝度管理デーモン `corebrightnessd` が担い、後述の CoreBrightness 経由で指示する

## 3. 制御方法

### 3.1 本命: CoreBrightness（プライベートFW）経由

`/System/Library/PrivateFrameworks/CoreBrightness.framework` を実行時に `dlopen` し、`BrightnessSystemClient` クラスの `setProperty:forKey:` / `copyPropertyForKey:` を使う。

ロゴ関連のキー（文字列定数）:

| キー | 意味 |
|---|---|
| `LEPWMBrightnessNitsMapping` | ロゴ輝度（nits）へのマッピング本体。対象指定は `appleLogoMapping` |
| `LEPWMFactorFadeDuration` | 輝度変化時のフェード時間 |
| `LEPWMLuxToMinNitsRestrictionMapping` | 周囲照度に対する最小nits制限（後述） |
| `LEPWMLuxToMaxNitsRestrictionMapping` | 周囲照度に対する最大nits制限（後述） |

要点:

- ロゴ輝度は画面輝度とは別系統で設定できる。画面輝度を一切変更せずロゴだけを制御可能
- フェード付きで輝度を書き換えると、旧MacBookのスリープランプのような呼吸（ブリーズ）表現が作れる
- 設定はデーモン側で解釈されるため、制御プロセスが終了すれば原則としてシステム標準の振る舞いに戻る（永続化される設定については §4 を参照）

ObjCからの利用イメージは [examples/corebrightness_probe.m](examples/corebrightness_probe.m) を参照。

### 3.2 フォールバック: DisplayServices + ガンマテーブル

- `/System/Library/PrivateFrameworks/DisplayServices.framework` を `dlopen` し、`DisplayServicesSetBrightness` / `DisplayServicesGetBrightness` を `dlsym` で解決する方式も併用可能
- さらに細かい制御では `CGGetDisplayTransferByTable` / `CGSetDisplayTransferByTable` によるガンマテーブルのスケーリングを組み合わせる
- ただしこの経路はディスプレイ全体の輝度系に触れるため、ロゴ単独制御の精度では §3.1 に劣る

### 3.3 輝度をパターンで動かす

輝度値をタイマーで時系列に書き換えることで以下のような表現が可能（いずれも輝度制御のみで実現できる）:

- 定常点灯（任意の輝度で保持）
- 呼吸（サイン波等でゆっくり上下）
- 点滅（矩形波、ダブルブリンク等）
- 音に合わせた点灯（システム再生音のレベル取得には Core Audio のプロセスタップ `AudioHardwareCreateProcessTap` を使う。マイク入力は不要）

## 4. 周囲光による輝度制限と、その解除

macOSは周囲照度（ALS）に応じてロゴ輝度を制限する:

- 暗い部屋では上限が約1/3にキャップされる
- 明るい部屋では下限が持ち上げられ、暗くできない

この制限はドメイン `com.apple.CoreBrightness` の2キーで定義されており、書き換えには管理者権限が要る。

| キー | 役割 |
|---|---|
| `LEPWMLuxToMinNitsRestrictionMapping` | 照度→最小nits の対応表 |
| `LEPWMLuxToMaxNitsRestrictionMapping` | 照度→最大nits の対応表 |

解除の考え方:

- Min側マッピングを下限なし（0）側に、Max側マッピングを事実上無制限（`3.4e38` 級の大きな値）側に書き換え、`corebrightnessd` を再起動して反映する

```sh
# 実施前に必ず現在値を保存すること（§5参照）
sudo defaults write com.apple.CoreBrightness LEPWMLuxToMinNitsRestrictionMapping -array \
  '<array><real>0</real><real>0</real></array>' \
  '<array><real>3.4e38</real><real>0</real></array>'
sudo defaults write com.apple.CoreBrightness LEPWMLuxToMaxNitsRestrictionMapping -array \
  '<array><real>0</real><real>3.4e38</real></array>' \
  '<array><real>3.4e38</real><real>3.4e38</real></array>'
sudo killall corebrightnessd
```

※ マッピング配列の正確な要素構成は実機の現在値（次節）を読み取ってから合わせること。上記は値の方向性（Min=0 / Max=∞）を示すための形式例。

スクリプト版: [examples/remove_brightness_limit.sh](examples/remove_brightness_limit.sh) / 復旧は [examples/restore_brightness_limit.sh](examples/restore_brightness_limit.sh)

## 5. 現在値の読み取りと復旧

書き換え前に現在値を必ず控える:

```sh
defaults read com.apple.CoreBrightness LEPWMLuxToMinNitsRestrictionMapping
defaults read com.apple.CoreBrightness LEPWMLuxToMaxNitsRestrictionMapping
```

制限をApple標準に戻すには、2キーを削除してデーモンを再起動するだけでよい:

```sh
sudo defaults delete com.apple.CoreBrightness LEPWMLuxToMinNitsRestrictionMapping
sudo defaults delete com.apple.CoreBrightness LEPWMLuxToMaxNitsRestrictionMapping
sudo killall corebrightnessd
```

## 6. 実装上の注意

- 対象機種以外では IOレジストリの `pwm1/bklb-backlight` 自体が存在しない。制御前に `hw.model` とエントリの有無で判定すること
- 画面スリープ・画面ロック・低電力モード中は制御を止めるのが無難（デーモン側の状態遷移と競合しやすい）
- ロゴを完全に消灯した状態は、制御側の設定次第でプロセス終了後も維持される。復帰手段（再点灯の経路）を必ず用意しておくこと
- `corebrightnessd` の再起動は画面輝度など他の輝度管理にも影響する瞬断を伴う
- プライベートフレームワークのクラス名・キー名は macOS のアップデートで変わり得る。実行時に存在チェックをしてから使うこと

## 7. 解析手法メモ

- IOレジストリ探索: `ioreg -l -r -d 1` およびデバイスツリー (`IODeviceTree`) の走査で `pwm1/bklb-backlight` を特定
- CoreBrightness のキー群は、同フレームワークが扱う `LEPWM` プレフィックスのプロパティから抽出
- 制限マッピングは `com.apple.CoreBrightness` ドメインの実在キーとして確認。書き換え＋ `killall corebrightnessd` で反映される
