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

final class GameSettings: ObservableObject {
    @Published var controlMode: MainMenuView.ControlMode = .drag
    @Published var soundEffectsEnabled: MainMenuView.SoundMode = .on
}

// MARK: - Content View
struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate { $0.score > 0 }, sort: \GameItem.score, order: .forward) private var gameItems: [GameItem]
    
    @StateObject private var gameSettings = GameSettings()
    @Environment(GameStatus.self) private var gameStatus
    
    var body: some View {
//        GameView(gameStatus: gameStatus)
        MainMenuView()
            .environmentObject(gameSettings)
    }
}

// MARK: - Main Menu
struct MainMenuView: View {
    
    // Define the 2 control options
    enum ControlMode: String, CaseIterable, Identifiable {
        var id: String { self.rawValue }
        case drag = "drag"
        case tilt = "tilt"
    }
    enum SoundMode: String, CaseIterable, Identifiable {
        var id: String { self.rawValue }
        case on = "on"
        case off = "off"
    }
    
    // State var to track selection
    @State private var selectedMode: ControlMode = .drag
    @State private var soundEffects: SoundMode = .on
    
    @State private var isGameActive: Bool = false
    @State private var inSettings: Bool = false
    @Environment(GameStatus.self) private var gameStatus
    @EnvironmentObject private var gameSettings: GameSettings
    
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
            ZStack {
                VStack {
                    Text("Swipe down to close")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                    Divider()
                        .frame(width: 40)
                        .background(Color.secondary)
                        .cornerRadius(2)
                    Spacer()
                }
                
                VStack {
                
                    HStack {
                        Text("play mode")
                            .monospaced()
                            
                        Picker("control mode", selection: $selectedMode) {
                            ForEach(ControlMode.allCases) { mode in
                                Text(mode.rawValue)
                                    .tag(mode)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding()
                    }
                    
                    HStack {
                        Text("sound effects")
                            .monospaced()

                        Picker("sound effects", selection: $soundEffects) {
                            ForEach(SoundMode.allCases) { mode in
                                Text(mode.rawValue)
                                    .tag(mode)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding()
                    }
                }
            }
            .padding()
            .onDisappear {
                // Upddate shared setting when sheet dismissed
                gameSettings.controlMode = selectedMode
                gameSettings.soundEffectsEnabled = soundEffects
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("defaultBackgroundColor"))
        }
        .interactiveDismissDisabled(false)
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
    
    // scenePhase to handle interupts
    @Environment(\.scenePhase) private var scenePhase
    
    // Power up alert
    @State private var showShakeAlert: Bool = false
    
    // GameItems for active game to save score
    @State private var score: GameItem = GameItem()
    @State private var highScore: GameItem?
    @AppStorage("bankPoints") private var bankPoints: Int = 0
    
    // gameOver and isPaused booleans for toggling
    @Bindable var gameStatus: GameStatus
    @State private var isStarted: Bool = true
    @State private var powerUpMenu = false
    
    // Game pieces
    @State private var direction = Direction.left
    @State private var theSnake: [CGPoint] = [CGPoint(x: 0, y: 0)]
    @State private var scoreAccumulator: Int = 0
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
    
    enum ControlMode {
        case drag
        case tilt
    }
    
    enum SoundMode {
        case on
        case off
    }
    
    @EnvironmentObject private var gameSettings: GameSettings
    @State private var motionManager = MotionManager()

    
    var body: some View {
        
        ZStack {
            gameLayer
            if showShakeAlert {
                shakeAlert
            }
        }
    }
        
        
    // MARK: - Main Game Layer
    private var gameLayer: some View {
        GeometryReader { geometry in
            // Define game area that is smaller than the screen
            let playAreaWidth = geometry.size.width * 0.9
            var playAreaHeight = geometry.size.height * 0.8
            
            ZStack {
                
                //Background color
                Color("defaultBackgroundColor")
                    .ignoresSafeArea()
                
                HStack {
                    Text("score: \(scoreAccumulator + (theSnake.count - 1))")
                        .padding()
                        .monospaced()
                        .foregroundStyle(Color("defaultFontColor"))
                    
                    Spacer()
                    
                    Button(action: {
                        gameStatus.isGamePaused.toggle()
                    }) {
                        Text("bank: \(bankPoints)")
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
                .frame(width: playAreaLocalWidth, height: playAreaLocalHeight)
                .contentShape(Rectangle())
                .overlay(
                  Rectangle()
                    .strokeBorder(Color("defaultFontColor"), lineWidth: 3)
                )
                .clipped()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                // onAppear: update play bounds and set inital positions
                .onAppear() {
                    
                    // Compute the “ideal” play area
                    let rawW = geometry.size.width  * 0.9
                    let rawH = geometry.size.height * 0.8

                    // How many whole segments fit?
                    let columns = Int(rawW / snakeSize)
                    let rows    = Int(rawH / snakeSize)

                    // Play area exact multiple of snakeSize
                    let fittedW = CGFloat(columns) * snakeSize
                    let fittedH = CGFloat(rows)    * snakeSize

                    // Store as true bounds
                    playAreaLocalWidth  = fittedW
                    playAreaLocalHeight = fittedH

                    if !gameItems.isEmpty {
                      highScore = calculateHighScore()
                    }
                    foodPosition = changeRectPosition()
                    theSnake[0]  = changeRectPosition()
                    
                    if bankPoints == 0 {
                        let totalFromHistory = gameItems.reduce(0) { $0 + $1.score }
                        bankPoints = totalFromHistory
                    }
                }
                // Handle swipe gestures
                .if(gameSettings.controlMode == .drag) { view in
                    view.highPriorityGesture(
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
                }
                // Update snake movement on each timer tick
                .onReceive(self.timerPublisher) { _ in
                    // If paused or game over, don't update game anymore
                    if gameStatus.isGamePaused || gameStatus.isGameOver || powerUpMenu {
                        return
                    }
                    
                    if gameSettings.controlMode == .tilt {
                        let tiltThreshold = 0.2
                        
                        // Horizontal direction: positive roll is a tilt to the right
                        if motionManager.roll > tiltThreshold && direction != .left {
                            direction = .right
                        } else if motionManager.roll < -tiltThreshold && direction != .right {
                            direction = .left
                        }
                        // Vertical direction: positive pitch is a tilt downward
                        if motionManager.pitch > tiltThreshold && direction != .up {
                            direction = .down
                        } else if motionManager.pitch < -tiltThreshold && direction != .down {
                            direction = .up
                        }
                    }
                    
                    moveSnake()
                    
                    // Check for food collision
                    if theSnake.first == foodPosition {
                        if gameSettings.soundEffectsEnabled == .on {
                            SoundManager.playSound(sound: "munch", type: "wav")
                        }
                        theSnake.append(theSnake.first!) // Snake grows
                        foodPosition = changeRectPosition()
                        bankPoints += 1
                    }
                }
                
                HStack {
                    Button(action: {
                        powerUpMenu.toggle()
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
            .background(
                ShakeDetector(onShake: {
                    if !gameStatus.isGamePaused && !gameStatus.isGameOver {
                        resetSnake()
                    }
                })
            )
        } // End of GeometryReader
        .edgesIgnoringSafeArea(.bottom)
        // Detect changes in scene phase
        .onChange(of: scenePhase) { oldPhase, newPhase in  // 2 param enclosure required
            if newPhase != .active {
                // Pause game if app is inactive
                gameStatus.isGamePaused = true
                print("Game paused due to scene change")
            }
        }
        // Game Over sheet.
        .sheet(isPresented: $gameStatus.isGameOver) {
            VStack {
                Text("game over")
                    .monospaced()
                    .padding()
                    .font(.title2)
                
                Button("new game", action: {
                    startNewGame()
                    gameStatus.isGameOver = false
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
            ZStack {
                VStack {
                    Text("Swipe down to close")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                    Divider()
                        .frame(width: 40)
                        .background(Color.secondary)
                        .cornerRadius(2)
                    Spacer()
                }
                VStack {
                    Text("high score: \(highScore?.score ?? 0)")
                        .monospaced()
                        .bold()
                        .padding()
                    
                    Text("accumulated points: \(bankPoints)")
                        .monospaced()
                        .bold()
                        .padding()
                }
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color("defaultBackgroundColor"))
        }
        .sheet(isPresented: $powerUpMenu) {
            ZStack {
                VStack {
                    Text("Swipe down to close")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                    Divider()
                        .frame(width: 40)
                        .background(Color.secondary)
                        .cornerRadius(2)
                    Spacer()
                }
                
                VStack {
                    
                    Text("shake to power up!")
                        .monospaced()
                        .bold()
                        .padding()
                    Text("requires 20 points from the bank")
                        .monospaced()
                        .bold()
                        .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("defaultBackgroundColor"))
        }
    }
        
    //MARK: - Shake Alert
    private var shakeAlert: some View {
        Text("shake detected!")
            .font(.headline)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color("defaultButtonColor").opacity(0.7))
            .foregroundColor(Color("defaultFontColor"))
            .cornerRadius(8)
            .transition(.opacity)
            .zIndex(1)
    }
    // MARK: - Game View Functions
    
    func moveSnake() {
          let head = theSnake[0]

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
        
        let half = snakeSize / 2
        
        // Check if newHead is within bounds - boundary collision
        if newHead.x - half < 0 ||
           newHead.x + half > playAreaLocalWidth ||
           newHead.y - half < 0 ||
           newHead.y + half > playAreaLocalHeight
        
        {
            // Play collision sound effect if enabled.
            if gameSettings.soundEffectsEnabled == .on {
                SoundManager.playSound(sound: "bummer", type: "wav")
            }
            gameOver()
            return
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
                  if gameSettings.soundEffectsEnabled == .on {
                      SoundManager.playSound(sound: "bummer", type: "wav")
                  }
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
        gameStatus.isGameOver = true
        let finalScore = scoreAccumulator + (theSnake.count - 1)
        if finalScore > 0 {
            bankPoints += finalScore
            
            score.score = finalScore
            saveGameItem()
        }
    }
    
    func changeRectPosition() -> CGPoint {
        
        var newPosition: CGPoint
        repeat {
            let columns = Int(playAreaLocalWidth / snakeSize)
            let rows = Int(playAreaLocalHeight / snakeSize)
            let randomColumn = CGFloat(Int.random(in: 0..<columns))
            let randomRow = CGFloat(Int.random(in: 0..<rows))
            let posX = randomColumn * snakeSize + snakeSize / 2
            let posY = randomRow * snakeSize + snakeSize / 2
            newPosition = CGPoint(x: posX, y: posY)
        } while theSnake.contains(newPosition)
        return newPosition
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
        print("calculateHighScore: \(String(describing: highScore?.score))")
        return highScore ?? GameItem()
    }
    
    func startNewGame() {
        
        // Save current GameItem
        saveGameItem()
        
        // Initialize new GameItem
        score = GameItem()
        
        // Reset score accumulator
        scoreAccumulator = 0
        
        // Reset Game Board
        if gameItems.count > 0 {
            self.highScore = calculateHighScore()
        }
        // Set Snake back to 1 pxl
        theSnake = [CGPoint(x: 0, y: 0)]
        
        self.foodPosition = changeRectPosition()
        self.theSnake[0] = changeRectPosition()
        
        // Update highScore as needed
        self.highScore = calculateHighScore()
        
        // Reset speed-related variables
        timerInterval = 0.15
        lastSpeedIncreaseScore = 0
    }
    
    func resetSnake() {
        // Only perform a reset if the bank has at least 20 points.
        guard bankPoints >= 20 else {
            print("Not enough bank points to reset snake. Required 20, but have \(bankPoints).")
            return
        }

        // Deduct cost
        bankPoints -= 20

        // Accumulate the score from the old snake
        let currentSnakeScore = theSnake.count - 1
        scoreAccumulator += currentSnakeScore

        // Remember head’s current location
        let headPosition = theSnake.first!

        // Shrink the snake to only head
        theSnake = [headPosition]
        
        // On Screen Alert
        withAnimation(.easeInOut(duration: 0.3)) {
            showShakeAlert = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.5)) {
                showShakeAlert = false
            }
        }

        print("Power‑up! Snake reset at \(headPosition). Accumulated Score: \(scoreAccumulator), Bank: \(bankPoints)")
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
