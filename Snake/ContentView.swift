//
//  ContentView.swift
//  Snake
//
//  Created by Maddie Nevans on 1/24/25.
//

import SwiftUI
import SwiftData
import Combine

@Observable
class GameStatus: ObservableObject {
    var isGameOver: Bool = false
    var isGamePaused: Bool = false
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate { $0.score > 0 }, sort: \GameItem.score, order: .forward) private var gameItems: [GameItem]

    @Environment(GameStatus.self) private var gameStatus
    
    var body: some View {
//        GameView(gameStatus: gameStatus)
        MainMenuView()
    }
}

// MARK: - Main Menu
struct MainMenuView: View {
    
    @State private var isGameActive: Bool = false
    @State private var inSettings: Bool = false
    @Environment(GameStatus.self) private var gameStatus
    
    // button to navigate to new game
    
    // button to navigate to settings
    
    var body: some View {
        ZStack {
            //Background color
            Color("defaultBackgroundColor")
                .ignoresSafeArea()
            VStack {
                Button(action: {
                    isGameActive = true
                }) {
                    Text("play")
                        .monospaced()
                        .bold()
                        .frame(width: 150, height: 50)
                        .background(Color("defaultButtonColor"))
                        .foregroundColor(Color("defaultFontColor"))
                }
                Button(action: {
                    inSettings = true
                }) {
                    Text("settings")
                        .monospaced()
                        .bold()
                        .frame(width: 150, height: 50)
                        .background(Color("defaultButtonColor"))
                        .foregroundColor(Color("defaultFontColor"))
                }
            }
        }
        .fullScreenCover(isPresented: $isGameActive) {
            GameView(gameStatus: gameStatus)
        }
        .sheet(isPresented: $inSettings) {
            // Setting Menu
            Text("settings")
            .interactiveDismissDisabled(false)
        }

    }
}

// MARK: - Game View
struct GameView: View {
    
    // has access to model context
    // loads the GameItem data into array
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate { $0.score > 0 },
           sort: \GameItem.score,
           order: .forward) private var gameItems: [GameItem]
    @Environment(\.dismiss) var dismiss
    
    // GameItems for active game to save score
    @State private var score: GameItem = GameItem()
    @State private var highScore: GameItem?
    @State private var accumulatedPoints : Int = 0
    
    // gameOver and isPaused booleans for toggling
    @Bindable var gameStatus: GameStatus
    @State private var isStarted: Bool = true
    
    // Game pieces
    @State private var direction = Direction.left
    @State private var theSnake: [CGPoint] = [CGPoint(x: 0, y: 0)] // .count - 1 serves as current score
    @State private var foodPosition = CGPoint(x: 0, y: 0)
    @State private var startPosition: CGPoint = .zero
    
    let snakeSize:CGFloat = 22 // Size of 1 pixel
    
    // Speed adjustment properties
    @State private var timerInterval: Double = 0.13
    @State private var lastSpeedIncreaseScore: Int = 0
    
    var timerPublisher: Publishers.Autoconnect<Timer.TimerPublisher> {
        Timer.publish(every: timerInterval, on: .main, in: .common).autoconnect()
    }
    
    enum Direction {
        case up, down, left, right
    }
    
    @State private var playAreaLocalWidth: CGFloat = 0
    @State private var playAreaLocalHeight: CGFloat = 0
    
    var body: some View {
        
        GeometryReader { geometry in
            // Define game area that is smaller than the screen
            let playAreaWidth = geometry.size.width * 0.9
            let playAreaHeight = geometry.size.height * 0.8

            ZStack {
                
                //Background color
                Color("defaultBackgroundColor")
                    .ignoresSafeArea()
                
                HStack {
                    Text("score: \(theSnake.count - 1)")
                        .padding()
                        .monospaced()
                        .foregroundStyle(Color("defaultFontColor"))
                    
                    Spacer()
                    
                    Button(action: {
                        gameStatus.isGamePaused.toggle()
                    }) {
                        Text("bank: \(accumulatedPoints)")
                            .padding()
                            .monospaced()
                            .foregroundStyle(Color("defaultFontColor"))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                
                // Play Area
                ZStack {
                    
                    // Snake
                    ForEach(0..<theSnake.count, id: \.self) { index in
                        Rectangle()
                            .frame(width: self.snakeSize, height: self.snakeSize)
                            .foregroundColor(Color("defaultSnakeColor")) // SNAKE COLOR
                            .position(self.theSnake[index])
                    }
                    Rectangle() // Food
                        .fill(Color("defaultFoodColor")) // FOOD COLOR
                        .frame(width: self.snakeSize, height: self.snakeSize)
                        .position(self.foodPosition)
                }
                // Set frame and center it
                .frame(width: playAreaWidth, height: playAreaHeight)
                // Draw border
                .border(Color("defaultFontColor"), width: 3)
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                
                // onAppear: update play bounds and set inital positions
                .onAppear() {
                    
                    // Update play area bounds
                    self.playAreaLocalWidth = playAreaWidth
                    self.playAreaLocalHeight = playAreaHeight
                    
                    if gameItems.count > 0 {
                        self.highScore = calculateHighScore()
                    }
                    self.foodPosition = changeRectPosition()
                    self.theSnake[0] = changeRectPosition()
                }
                // Handle swipe gestures
                .highPriorityGesture(
                    DragGesture(minimumDistance: 15)
                        .onEnded { gesture in
                            let translation = gesture.translation
                            if abs(translation.width) > abs(translation.height) {
                                // Horizontal swipe
                                if translation.width > 0 && direction != .left {
                                    direction = .right
                                } else if translation.width < 0 && direction != .right {
                                    direction = .left
                                }
                            } else {
                                // Vertical Swipe
                                if translation.height > 0 && direction != .up{
                                    direction = .down
                                } else if translation.height < 0 && direction != .down {
                                    direction = .up
                                }
                            }
  
                            }
                        )
                // Update snake movement on each timer tick
                .onReceive(self.timerPublisher) { _ in
                    if !self.gameStatus.isGameOver && !self.gameStatus.isGamePaused {
                        self.moveSnake()
                        
                        // Check for food collision
                        if theSnake.first == foodPosition {
                            theSnake.append(theSnake.first!) // Snake grows
                            foodPosition = changeRectPosition()
                        }
                    }
                }
                
                HStack {
                    Button(action: {
                        gameStatus.isGamePaused.toggle()
                    }) {
                        Image(systemName: "powerplug.portrait")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 35, height: 35)
                            .foregroundColor(Color("defaultFontColor"))
                            .padding()
                    }
                    
                    Button(action: {
                        gameStatus.isGamePaused.toggle()
                    }) {
                        Image(systemName: "pause.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 35, height: 35)
                            .foregroundColor(Color("defaultFontColor"))
                            .padding()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                
                
            } // End of ZStack
        } // End of GeometryReader
        .edgesIgnoringSafeArea(.bottom)
        // Game Over sheet.
        .sheet(isPresented: $gameStatus.isGameOver) {
            VStack {
                Text("game over")
                    .monospaced()
                    .padding()
                    .font(.title2)
                
                Button("new game", action: {
                    gameStatus.isGameOver.toggle()
                    score = startNewGame()
                    // Call gameOver() ??
                })
                .monospaced()
                .frame(width: 150, height: 50)
                .background(Color("defaultButtonColor"))
                .foregroundStyle(Color("defaultFontColor"))
                
                Button("quit") {
                    dismiss()
                }
                .monospaced()
                .frame(width: 150, height: 50)
                .background(Color("defaultButtonColor"))
                .foregroundStyle(Color("defaultFontColor"))
                
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("defaultBackgroundColor"))
            .interactiveDismissDisabled(true)
        }
        // Pause sheet (if needed).
        .sheet(isPresented: $gameStatus.isGamePaused) {
            VStack {
                Image(systemName: "pause.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(Color("defaultFontColor"))
                    .padding()
                
                Text("high score: \(highScore?.score ?? 0)")
                    .monospaced()
                    .bold()
                    .padding()
                
                Text("accumulated points: \(accumulatedPoints)")
                    .monospaced()
                    .bold()
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("defaultBackgroundColor"))
        }
    }
    // MARK: - Game View Functions
    
    func moveSnake() {
        // Check for boundary collisions first.
          let head = theSnake[0]
          if head.x < 0 || head.x > playAreaLocalWidth ||
             head.y < 0 || head.y > playAreaLocalHeight {
              gameOver()
              return
          }
          
          // Calculate new head position.
          var newHead = head
          switch direction {
          case .down:
              newHead.y += snakeSize
          case .up:
              newHead.y -= snakeSize
          case .left:
              newHead.x -= snakeSize
          case .right:
              newHead.x += snakeSize
          }
          
          // Move body segments.
          var prev = theSnake[0]
          theSnake[0] = newHead
          for index in 1..<theSnake.count {
              let current = theSnake[index]
              theSnake[index] = prev
              prev = current
          }
          
          // Check for self-collision.
          for segment in theSnake.dropFirst() {
              if newHead == segment {
                  gameOver()
                  return
              }
          }
        
        // Increase speed every 15 points
        let currentScore = theSnake.count - 1
        if currentScore >= lastSpeedIncreaseScore + 15 {
            lastSpeedIncreaseScore = currentScore
            timerInterval = max(0.05, timerInterval - 0.02)
        }
      }
    
    // Handles game over logic.
    func gameOver() {
        gameStatus.isGameOver.toggle()
        if theSnake.count > 1 {
            score.score = theSnake.count - 1
            saveGameItem()
        }
    }
    
    func changeRectPosition() -> CGPoint {
        
        // Calculate how many snake segments fit in play area
        let columns = Int(playAreaLocalWidth / snakeSize)
        let rows = Int(playAreaLocalHeight / snakeSize)
        let randomColumn = CGFloat(Int.random(in: 0..<columns))
        let randomRow = CGFloat(Int.random(in: 0..<rows))
        
        // Offset random position so snake/food is centered in cell
        let posX = randomColumn * snakeSize + snakeSize / 2
        let posY = randomRow * snakeSize + snakeSize / 2
        
        return CGPoint(x: posX, y: posY)
    }
    
    func saveGameItem() {
        context.insert(score)
        try! context.save()

        score = GameItem() // Initialize new game with score = 0
        print("new game created")
    }
    
    func calculateHighScore() -> GameItem {
        print("calculateHighScore() has been entered")
        for item in gameItems {
            if item.score > self.highScore?.score ?? 0 {
                highScore = item
            }
        }

//        highScore = gameItems[0] // write sorting function instead of depending on query sort
        print("calculateHighScore: \(String(describing: highScore?.score))")
        return highScore ?? GameItem()
    }
    
    func startNewGame() -> GameItem {
        
        // Save current GameItem
        saveGameItem()
        
        // Initialize new GameItem
        score = GameItem()
        
        // Reset Game Board
        if gameItems.count > 0 {
            self.highScore = calculateHighScore()
        }
        theSnake = [CGPoint(x: 0, y: 0)] // Set Snake back to 1 pxl
        
        self.foodPosition = changeRectPosition()
        self.theSnake[0] = changeRectPosition()
        
        // Update highScore as needed
        self.highScore = calculateHighScore()
        
        // Update accumulatedPoints
        calculateAccumulatedPoints()
        
        // Reset speed-related variables
        timerInterval = 0.15
        lastSpeedIncreaseScore = 0
        
        return score
    }
    
    func calculateAccumulatedPoints() {
        accumulatedPoints = gameItems.reduce(0) { $0 + $1.score }
    }
}

// MARK: - Game Menu
struct GameMenuView: View {
    
    var body: some View {
        Text("Game Menu")
        
        
        Button("restart") {
        }
        // resume active game if game is paused
        
        // quit game if game is paused (do not save score)
        
        // save game if game over
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .modelContainer(for: GameItem.self, inMemory: true)
        .environment(GameStatus())
}
