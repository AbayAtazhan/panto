import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Registers a system-wide hotkey through Carbon. Works without Accessibility.
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    var onPress: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var registered: HotKeyCombo?

    private init() {}

    /// Carbon needs the app's event target, which only exists once NSApplication
    /// is up. Install lazily and retry: doing it in `init` can silently fail and
    /// leave the hotkey registered without a handler (the key then just beeps).
    @discardableResult
    private func installHandlerIfNeeded() -> Bool {
        if handlerRef != nil { return true }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let callback: EventHandlerUPP = { _, _, userData in
            guard let userData else { return noErr }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async {
                Log.write("hotkey: pressed")
                center.onPress?()
            }
            return noErr
        }
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
        Log.write("hotkey: install handler status=\(status)")
        if status != noErr {
            handlerRef = nil
            return false
        }
        return true
    }

    func register(_ combo: HotKeyCombo) {
        // Never register a modifier-less key: it would steal that key from every app.
        guard combo.modifiers != 0 else {
            unregister()
            return
        }
        if registered == combo, hotKeyRef != nil { return }
        unregister()

        guard installHandlerIfNeeded() else {
            Log.write("hotkey: handler unavailable, not registering")
            return
        }

        var ref: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: OSType(0x50414E54), id: 1) // 'PANT'
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        Log.write("hotkey: register \(combo.label) status=\(status)")
        if status == noErr {
            hotKeyRef = ref
            registered = combo
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
        registered = nil
    }
}

// MARK: - Recorder control

struct HotKeyField: NSViewRepresentable {
    @Binding var combo: HotKeyCombo

    func makeNSView(context: Context) -> HotKeyRecorderView {
        let view = HotKeyRecorderView()
        view.onCapture = { combo = $0 }
        view.combo = combo
        return view
    }

    func updateNSView(_ nsView: HotKeyRecorderView, context: Context) {
        nsView.combo = combo
    }
}

final class HotKeyRecorderView: NSView {
    var onCapture: ((HotKeyCombo) -> Void)?
    var combo: HotKeyCombo = .fallback {
        didSet { needsDisplay = true }
    }

    private var isRecording = false
    private var warning: String?
    private var isHovering = false

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 118, height: 30) }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.16) : NSColor.controlBackgroundColor).setFill()
        path.fill()
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = 1
        path.stroke()

        let text = warning ?? (isRecording ? "Press keys…" : combo.label)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: isRecording ? NSColor.controlAccentColor : NSColor.labelColor
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(
            at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2),
            withAttributes: attributes
        )
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
        needsDisplay = true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        needsDisplay = true
        return true
    }

    override func keyDown(with event: NSEvent) {
        // Ignore modifier-only presses.
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isModifierOnly = [.command, .option, .control, .shift].contains(where: { flags.contains($0) })
            && event.charactersIgnoringModifiers?.isEmpty != false
        if isModifierOnly { return }

        // A bare key would be swallowed system-wide: always require ⌘/⌥/⌃.
        let hasModifier = flags.contains(.command) || flags.contains(.option) || flags.contains(.control)
        guard hasModifier else {
            warning = "Add ⌘, ⌥ or ⌃"
            NSSound.beep()
            needsDisplay = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
                self?.warning = nil
                self?.needsDisplay = true
            }
            return
        }

        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }

        var label = ""
        if flags.contains(.control) { label += "⌃" }
        if flags.contains(.option) { label += "⌥" }
        if flags.contains(.shift) { label += "⇧" }
        if flags.contains(.command) { label += "⌘" }
        let key = event.charactersIgnoringModifiers?.uppercased() ?? "?"
        label += key

        let updated = HotKeyCombo(keyCode: UInt32(event.keyCode), modifiers: carbon, label: label)
        combo = updated
        isRecording = false
        onCapture?(updated)
        window?.makeFirstResponder(nil)
    }
}
