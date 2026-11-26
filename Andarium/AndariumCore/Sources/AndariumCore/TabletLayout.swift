// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation

/// Home's "Tablet layout" in Virtual machine: whether Android's interface
/// takes the two-column layout of a large screen. The choice lasts across
/// launches and applies to the next Android start.
///
/// Android lays its interface out by the display's width in density
/// independent pixels, which the host keeps equal to the window's width in
/// points wherever the person's resolution choice is. A window narrower
/// than the smallest tablet therefore reads as a phone. The switch lowers
/// the density Android is told, so the same window reads as the inner
/// display of a folding iPhone — the widest display this application runs
/// on and the reference for the figures here.
public struct TabletLayoutPreference {
    /// The stored value's key in the defaults database; a missing value is
    /// the default, off.
    public static let key = "andarium.tabletLayout"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The last value kept; off until one is.
    public var isOn: Bool { defaults.object(forKey: Self.key) as? Bool ?? false }

    public func keep(_ on: Bool) {
        defaults.set(on, forKey: Self.key)
    }

    /// How a launch begins. One that states the value starts as stated. Any
    /// other harness launch starts with the default, so that a measured run
    /// does not inherit the person's choice; only a launch of the person's
    /// own restores the kept value.
    public func launch(automated: Bool, stated: Bool? = nil) -> Launch {
        if let stated { return Launch(isOn: stated, keepsChanges: false) }
        return automated ? Launch(isOn: false, keepsChanges: false) : Launch(isOn: isOn, keepsChanges: true)
    }

    /// How a launch begins.
    public struct Launch: Equatable, Sendable {
        /// Whether the setting is on from the start.
        public var isOn: Bool
        /// Whether what the person sets from here on is kept.
        public var keepsChanges: Bool
    }
}

/// The density Android is told while "Tablet layout" is on, from the display
/// the next start gives the guest. Pure arithmetic: one place holds every
/// figure, and one table in the tests checks each against the display it
/// came from.
public enum TabletLayout {
    /// What the smallest width of a display Android lays out as a tablet is,
    /// in density independent pixels: the platform's own boundary. Launcher3
    /// shows its taskbar, the two-column layouts of the system apps and most
    /// third-party applications begin at it, and the sw600dp wallpapers of
    /// the release take their place.
    public static let minimumSmallestWidthDp = 600.0

    /// The smallest width the inner display of a folding iPhone gives
    /// Android, in density independent pixels: the reference display of this
    /// choice. Everything a person sees with the switch on is what that
    /// display shows, at the same size relative to the screen.
    public static let referenceSmallestWidthDp = 720.0

    /// The density the switch asks of a display `widthPixels` guest pixels
    /// wide, which Android reads at `naturalDotsPerInch`: the density that
    /// makes the display's smallest width the reference display's. A
    /// display that already reads as a tablet at its own density keeps it
    /// (nil), so a choice made on a large screen changes nothing there. The
    /// answer is never below 80: a density the platform's own scaling of its
    /// largest texts cannot hold.
    public static func density(widthPixels: Int, naturalDotsPerInch: Int) -> Int? {
        guard widthPixels > 0, naturalDotsPerInch > 0 else { return nil }
        let naturalWidthDp = Double(widthPixels) * 160.0 / Double(naturalDotsPerInch)
        guard naturalWidthDp < minimumSmallestWidthDp else { return nil }
        let whole = Int((Double(widthPixels) * 160.0 / referenceSmallestWidthDp).rounded(.down))
        guard whole >= 80 else { return nil }
        // The rounded figure must still leave the display at the boundary:
        // what it gives, in whole dp.
        guard Double(widthPixels) * 160.0 / Double(whole) >= minimumSmallestWidthDp else { return nil }
        return whole
    }

    /// Whether the guest applies the density to the display of the next
    /// start, from the choice and the display: only where the person asked
    /// and a density answers the display.
    public static func applies(
        isOn: Bool, widthPixels: Int, naturalDotsPerInch: Int
    ) -> Bool {
        isOn && density(widthPixels: widthPixels, naturalDotsPerInch: naturalDotsPerInch) != nil
    }

    /// The command the shell user runs to tell Android the density of its
    /// default display: the override `wm` keeps in its settings store, or
    /// the reset that returns the guest to the density of the display the
    /// start passed (`androidboot.lcd_density`). `density` is what
    /// `density(widthPixels:naturalDotsPerInch:)` answered; nil resets.
    public static func command(density: Int?) -> String {
        guard let density else { return "wm density reset" }
        return "wm density \(density)"
    }
}
