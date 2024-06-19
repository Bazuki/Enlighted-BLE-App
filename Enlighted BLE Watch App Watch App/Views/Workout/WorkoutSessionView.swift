//
//  WorkoutSessionView.swift
//  Enlighted BLE Watch App Watch App
//
//  Created by Dylan Suzuki on 6/13/24.
//  Copyright © 2024 Bryce Suzuki. All rights reserved.
//

//Credit for WorkoutSessionView to WWDC tutorial linked here: https://developer.apple.com/videos/play/wwdc2021/10009/


import SwiftUI

struct WorkoutSessionView: View {
    @State private var selection: Tab = .metrics
    @EnvironmentObject var workoutManager: WorkoutManager
    
    enum Tab {
        case controls, metrics
    }
    
    private func displayMetricsView() {
        withAnimation{
            selection = .metrics
        }
    }
    
    var body: some View {
        TabView(selection: $selection){
            WorkoutControlsView().tag(Tab.controls)
            WorkoutMetricsView().tag(Tab.metrics)
        }.tabViewStyle(.automatic)
        .onAppear{
            workoutManager.requestAuth()
            workoutManager.startWorkout(workoutType: .cardioDance)
        }
        .navigationTitle("Continuous Control")
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(selection == .controls)
        .onChange(of: workoutManager.running){ _, _ in
                displayMetricsView()
        }
        .sheet(isPresented: $workoutManager.showingSummaryView) {
            NavigationView{
                WorkoutSummaryView()
            }.toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    WorkoutSessionView()
        .environmentObject(WorkoutManager())
}
