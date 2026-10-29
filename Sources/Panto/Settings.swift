import Carbon.HIToolbox
import Foundation

enum TriggerMode: String, CaseIterable, Identifiable {
    case clicks
    case hotkey
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clicks: return "Clicks"
        case .hotkey: return "Hotkey"
        case .both: return "Both"
        }
    }

    var detail: String {
        switch self {
        case .clicks: return "Zoom wherever you click."
        case .hotkey: return "Zoom only when you press the hotkey."
        case .both: return "Clicks and the hotkey both zoom."
        }
    }
}

struct HotKeyCombo: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var label: String

    static let fallback = HotKeyCombo(
        keyCode: UInt32(kVK_ANSI_Z),
        modifiers: UInt32(cmdKey | optionKey),
        label: "⌥⌘Z"
    )

    var carbonModifiers: UInt32 { modifiers }
}

final class AppSettings: ObservableObject {
    @Published var trigger: TriggerMode {
        didSet { save() }
    }
    @Published var hotKey: HotKeyCombo {
        didSet { save() }
    }
    @Published var zoom: Double {
        didSet { save() }
    }
    @Published var systemAudio: Bool {
        didSet { save() }
    }
    @Published var showHUD: Bool {
        didSet { save() }
    }
    @Published var selectedDisplayID: CGDirectDisplayID? {
        didSet { save() }
    }

    private let defaults = UserDefaults.standard
    private let key = "panto.settings.v2"

    init() {
        if let data = defaults.data(forKey: key),
           let stored = try? JSONDecoder().decode(Stored.self, from: data) {
            trigger = TriggerMode(rawValue: stored.trigger) ?? .both
            hotKey = HotKeyCombo(keyCode: stored.keyCode, modifiers: stored.modifiers, label: stored.label)
            zoom = stored.zoom
            systemAudio = stored.systemAudio
            showHUD = stored.showHUD
            selectedDisplayID = stored.displayID
        } else {
            trigger = .both
            hotKey = .fallback
            zoom = 2.0
            systemAudio = true
            showHUD = true
            selectedDisplayID = nil
        }
    }

    private struct Stored: Codable {
        var trigger: String
        var keyCode: UInt32
        var modifiers: UInt32
        var label: String
        var zoom: Double
        var systemAudio: Bool
        var showHUD: Bool
        var displayID: CGDirectDisplayID?
    }

    private func save() {
        let stored = Stored(
            trigger: trigger.rawValue,
            keyCode: hotKey.keyCode,
            modifiers: hotKey.modifiers,
            label: hotKey.label,
            zoom: zoom,
            systemAudio: systemAudio,
            showHUD: showHUD,
            displayID: selectedDisplayID
        )
        if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: key)
        }
    }
}
