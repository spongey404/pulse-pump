import XCTest

/// The DEBUG dev-data seeder that every other UI test relies on.
final class DevDataUITests: UITestCase {

    /// Regression: relaunching with `-devDataReset 1` over an existing store used to crash Home
    /// (`Split.days` on a deleted split) because the shell rendered before the seeder replaced the models.
    func testRelaunchingTwiceWithDevDataResetKeepsTheAppAlive() {
        let email = LaunchConfig.uniqueEmail("reset")
        let config = launch(LaunchConfig(email: email, scenario: .busy, weeks: 4))
        XCTAssertGreaterThan(HomePage(t: self).streak, 0)

        for round in 1...2 {
            relaunch(with: config)
            require(el(AX.home.recent), "seeded Home after reset relaunch #\(round)", timeout: 60)
            XCTAssertEqual(app.state, .runningForeground, "app must still be running after reset relaunch #\(round)")
            XCTAssertGreaterThan(HomePage(t: self).streak, 0, "seed rebuilt on relaunch #\(round)")
        }
    }
}
