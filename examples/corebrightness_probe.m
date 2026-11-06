// corebrightness_probe.m
// CoreBrightness (プライベートFW) の BrightnessSystemClient 経由で
// ロゴ関連キー LEPWM* の現在値を読み取る検査用コード。書き込みは行わない。
//
// ビルド: clang -framework Foundation corebrightness_probe.m -o corebrightness_probe
// 実行:   ./corebrightness_probe
//
// 注意: プライベートフレームワークのため App Store 配布不可。
//       クラス名・キー名は macOS の版で変わり得るので実行時チェックを入れてある。

#import <Foundation/Foundation.h>
#import <dlfcn.h>

int main(void) {
    @autoreleasepool {
        void *handle = dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness",
                              RTLD_NOW);
        if (!handle) {
            NSLog(@"CoreBrightness を開けませんでした: %s", dlerror());
            return 1;
        }

        Class clientClass = NSClassFromString(@"BrightnessSystemClient");
        if (!clientClass) {
            NSLog(@"BrightnessSystemClient クラスが見つかりません");
            return 1;
        }

        id client = [[clientClass alloc] init];
        SEL copySel = NSSelectorFromString(@"copyPropertyForKey:");
        if (![client respondsToSelector:copySel]) {
            NSLog(@"copyPropertyForKey: がありません");
            return 1;
        }

        NSArray<NSString *> *keys = @[
            @"LEPWMBrightnessNitsMapping",
            @"LEPWMFactorFadeDuration",
            @"LEPWMLuxToMinNitsRestrictionMapping",
            @"LEPWMLuxToMaxNitsRestrictionMapping",
        ];
        for (NSString *key in keys) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            id value = [client performSelector:copySel withObject:key];
#pragma clang diagnostic pop
            NSLog(@"%@ = %@", key, value ?: @"(nil)");
        }

        // 書き込みを行う場合は setProperty:forKey: を使う:
        //   [client performSelector:NSSelectorFromString(@"setProperty:forKey:")
        //                withObject:<新しいマッピング値>
        //                withObject:@"LEPWMBrightnessNitsMapping"];
        // 対象指定には appleLogoMapping が関係する。値の形式は copyPropertyForKey:
        // で取得した現在値の構造をそのまま踏襲すること。
    }
    return 0;
}
