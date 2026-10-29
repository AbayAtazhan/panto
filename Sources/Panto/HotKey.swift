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

    private init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let callback: EventHandlerUPP = { _, _, userData in
            guard let userData else { return noErr }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async {
                center.onPress?()
            }
            return noErr
        }
        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
    }

    func register(_ combo: HotKeyCombo) {
        if registered == combo, hotKeyRef != nil { return }
        unregister()
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

        let text = isRecording ? "Press keys…" : combo.label
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
