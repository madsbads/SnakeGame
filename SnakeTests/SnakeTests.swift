//
//  SnakeTests.swift
//  SnakeTests
//
//  Created by Maddie Nevans on 1/24/25.
//

import XCTest
@testable import Snake

final class SnakeTests: XCTestCase {

    func testGameStatusInitialValues() {
        let gameStatus = GameStatus()
        XCTAssertFalse(gameStatus.isGameOver, "Game should not be over when first initialized")
        XCTAssertFalse(gameStatus.isGamePaused, "Game should not be paused when first initialized")
    }
    
    func testHighScoreCalculation() {
        // Create a few dummy GameItems
        let item1 = GameItem()
        item1.score = 5
        let item2 = GameItem()
        item2.score = 10
        let item3 = GameItem()
        item3.score = 7
        
        let gameItems = [item1, item2, item3]
        
        // Simulate calculating the high score.
        // (In your GameView the logic loops through gameItems; here we can simulate that.)
        let highScore = gameItems.max { $0.score < $1.score }
        XCTAssertEqual(highScore?.score, 10, "The high score should be 10")
    }
    
    // If you extract reset logic into a separate GameLogic class or extension, you could test it like:
    /*
    func testResetSnakeWithSufficientBank() {
        let gameLogic = GameLogic() // Your custom logic type
        gameLogic.accumulatedPoints = 25
        gameLogic.theSnake = [CGPoint(x: 0, y: 0), CGPoint(x: 22, y: 0)]
        gameLogic.resetSnake()
        XCTAssertEqual(gameLogic.accumulatedPoints, 5, "20 points should have been deducted")
        XCTAssertEqual(gameLogic.theSnake.count, 1, "The snake should have been reset to one segment")
    }
    */
}
