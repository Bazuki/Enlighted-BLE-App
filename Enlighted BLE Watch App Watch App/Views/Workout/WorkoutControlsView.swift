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
            Spacer()
            VStack{
                Spacer()
                Button {
                    NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.ENDED_WORKOUT), object: nil)
                } label: {
                    Image(systemName: "arrowshape.backward.fill")
                }
                .frame(width: 75, height: 75)
                .tint(Color.purple)
                .font(.title2)
                Text("Back")
                Spacer()
            }
            Spacer()
        }
        .ignoresSafeArea()
    }
}

#Preview {
    WorkoutControlsView()
}
