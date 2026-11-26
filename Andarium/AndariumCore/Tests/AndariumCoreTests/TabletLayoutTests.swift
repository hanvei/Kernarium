// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import Testing
@testable import AndariumCore

struct TabletLayoutTests {
    /// A phone's window at the resolution choices it offers, with the
    /// density Android reads at each: what "Tablet layout" asks for is the
    /// density that makes the window's smallest width the reference
    /// display's 720 dp. One table checks each width and density.
    @Test func theDensityMakesAPhoneWindowReadAsTheReferenceDisplay() {
        // px width @ natural dpi → the density the choice asks for.
        for (width, natural, density) in [
            (375, 160, 83), (375, 320, 83), (390, 320, 86), (402, 240, 89),
            (428, 320, 95), (440, 320, 97), (603, 240, 134), (804, 320, 178)
        ] {
            #expect(TabletLayout.density(widthPixels: width, naturalDotsPerInch: natural) == density, "\(width)@\(natural)")
        }
    }

    @Test func aDisplayThatCannotReadAsATabletAnswersNone() {
        // A display 300 px wide would need a density below the floor.
        #expect(TabletLayout.density(widthPixels: 300, naturalDotsPerInch: 320) == nil)
        // No display at all.
        #expect(TabletLayout.density(widthPixels: 0, naturalDotsPerInch: 320) == nil)
        #expect(TabletLayout.density(widthPixels: 402, naturalDotsPerInch: 0) == nil)
    }

    @Test func aDisplayThatAlreadyReadsAsATabletKeepsItsOwnDensity() {
        // An iPad's window: wider in dp than the boundary at its own
        // density, so the choice changes nothing there.
        #expect(TabletLayout.density(widthPixels: 1180, naturalDotsPerInch: 160) == nil)
        #expect(TabletLayout.density(widthPixels: 1024, naturalDotsPerInch: 160) == nil)
        // The same pixels at a phone's density do answer one.
        #expect(TabletLayout.density(widthPixels: 1024, naturalDotsPerInch: 320) != nil)
    }

    @Test func appliesFollowsTheChoiceAndTheDisplay() {
        #expect(!TabletLayout.applies(isOn: false, widthPixels: 402, naturalDotsPerInch: 320))
        #expect(TabletLayout.applies(isOn: true, widthPixels: 402, naturalDotsPerInch: 320))
        #expect(!TabletLayout.applies(isOn: true, widthPixels: 1180, naturalDotsPerInch: 160))
        #expect(!TabletLayout.applies(isOn: true, widthPixels: 300, naturalDotsPerInch: 320))
    }

    @Test func theCommandTellsTheShellTheDensityOrResetsIt() {
        #expect(TabletLayout.command(density: 89) == "wm density 89")
        #expect(TabletLayout.command(density: 94) == "wm density 94")
        #expect(TabletLayout.command(density: nil) == "wm density reset")
    }
}

struct TabletLayoutPreferenceTests {
    private func withDefaults<Result>(_ body: (UserDefaults) -> Result) -> Result {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("andarium-tablet-layout-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = directory.appendingPathComponent("defaults").path
        let defaults = UserDefaults(suiteName: name)!
        defer {
            defaults.removePersistentDomain(forName: name)
            try? FileManager.default.removeItem(at: directory)
        }
        return body(defaults)
    }

    @Test func aFreshInstallIsOff() {
        withDefaults { defaults in
            let preference = TabletLayoutPreference(defaults: defaults)
            #expect(!preference.isOn)
            let start = preference.launch(automated: false)
            #expect(!start.isOn)
            #expect(start.keepsChanges)
        }
    }

    @Test func theChoiceSurvivesANewSessionUntilTurnedBackOff() {
        withDefaults { defaults in
            TabletLayoutPreference(defaults: defaults).keep(true)
            let again = TabletLayoutPreference(defaults: defaults)
            #expect(again.isOn)
            let person = again.launch(automated: false)
            #expect(person.isOn && person.keepsChanges)
            again.keep(false)
            #expect(!TabletLayoutPreference(defaults: defaults).isOn)
        }
    }

    @Test func aHarnessLaunchRunsWithTheDefaultAndLeavesTheChoiceAlone() {
        withDefaults { defaults in
            let preference = TabletLayoutPreference(defaults: defaults)
            preference.keep(true)
            let harness = preference.launch(automated: true)
            #expect(!harness.isOn && !harness.keepsChanges)
            let stated = preference.launch(automated: true, stated: true)
            #expect(stated.isOn && !stated.keepsChanges)
            let statedOff = preference.launch(automated: false, stated: false)
            #expect(!statedOff.isOn && !statedOff.keepsChanges)
            #expect(preference.isOn, "a launch changed what the person chose")
        }
    }
}
