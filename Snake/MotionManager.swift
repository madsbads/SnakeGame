//
//  MotionManager.swift
//  Snake
//
//  Created by Maddie Nevans on 2/10/25.
//

import Foundation
import CoreMotion

class MotionManager: ObservableObject {
    private var motionManager: CMMotionManager
    @Published var pitch: Double = 0.0
    @Published var roll: Double = 0.0
    
    init() {
        self.motionManager = CMMotionManager()
        self.motionManager.deviceMotionUpdateInterval = 0.01
        if self.motionManager.isDeviceMotionAvailable {
            self.motionManager.startDeviceMotionUpdates(to: .main){ [weak self] data, error in
                guard let data = data, error == nil else { return }
                
                // Update published properties with current pitch and roll vals
                self?.pitch = data.attitude.pitch
                self?.roll = data.attitude.roll
                
            }
        }
    }
    
}
