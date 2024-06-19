//
//  WorkoutControlsView.swift
//  Enlighted BLE Watch App Watch App
//
//  Created by Dylan Suzuki on 6/13/24.
//  Copyright © 2024 Bryce Suzuki. All rights reserved.
//

//Credit for WorkoutControlsView to WWDC tutorial linked here: https://developer.apple.com/videos/play/wwdc2021/10009/


import SwiftUI

struct WorkoutControlsView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    //Dismiss environment variable, which lets us go back to the device control page
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        HStack{
            VStack{
                Button {
                    workoutManager.endWorkout()
                } label: {
                    Image(systemName: "xmark")
                }
                .tint(Color.red)
                .font(.title2)
                Text("End")
            }
            VStack{
                Button {
                    workoutManager.togglePause()
                } label: {
                    Image(systemName: workoutManager.running ? "pause" : "play")
                }
                .tint(Color.yellow)
                .font(.title2)
                Text(workoutManager.running ? "Pause" : "Resume")
            }
        }
    }
}

#Preview {
    WorkoutControlsView()
}
