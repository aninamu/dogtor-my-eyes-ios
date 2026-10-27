import XCTest
@testable import DogtorMyEyes

final class FeatureFlagsTests: XCTestCase {
    func testDefaultIsOnInDebugBuilds() throws {
        let flags = FeatureFlags(defaults: try Fixtures.isolatedDefaults(), arguments: [])
        #if DEBUG
        XCTAssertTrue(flags.isEnabled(.phase1Finder))
        #else
        XCTAssertFalse(flags.isEnabled(.phase1Finder))
        #endif
    }

    func testUserDefaultsOverrideDefault() throws {
        let defaults = try Fixtures.isolatedDefaults()
        let flags = FeatureFlags(defaults: defaults, arguments: [])

        flags.set(.phase1Finder, enabled: false)
        XCTAssertFalse(flags.isEnabled(.phase1Finder))
        flags.set(.phase1Finder, enabled: true)
        XCTAssertTrue(flags.isEnabled(.phase1Finder))
        flags.set(.phase1Finder, enabled: nil)
        XCTAssertEqual(flags.isEnabled(.phase1Finder), FeatureFlag.phase1Finder.defaultValue)
    }

    func testLaunchArgumentsWinOverUserDefaults() throws {
        let defaults = try Fixtures.isolatedDefaults()
        defaults.set(true, forKey: FeatureFlag.phase1Finder.defaultsKey)

        XCTAssertFalse(FeatureFlags(defaults: defaults, arguments: ["--disable-phase1Finder"]).isEnabled(.phase1Finder))

        defaults.set(false, forKey: FeatureFlag.phase1Finder.defaultsKey)
        XCTAssertTrue(FeatureFlags(defaults: defaults, arguments: ["--enable-phase1Finder"]).isEnabled(.phase1Finder))
    }
}
