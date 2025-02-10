//
//  Item.swift
//  Snake
//
//  Created by Maddie Nevans on 1/24/25.
//

import Foundation
import SwiftData

@Model
final class GameItem {
    var score: Int
    var gameID: String
    
    init() {
        self.score = 0
        self.gameID = UUID().uuidString
    }
}
