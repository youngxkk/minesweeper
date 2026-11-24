//
//  StarYiGoUITests.swift
//  StarYi Go UI Tests
//

import XCTest

final class StarYiGoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["STARYIGO_UI_TEST_SUITE"] = "StarYiGoUITests.\(UUID())"
        return app
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in scrollView: XCUIElement) {
        for _ in 0..<6 where !element.isHittable && scrollView.exists {
            scrollView.swipeUp(velocity: .slow)
        }
    }

    @MainActor
    func testPlayAIAndReopenSavedMatchAfterRelaunch() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = makeApp()
        app.launch()

        let start = app.buttons["HomeStartMatchButton"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()

        let board = app.otherElements["GoBoardCanvas"]
        XCTAssertTrue(board.waitForExistence(timeout: 10))
        board.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let confirm = app.buttons["Place Stone"]
        reveal(confirm, in: app.scrollViews.firstMatch)
        XCTAssertTrue(confirm.isHittable)
        confirm.tap()

        let aiReply = app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "GameStatusButton", "Move 2 ·")).firstMatch
        XCTAssertTrue(aiReply.waitForExistence(timeout: 20), "The AI must complete the second ply")

        let actions = app.buttons["GameActionsMenu"]
        XCTAssertTrue(actions.isHittable)
        actions.tap()
        app.buttons["Resign"].tap()
        app.alerts.buttons["Resign"].tap()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 10))

        // Relaunch against the same isolated store to verify persistence.
        app.terminate()
        app.launch()
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        let archive = app.buttons["HomeArchiveButton"]
        reveal(archive, in: app.scrollViews.firstMatch)
        XCTAssertTrue(archive.isHittable)
        archive.tap()

        let myGames = app.buttons["ArchiveMyGamesTab"]
        XCTAssertTrue(myGames.waitForExistence(timeout: 5))
        myGames.tap()
        let record = app.buttons.matching(identifier: "ArchiveGameRecord").firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.tap()
        XCTAssertTrue(board.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["W+R"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.sliders.firstMatch.waitForExistence(timeout: 5), "The saved SGF must load into the replay timeline")
    }

    @MainActor
    func testBoardFrameNeverJumpsDuringGameplay() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = makeApp()
        app.launch()

        // 0. Verify StarYi Islands adventure map opens and backs out cleanly via GameBackButton
        let islandsBtn = app.buttons["HomePuzzleQuestButton"]
        XCTAssertTrue(islandsBtn.waitForExistence(timeout: 5), "StarYi Islands hero button should exist on Home")
        islandsBtn.tap()

        let backZh = app.buttons["返回"]
        let backEn = app.buttons["Back"]
        let backBtn = backZh.waitForExistence(timeout: 4) ? backZh : backEn
        XCTAssertTrue(backBtn.exists, "Custom GameBackButton should appear on StarYi Islands map")
        backBtn.tap()

        // 1. Tap Start Match on Home
        let startButton = app.buttons["HomeStartMatchButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start Match hero button should exist on Home screen")
        startButton.tap()

        // 2. Measure initial Go board frame
        let board = app.otherElements["GoBoardCanvas"]
        XCTAssertTrue(board.waitForExistence(timeout: 5), "GoBoardCanvas should appear")
        let initialFrame = board.frame
        XCTAssertGreaterThan(initialFrame.width, 0)

        // 3. Tap center of board (enters pending confirm state on 13x13)
        board.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let confirmZh = app.buttons["确认落子"]
        let confirmEn = app.buttons["Place Stone"]
        let confirmBtn = confirmZh.waitForExistence(timeout: 3) ? confirmZh : confirmEn
        reveal(confirmBtn, in: app.scrollViews.firstMatch)
        XCTAssertTrue(confirmBtn.isHittable, "Confirm button should appear in fixed dock")

        let pendingFrame = board.frame
        XCTAssertEqual(initialFrame.origin.x, pendingFrame.origin.x, accuracy: 0.5, "Board X must not jump when confirm bar appears")
        XCTAssertEqual(initialFrame.origin.y, pendingFrame.origin.y, accuracy: 0.5, "Board Y must not jump when confirm bar appears")
        XCTAssertEqual(initialFrame.width, pendingFrame.width, accuracy: 0.5, "Board width must not shrink when confirm bar appears")
        XCTAssertEqual(initialFrame.height, pendingFrame.height, accuracy: 0.5, "Board height must not shrink when confirm bar appears")

        // 4. Confirm placement (triggers AI thinking & status update)
        confirmBtn.tap()
        Thread.sleep(forTimeInterval: 0.8)

        let afterMoveFrame = board.frame
        XCTAssertEqual(initialFrame.origin.x, afterMoveFrame.origin.x, accuracy: 0.5, "Board X must not jump after move")
        XCTAssertEqual(initialFrame.origin.y, afterMoveFrame.origin.y, accuracy: 0.5, "Board Y must not jump after move")
        XCTAssertEqual(initialFrame.width, afterMoveFrame.width, accuracy: 0.5, "Board width must not change after move")
        XCTAssertEqual(initialFrame.height, afterMoveFrame.height, accuracy: 0.5, "Board height must not change after move")

        // 5. Toggle Territory overlay -> board frame MUST stay identical
        let terrZh = app.buttons["形势判断"]
        let terrEn = app.buttons["Territory"]
        let terrBtn = terrZh.exists ? terrZh : terrEn
        reveal(terrBtn, in: app.scrollViews.firstMatch)
        XCTAssertTrue(terrBtn.isHittable)
        terrBtn.tap()
        let territoryFrame = board.frame
        XCTAssertEqual(initialFrame.origin.y, territoryFrame.origin.y, accuracy: 0.5, "Board Y must not jump when toggling territory")
        XCTAssertEqual(initialFrame.height, territoryFrame.height, accuracy: 0.5, "Board height must not change when toggling territory")
    }

    @MainActor
    func testHomeAIOptionChipsAreTappable() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = makeApp()
        app.launch()

        let startBtn = app.buttons["HomeStartMatchButton"]
        XCTAssertTrue(startBtn.waitForExistence(timeout: 5))

        // Tap each of the 4 option chips at their exact visual center (like a real human finger!)
        // 1. Board Size chip -> Menu pops up -> pick 19x19
        let sizeChip = app.buttons["HomeBoardSizeChip"]
        XCTAssertTrue(sizeChip.waitForExistence(timeout: 3), "HomeBoardSizeChip must exist")
        sizeChip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let opt19 = app.buttons.matching(NSPredicate(format: "label CONTAINS '19'")).firstMatch
        XCTAssertTrue(opt19.waitForExistence(timeout: 3), "Real center tap on BoardSizeChip (\(sizeChip.frame)) MUST open menu! StartBtn=\(startBtn.frame)")
        opt19.tap()

        // 2. Difficulty chip -> Menu pops up -> pick 5K
        let diffChip = app.buttons["HomeDifficultyChip"]
        XCTAssertTrue(diffChip.waitForExistence(timeout: 3))
        diffChip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let opt5K = app.buttons.matching(NSPredicate(format: "label CONTAINS '5K'")).firstMatch
        XCTAssertTrue(opt5K.waitForExistence(timeout: 3), "Real center tap on DifficultyChip (\(diffChip.frame)) MUST open menu!")
        opt5K.tap()

        // 3. Rules / Color chip -> Menu pops up -> pick White
        let rulesChip = app.buttons["HomeRulesChip"]
        XCTAssertTrue(rulesChip.waitForExistence(timeout: 3))
        rulesChip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let optWhite = app.buttons.matching(NSPredicate(format: "label CONTAINS '执白' OR label CONTAINS 'White'")).firstMatch
        XCTAssertTrue(optWhite.waitForExistence(timeout: 3), "Real center tap on RulesChip (\(rulesChip.frame)) MUST open menu!")
        optWhite.tap()

        // 4. Clock / Coaching chip -> Menu pops up -> pick 10m
        let clockChip = app.buttons["HomeClockChip"]
        XCTAssertTrue(clockChip.waitForExistence(timeout: 3))
        clockChip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let opt10m = app.buttons.matching(NSPredicate(format: "label CONTAINS '10分钟' OR label CONTAINS '10m'")).firstMatch
        XCTAssertTrue(opt10m.waitForExistence(timeout: 3), "Real center tap on ClockChip (\(clockChip.frame)) MUST open menu!")
        opt10m.tap()
    }
}
