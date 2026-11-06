// inspect_logo_backlight.swift
// 天板ロゴ用PWMバックライト (IODeviceTree:/arm-io/pwm1/bklb-backlight) の
// プロパティを読み取って表示するだけの検査用コード。
// 対象機種以外ではエントリが存在せず、その旨を表示して終了する。
//
// ビルド: swiftc inspect_logo_backlight.swift -o inspect_logo_backlight
// 実行:   ./inspect_logo_backlight

import Foundation
import IOKit

// 対象機種判定 (sysctl hw.model)
func machineModel() -> String {
    var size = 0
    sysctlbyname("hw.model", nil, &size, nil, 0)
    var buf = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.model", &buf, &size, nil, 0)
    return String(cString: buf)
}

let supportedModels = ["Mac17,10", "Mac17,11", "Mac17,12", "Mac17,13"]
let model = machineModel()
print("hw.model: \(model)")
if !supportedModels.contains(model) {
    print("この機種には発光ロゴバックライトはありません (対象外モデル)")
}

let path = "IODeviceTree:/arm-io/pwm1/bklb-backlight"
let entry = IORegistryEntryFromPath(kIOMainPortDefault, path)
guard entry != IO_OBJECT_NULL else {
    print("エントリが見つかりません: \(path)")
    exit(0)
}
defer { IOObjectRelease(entry) }

var unmanagedProps: Unmanaged<CFMutableDictionary>?
let kr = IORegistryEntryCreateCFProperties(entry, &unmanagedProps, kCFAllocatorDefault, 0)
guard kr == KERN_SUCCESS, let props = unmanagedProps?.takeRetainedValue() as? [String: Any] else {
    print("プロパティ取得に失敗: kr=\(kr)")
    exit(1)
}

print("--- \(path) ---")
for key in props.keys.sorted() {
    print("\(key) = \(props[key]!)")
}
