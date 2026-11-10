import Cocoa
import ApplicationServices

// IKB-blue circle cursor that morphs by context (dot / ring over buttons / bar over text fields).
// Replaces all system cursors with transparent ones (private CGS API) and draws the circle in an overlay window.
@_silgen_name("CGSMainConnectionID") func CGSMainConnectionID() -> Int32
@_silgen_name("CGSSetConnectionProperty") func CGSSetConnectionProperty(_ c: Int32, _ t: Int32, _ k: CFString, _ v: CFTypeRef) -> Int32

@_silgen_name("CGCursorIsVisible") func cursorVisible() -> Int32

@_silgen_name("CoreCursorSet") func CoreCursorSet(_ cid: Int32, _ id: Int32) -> Int32
@_silgen_name("CGSSetRegisteredCursor") func CGSSetRegisteredCursor(_ cid: Int32, _ name: UnsafeMutablePointer<CChar>, _ seed: UnsafeMutablePointer<Int32>) -> Int32
@_silgen_name("CGSSetDockCursorOverride") func CGSSetDockCursorOverride(_ cid: Int32, _ flag: Bool)
@_silgen_name("CGSSetCursorScale") func CGSSetCursorScale(_ cid: Int32, _ s: Float) -> Int32
@_silgen_name("CGSGetCursorScale") func CGSGetCursorScale(_ cid: Int32, _ s: UnsafeMutablePointer<Float>) -> Int32
@_silgen_name("CGSSetSystemDefinedCursor") func CGSSetSystemDefinedCursor(_ cid: Int32, _ c: Int32) -> Int32
@_silgen_name("CoreCursorUnregisterAll") func CoreCursorUnregisterAll(_ cid: Int32) -> Int32
@_silgen_name("CGSRegisterCursorWithImages") func CGSRegisterCursorWithImages(_ cid: Int32, _ name: UnsafeMutablePointer<CChar>, _ setGlobally: Bool, _ instantly: Bool, _ size: NSSize, _ hotspot: CGPoint, _ frames: UInt, _ dur: CGFloat, _ imgs: CFArray, _ seed: UnsafeMutablePointer<Int32>) -> Int32

enum Shape { case dot, link, text, press }
let ikb = NSColor(srgbRed: 0, green: 0x2F/255.0, blue: 0xA7/255.0, alpha: 1).cgColor
let S: CGFloat = 80  // window size
let textRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField", "AXSecureTextField"]
let linkRoles: Set<String> = ["AXButton", "AXLink", "AXMenuItem", "AXMenuBarItem", "AXCheckBox", "AXRadioButton", "AXPopUpButton", "AXTab", "AXDisclosureTriangle", "AXMenuButton"]

NSApplication.shared.setActivationPolicy(.accessory)
let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: S, height: S), styleMask: .borderless, backing: .buffered, defer: false)
win.isOpaque = false; win.backgroundColor = .clear; win.hasShadow = false; win.ignoresMouseEvents = true
win.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
win.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
let view = NSView(frame: NSRect(x: 0, y: 0, width: S, height: S)); view.wantsLayer = true
win.contentView = view
let dot = CALayer(); dot.position = CGPoint(x: S/2, y: S/2); dot.backgroundColor = ikb
view.layer!.addSublayer(dot)
win.orderFrontRegardless()

var shape: Shape = .dot
func apply(_ s: Shape) {
    guard s != shape else { return }; shape = s
    let (w, h, a): (CGFloat, CGFloat, Float) = { switch s {
        case .dot: return (14, 14, 1); case .link: return (20, 20, 0.85)
        case .text: return (3, 22, 1); case .press: return (9, 9, 1) } }()
    CATransaction.begin(); CATransaction.setAnimationDuration(0.18)
    CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.1))
    dot.bounds = CGRect(x: 0, y: 0, width: w, height: h); dot.cornerRadius = min(w, h) / 2; dot.opacity = a
    CATransaction.commit()
}
dot.bounds = CGRect(x: 0, y: 0, width: 14, height: 14); dot.cornerRadius = 7

let cid = CGSMainConnectionID()
func showCursor() { _ = CoreCursorUnregisterAll(cid); CGSSetDockCursorOverride(cid, false) }
var sources: [DispatchSourceSignal] = []
for sig in [SIGINT, SIGTERM] { signal(sig, SIG_IGN); let s = DispatchSource.makeSignalSource(signal: sig); s.setEventHandler { showCursor(); exit(0) }; s.resume(); sources.append(s) }

// Make every system cursor fully transparent (the overlay circle replaces it). Undone on exit / `--restore`.
func makeInvisible() {
    let cs = CGColorSpaceCreateDeviceRGB()
    func clear(_ n: Int) -> CGImage { CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()! }
    let imgs = [clear(32), clear(64)] as CFArray
    let cg = ["Arrow", "ArrowS", "IBeam", "IBeamS", "Alias", "Move", "Wait", "Copy", "NotAllowed", "OpenHand", "ClosedHand", "PointingHand", "ArrowCtx", "CountingUpHand", "CountingDownHand", "CountingUpAndDownHand", "ResizeLeft", "ResizeRight", "ResizeLeftRight", "ResizeUp", "ResizeDown", "ResizeUpDown", "ScreenshotWindow", "ScreenshotSelection"].map { "com.apple.coregraphics." + $0 }
    let names = cg + (0...43).map { "com.apple.cursor.\($0)" }
    _ = CoreCursorUnregisterAll(cid)
    for i in 0...43 { _ = CoreCursorSet(cid, Int32(i)) }
    var seed: Int32 = 0
    for n in names {
        let p = strdup(n)!; defer { free(p) }
        _ = CGSRegisterCursorWithImages(cid, p, true, true, NSSize(width: 32, height: 32), .zero, 1, 0, imgs, &seed)
        _ = CGSSetRegisteredCursor(cid, p, &seed)
    }
    CGSSetDockCursorOverride(cid, true)
    var sc: Float = 1; if CGSGetCursorScale(cid, &sc) == 0 { _ = CGSSetCursorScale(cid, sc + 0.1); _ = CGSSetCursorScale(cid, sc) }
    _ = CGSSetSystemDefinedCursor(cid, 0)
}
if CommandLine.arguments.contains("--restore") { _ = CoreCursorUnregisterAll(cid); CGSSetDockCursorOverride(cid, false); exit(0) }
makeInvisible()

let trusted = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
var lastPid: pid_t = 0
let sys = AXUIElementCreateSystemWide(); AXUIElementSetMessagingTimeout(sys, 0.05)
let primaryH = NSScreen.screens[0].frame.height
var lastP = NSPoint.zero, idle = 0
var ctx: Shape = .dot, tick = 0, debug = CommandLine.arguments.contains("--debug")
Timer.scheduledTimer(withTimeInterval: 1.0/120, repeats: true) { _ in
    let p = NSEvent.mouseLocation
    let moved = p != lastP; lastP = p
    if moved { win.setFrameOrigin(NSPoint(x: p.x - S/2, y: p.y - S/2)); idle = 0 } else { idle += 1 }
    tick += 1
    if tick % 240 == 0 { makeInvisible() }  // re-assert, other apps may re-register cursors
    if tick % 4 == 0 && (moved || idle < 30 || tick % 30 == 0) {
        // hit-test per app (skipping our own overlay window, which otherwise answers for the system-wide query)
        let pt = CGPoint(x: p.x, y: primaryH - p.y)
        let wins = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? []
        var tried = 0
        for w in wins {
            guard let pid = w[kCGWindowOwnerPID as String] as? pid_t, pid != getpid(),
                  (w[kCGWindowAlpha as String] as? Double ?? 1) > 0, (w[kCGWindowLayer as String] as? Int ?? 0) == 0,
                  let bd = w[kCGWindowBounds as String] as? [String: CGFloat],
                  CGRect(x: bd["X"] ?? 0, y: bd["Y"] ?? 0, width: bd["Width"] ?? 0, height: bd["Height"] ?? 0).contains(pt) else { continue }
            tried += 1; if tried > 3 { break }
            let app = AXUIElementCreateApplication(pid)
            if pid != lastPid { lastPid = pid; AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue) }  // makes Chrome/Electron expose text fields
            var el: AXUIElement?
            guard AXUIElementCopyElementAtPosition(app, Float(pt.x), Float(pt.y), &el) == .success, let el = el else { continue }
            var r: CFTypeRef?; AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &r)
            let role = (r as? String) ?? ""
            if role == "AXMenuBar" || role == "AXApplication" || role.isEmpty { continue }
            ctx = textRoles.contains(role) ? .text : linkRoles.contains(role) ? .link : .dot
            if debug { print(role, ctx); fflush(stdout) }
            break
        }
    }
    apply(NSEvent.pressedMouseButtons & 1 != 0 && ctx != .text ? .press : ctx)
}
NSApplication.shared.run()
