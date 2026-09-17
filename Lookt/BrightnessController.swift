import CoreGraphics
import IOKit

/// Temporarily maxes screen brightness during a Face ID attempt (acts as
/// a poor-man's fill light on Macs without an IR illuminator) and restores
/// the user's original setting afterward.
///
/// Note: there's no fully public, sandbox-friendly API for reading/setting
/// display brightness on Apple Silicon Macs. The common approach is the
/// `DisplayServices` private framework (used by tools like `brightness`
/// CLI) via dlopen, or shelling out to a helper binary. Because this
/// touches private APIs, it may need Apple to grant an entitlement
/// exception, or you keep it as a "best effort" feature that no-ops
/// gracefully if unavailable — don't let it block core auth if it fails.
final class BrightnessController {
    private var originalBrightness: Float?

    func maxOutBrightness() {
        originalBrightness = Self.currentBrightness()
        Self.setBrightness(1.0)
    }

    func restore() {
        guard let original = originalBrightness else { return }
        Self.setBrightness(original)
        originalBrightness = nil
    }

    // MARK: - DisplayServices bridging (private API — best effort only)

    private typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightnessFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static func currentBrightness() -> Float {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW),
              let sym = dlsym(handle, "DisplayServicesGetBrightness") else { return 0.7 }
        let fn = unsafeBitCast(sym, to: GetBrightnessFn.self)
        var brightness: Float = 0.7
        _ = fn(CGMainDisplayID(), &brightness)
        return brightness
    }

    private static func setBrightness(_ value: Float) {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW),
              let sym = dlsym(handle, "DisplayServicesSetBrightness") else { return }
        let fn = unsafeBitCast(sym, to: SetBrightnessFn.self)
        _ = fn(CGMainDisplayID(), value)
    }
}
