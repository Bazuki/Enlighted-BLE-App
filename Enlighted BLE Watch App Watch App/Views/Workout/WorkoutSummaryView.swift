//
//  WorkoutSummaryView.swift
//  Enlighted BLE Watch App Watch App
//
//  Created by Dylan Suzuki on 6/17/24.
//  Copyright © 2024 Bryce Suzuki. All rights reserved.
//

//Credit for WorkoutSummaryView to WWDC tutorial linked here: https://developer.apple.com/videos/play/wwdc2021/10009/


import SwiftUI

struct WorkoutSummaryView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
    var body: some View {
        if workoutManager.workout == nil{
            ProgressView("Saving Workout")
                .navigationBarHidden(true)
        } else {
            ScrollView(.vertical){
                VStack(alignment: .leading){
                    SummaryMetricView(title: "Total Time", value: durationFormatter.string(from: workoutManager.workout?.duration ?? 0.0) ?? "")
                    SummaryMetricView(title: "Avg. Heart Rate", value: workoutManager.averageHeartRate.formatted(.number.precision(.fractionLength(0))))
                    Button("Done") {
                        NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: Constants.MESSAGES.ENDED_WORKOUT)))
                        dismiss()
                    }
                }.scenePadding()
            }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    WorkoutSummaryView()
}

struct SummaryMetricView: View {
    var title: String
    var value: String
    
    var body: some View {
        Text(title)
        Text(value)
            .font(.system(.title2, design: .rounded).lowercaseSmallCaps())
            .foregroundColor(.accentColor)
        Divider()
    }
}
