//
//  SnakeUITests.swift
//  SnakeUITests
//
//  Created by Maddie Nevans on 1/24/25.
//

import XCTest

final class SnakeUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func testLaunchGameFromMainMenu() {
        // Ensure the "play" button exists on the main menu
        let playButton = app.buttons["play"]
        XCTAssertTrue(playButton.exists, "Play button should exist on the main menu")
        
        // Tap "play" to launch GameView
        playButton.tap()
        
        // Check that an element from GameView exists; for example, the score label.
        let scoreLabel = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'score:'")).element
        XCTAssertTrue(scoreLabel.waitForExistence(timeout: 5), "GameView should display a score label")
    }
    
    func testPauseGameOnBackgrounding() {
        // Launch the game first.
        app.buttons["play"].tap()
        
        // Simulate sending the app to background
        XCUIDevice.shared.press(.home)
        // Wait a moment to allow the scene phase change to be processed.
        sleep(2)
        
        // Bring the app back to the foreground.
        app.activate()
        
        // Check that the game is paused by looking for an element in the pause sheet.
        // For example, verify that the "pause.circle.fill" button is still present.
        let pauseButton = app.buttons["pause.circle.fill"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 5), "After backgrounding, the pause UI should be active")
    }
    
    func testPowerUpMenuAppears() {
        // Launch the game.
        app.buttons["play"].tap()
        
        // Tap the power up button (icon: powerplug.portrait)
        let powerUpButton = app.buttons["powerplug.portrait"]
        XCTAssertTrue(powerUpButton.exists, "The power up button should exist in GameView")
        powerUpButton.tap()
        
        // Verify that the power up sheet appears (look for its text).
        let powerUpText = app.staticTexts["shake to power up!"]
        XCTAssertTrue(powerUpText.waitForExistence(timeout: 5), "The power up sheet should display the expected text")
    }
}

