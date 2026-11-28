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
    private func makeApp(language: String = "en", locale: String = "en_US") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(\(language))", "-AppleLocale", locale]
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
    func testCampaignMapVisualReview() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = makeApp()
        app.launch()
        let quest = app.buttons["HomePuzzleQuestButton"]
        XCTAssertTrue(quest.waitForExistence(timeout: 10))
        let mistakesButton = app.buttons["HomeMistakeBookButton"]
        XCTAssertTrue(mistakesButton.waitForExistence(timeout: 5), "HomeMistakeBookButton should exist on Home")
        XCTAssertGreaterThanOrEqual(mistakesButton.frame.minY, quest.frame.maxY - 2, "Mistake book entry should sit below StarYi Adventure")
        XCTAssertGreaterThanOrEqual(mistakesButton.frame.minX, quest.frame.minX - 2, "Mistake book entry should align under StarYi Adventure")
        quest.tap()

        let landmarks = ["IslandPin_s1-reef", "IslandPinLocked_s2-wind", "IslandPinLocked_s3-pine", "IslandPinLocked_s4-mist", "IslandPinLocked_s5-forge"]
        for (offset, landmark) in landmarks.enumerated() {
            let index = offset + 1
            let tab = app.buttons["SeaTab_sea-\(index)"]
            XCTAssertTrue(tab.waitForExistence(timeout: 5))
            tab.tap()
            let selected = NSPredicate(format: "label CONTAINS %@", "Sea \(index)")
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: selected, object: tab)], timeout: 5), .completed)
            let pin = app.buttons[landmark]
            let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                pin.exists && pin.frame.midX >= app.frame.width * 0.1 && pin.frame.midX <= app.frame.width * 0.4
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 5), .completed)
            let title = app.descendants(matching: .any)["CampaignMapTitle"]
            XCTAssertTrue(title.exists)
            XCTAssertEqual(title.frame.midX, app.frame.midX, accuracy: 1)
            if index > 1 {
                let gate = app.buttons["CampaignSkipGateButton"]
                XCTAssertTrue(gate.exists)
                XCTAssertLessThanOrEqual(pin.frame.maxY, gate.frame.minY + 2)
            }
            let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            capture.name = "Campaign-Sea-\(index)"
            capture.lifetime = .keepAlways
            add(capture)
        }

        let map = app.scrollViews.firstMatch
        let start = map.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.45))
        let end = map.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.45))
        start.press(forDuration: 0.08, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0)
        let fourthSea = app.buttons["SeaTab_sea-4"]
        let selected = NSPredicate(format: "label CONTAINS %@", "Sea 4")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: selected, object: fourthSea)], timeout: 5), .completed)
    }

    @MainActor
    func testCampaignEdgeFlyButtons() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = makeApp()
        app.launch()

        let quest = app.buttons["HomePuzzleQuestButton"]
        XCTAssertTrue(quest.waitForExistence(timeout: 10))
        let mistakesButton = app.buttons["HomeMistakeBookButton"]
        XCTAssertTrue(mistakesButton.waitForExistence(timeout: 5), "HomeMistakeBookButton should exist on Home")
        XCTAssertGreaterThanOrEqual(mistakesButton.frame.minY, quest.frame.maxY - 2, "Mistake book entry should sit below StarYi Adventure")
        XCTAssertGreaterThanOrEqual(mistakesButton.frame.minX, quest.frame.minX - 2, "Mistake book entry should align under StarYi Adventure")
        quest.tap()

        let nextButton = app.buttons["FlyNextSeaButton"]
        let prevButton = app.buttons["FlyPrevSeaButton"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5), "FlyNextSeaButton should exist on Sea 1")
        XCTAssertTrue(nextButton.isHittable, "FlyNextSeaButton should be hittable on Sea 1")

        // Tap right edge button to navigate from Sea 1 -> Sea 2 -> Sea 3
        nextButton.tap()
        let sea2Tab = app.buttons["SeaTab_sea-2"]
        let sea2Selected = NSPredicate(format: "label CONTAINS %@", "Sea 2")
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: sea2Selected, object: sea2Tab)], timeout: 5),
            .completed,
            "Tapping FlyNextSeaButton should switch to Sea 2"
        )
        let sea2Pin = app.buttons["IslandPinLocked_s2-wind"]
        let sea2Settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            sea2Pin.exists && sea2Pin.frame.midX >= app.frame.width * 0.1 && sea2Pin.frame.midX <= app.frame.width * 0.4
        }, object: nil)
        XCTAssertEqual(
            XCTWaiter.wait(for: [sea2Settled], timeout: 5),
            .completed,
            "Map should scroll to Sea 2 (app.frame=\(app.frame), sea1Pin=\(app.buttons["IslandPin_s1-reef"].frame), sea2Pin=\(sea2Pin.frame))"
        )

        XCTAssertTrue(prevButton.waitForExistence(timeout: 5), "FlyPrevSeaButton should exist on Sea 2")
        XCTAssertTrue(prevButton.isHittable, "FlyPrevSeaButton should be hittable on Sea 2")
        nextButton.tap()
        let sea3Tab = app.buttons["SeaTab_sea-3"]
        let sea3Selected = NSPredicate(format: "label CONTAINS %@", "Sea 3")
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: sea3Selected, object: sea3Tab)], timeout: 5),
            .completed,
            "Tapping FlyNextSeaButton again should switch to Sea 3"
        )
        let sea3Pin = app.buttons["IslandPinLocked_s3-pine"]
        let sea3Settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            sea3Pin.exists && sea3Pin.frame.midX >= app.frame.width * 0.1 && sea3Pin.frame.midX <= app.frame.width * 0.4
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [sea3Settled], timeout: 5), .completed, "Map should scroll to Sea 3")

        // Tap left edge button to navigate back from Sea 3 -> Sea 2 -> Sea 1
        prevButton.tap()
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: sea2Selected, object: sea2Tab)], timeout: 5),
            .completed,
            "Tapping FlyPrevSeaButton should switch back to Sea 2"
        )
        let sea2BackSettled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            sea2Pin.exists && sea2Pin.frame.midX >= app.frame.width * 0.1 && sea2Pin.frame.midX <= app.frame.width * 0.4
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [sea2BackSettled], timeout: 5), .completed, "Map should scroll back to Sea 2")

        prevButton.tap()
        let sea1Tab = app.buttons["SeaTab_sea-1"]
        let sea1Selected = NSPredicate(format: "label CONTAINS %@", "Sea 1")
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: sea1Selected, object: sea1Tab)], timeout: 5),
            .completed,
            "Tapping FlyPrevSeaButton again should switch back to Sea 1"
        )
        let sea1Pin = app.buttons["IslandPin_s1-reef"]
        let sea1BackSettled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            sea1Pin.exists && sea1Pin.frame.midX >= app.frame.width * 0.1 && sea1Pin.frame.midX <= app.frame.width * 0.4
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [sea1BackSettled], timeout: 5), .completed, "Map should scroll back to Sea 1")
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
        let center = board.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.tap()
        center.tap()

        let aiReply = app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "GameStatusButton", "Move 2 ·")).firstMatch
        XCTAssertTrue(aiReply.waitForExistence(timeout: 20), "The AI must complete the second ply")

        let actions = app.buttons["GameActionsMenu"]
        XCTAssertTrue(actions.isHittable)
        actions.tap()
        app.buttons["Resign"].tap()
        app.buttons["Resign"].tap()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 10))

        // Relaunch against the same isolated store to verify persistence.
        app.terminate()
        app.launch()
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        let passport = app.buttons["HomePassportButton"]
        XCTAssertTrue(passport.waitForExistence(timeout: 5))
        passport.tap()

        let record = app.buttons.matching(identifier: "ArchiveGameRecord").firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.tap()
        XCTAssertTrue(board.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["W+R"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.sliders.firstMatch.waitForExistence(timeout: 5), "The saved SGF must load into the replay timeline")
    }

    @MainActor
    func testGamePlayVoiceToggleButton() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = makeApp()
        app.launch()

        let startButton = app.buttons["HomeStartMatchButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        startButton.tap()

        let soundToggle = app.buttons["GameSoundToggleButton"]
        let voiceToggle = app.buttons["GameVoiceToggleButton"]
        let stoneToggle = app.buttons["GameStoneDisplayToggleButton"]
        XCTAssertTrue(soundToggle.waitForExistence(timeout: 5), "GameSoundToggleButton should appear in top bar")
        XCTAssertTrue(voiceToggle.waitForExistence(timeout: 5), "GameVoiceToggleButton should appear in top bar")
        XCTAssertTrue(stoneToggle.waitForExistence(timeout: 5), "GameStoneDisplayToggleButton should appear in top bar")
        XCTAssertLessThanOrEqual(soundToggle.frame.maxX, voiceToggle.frame.minX + 1, "Sound toggle should sit to the left of voice toggle")
        XCTAssertLessThanOrEqual(voiceToggle.frame.maxX, stoneToggle.frame.minX + 1, "Voice toggle should sit to the left of stone display toggle")
        XCTAssertTrue(soundToggle.label.contains("On"), "Sound toggle should start On")
        XCTAssertTrue(voiceToggle.label.contains("On"), "Voice toggle should start On")

        soundToggle.tap()
        XCTAssertTrue(soundToggle.label.contains("Off"), "Tapping sound toggle should mute sound effects")
        XCTAssertTrue(voiceToggle.label.contains("On"), "Muting sound effects should leave voice toggle independent")

        soundToggle.tap()
        XCTAssertTrue(soundToggle.label.contains("On"), "Tapping sound toggle again should re-enable sound effects")

        voiceToggle.tap()
        XCTAssertTrue(voiceToggle.label.contains("Off"), "Tapping voice toggle should mute voice lines")

        voiceToggle.tap()
        XCTAssertTrue(voiceToggle.label.contains("On"), "Tapping voice toggle again should re-enable voice lines")
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

        // 3. Switch to Confirm Button mode via top-right menu, then tap center of board
        let actions = app.buttons["GameActionsMenu"]
        XCTAssertTrue(actions.waitForExistence(timeout: 5))
        actions.tap()
        let confirmModeBtn = app.buttons["GamePlacementModeConfirmButton"]
        XCTAssertTrue(confirmModeBtn.waitForExistence(timeout: 3))
        confirmModeBtn.tap()
        actions.tap()
        _ = confirmModeBtn.waitForNonExistence(timeout: 2)

        board.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let confirmById = app.buttons["GameConfirmPlaceButton"]
        let confirmZh = app.buttons["确认落子"]
        let confirmEn = app.buttons["Place Stone"]
        let confirmBtn = confirmById.waitForExistence(timeout: 3)
            ? confirmById
            : (confirmZh.exists ? confirmZh : confirmEn)
        reveal(confirmBtn, in: app.scrollViews.firstMatch)
        XCTAssertTrue(confirmBtn.isHittable, "Confirm button should appear in fixed dock")

        XCTAssertGreaterThanOrEqual(confirmBtn.frame.height, 56)

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
        XCTAssertGreaterThanOrEqual(terrBtn.frame.height, 56)
        terrBtn.tap()
        let territoryFrame = board.frame
        XCTAssertEqual(initialFrame.origin.y, territoryFrame.origin.y, accuracy: 0.5, "Board Y must not jump when toggling territory")
        XCTAssertEqual(initialFrame.height, territoryFrame.height, accuracy: 0.5, "Board height must not change when toggling territory")
    }

    @MainActor
    func testChineseNineteenLineBoardOnPad() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = makeApp(language: "zh-Hans", locale: "zh_CN")
        app.launch()

        let start = app.buttons["HomeStartMatchButton"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        let size = app.buttons["HomeBoardSizeChip"]
        reveal(size, in: app.scrollViews.firstMatch)
        XCTAssertTrue(size.isHittable)
        size.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let nineteen = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "标准全场")).firstMatch
        XCTAssertTrue(nineteen.waitForExistence(timeout: 5))
        nineteen.tap()
        reveal(start, in: app.scrollViews.firstMatch)
        XCTAssertTrue(start.isHittable)
        start.tap()

        let actions = app.buttons["GameActionsMenu"]
        XCTAssertTrue(actions.waitForExistence(timeout: 5))
        actions.tap()
        let confirmModeBtn = app.buttons["GamePlacementModeConfirmButton"]
        XCTAssertTrue(confirmModeBtn.waitForExistence(timeout: 3))
        confirmModeBtn.tap()
        actions.tap()

        let board = app.otherElements["GoBoardCanvas"]
        XCTAssertTrue(board.waitForExistence(timeout: 10))
        let center = board.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let focus = app.buttons["GameBoardFocusButton"]
        let confirm = app.buttons["确认落子"]
        XCTAssertFalse(focus.exists, "iPad uses full 19x19 board without phone zoom toggle")

        center.tap()
        reveal(confirm, in: app.scrollViews.firstMatch)
        XCTAssertTrue(confirm.isHittable)
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Pending move survives backgrounding")
        confirm.tap()
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

    @MainActor
    func testFamilyProfileLongPressDeletePersists() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = makeApp()
        app.launch()

        let settingsBtn = app.buttons["Settings"]
        XCTAssertTrue(settingsBtn.waitForExistence(timeout: 8), "Settings button must exist on Home")
        settingsBtn.tap()

        // Add a second family member
        let addBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Add'")).firstMatch
        XCTAssertTrue(addBtn.waitForExistence(timeout: 5), "Add member button must exist in Settings")
        addBtn.tap()

        let okBtn = app.buttons["OK"]
        XCTAssertTrue(okBtn.waitForExistence(timeout: 3))
        okBtn.tap()

        // Find the newly added second family profile chip
        let profileChips = app.buttons.matching(identifier: "FamilyProfileChip")
        let twoChips = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count == 2"),
            object: profileChips
        )
        XCTAssertEqual(XCTWaiter.wait(for: [twoChips], timeout: 5), .completed, "Should have 2 family profile chips after adding one")
        let newProfileChip = profileChips.element(boundBy: 1)
        let deletedLabel = newProfileChip.label

        // Long-press the newly created profile chip to open the system context menu
        newProfileChip.press(forDuration: 1.0)

        let deleteMenuItem = app.buttons["Delete Profile"]
        XCTAssertTrue(deleteMenuItem.waitForExistence(timeout: 5), "Context menu must show Delete Profile")
        deleteMenuItem.tap()

        // Confirm deletion in the glossy gameDialog
        let confirmDeleteBtn = app.buttons["Delete"]
        XCTAssertTrue(confirmDeleteBtn.waitForExistence(timeout: 5), "Confirmation dialog must show Delete button")
        confirmDeleteBtn.tap()

        // Verify the deleted profile disappears immediately
        let oneChip = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count == 1"),
            object: profileChips
        )
        XCTAssertEqual(XCTWaiter.wait(for: [oneChip], timeout: 5), .completed, "Deleted profile '\(deletedLabel)' must disappear after confirming Delete")

        // Close Settings and reopen to confirm deletion persisted
        let backBtn = app.buttons["Back"]
        XCTAssertTrue(backBtn.waitForExistence(timeout: 3))
        backBtn.tap()

        XCTAssertTrue(settingsBtn.waitForExistence(timeout: 5))
        settingsBtn.tap()
        XCTAssertTrue(addBtn.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "FamilyProfileChip").count, 1, "Deleted profile '\(deletedLabel)' must stay deleted after closing and reopening Settings")
    }
}
