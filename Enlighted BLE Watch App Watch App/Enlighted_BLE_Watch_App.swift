//
//  Enlighted_BLE_Watch_AppApp.swift
//  Enlighted BLE Watch App Watch App
//
//  Created by Dylan Suzuki on 5/17/24.
//  Copyright © 2024 Bryce Suzuki. All rights reserved.
//

import SwiftUI
import CoreMotion

@main
struct Enlighted_BLE_Watch_App_Watch_AppApp: App {
    @State var showingLaunchImage = true
    
    @State var workoutManager = WorkoutManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(BLEConnectionController())
                .environmentObject(workoutManager)
        }
    }
}
