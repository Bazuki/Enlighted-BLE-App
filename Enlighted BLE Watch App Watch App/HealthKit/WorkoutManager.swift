//
//  WorkoutManager.swift
//  Enlighted BLE Watch App Watch App
//
//  Created by Dylan Suzuki on 6/13/24.
//  Copyright © 2024 Bryce Suzuki. All rights reserved.
//


//Credit for WorkoutManager to WWDC tutorial linked here: https://developer.apple.com/videos/play/wwdc2021/10009/

import Foundation
import HealthKit

class WorkoutManager: NSObject, ObservableObject {
    var selectedWorkout: HKWorkoutActivityType?
    
    @Published var showingSummaryView: Bool = false {
        didSet{
            if showingSummaryView == false {
                resetWorkout()
            }
        }
    }
    
    let healthStore = HKHealthStore()
    var session: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?
    
    func startWorkout(workoutType: HKWorkoutActivityType) {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workoutType
        configuration.locationType = .indoor
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
        } catch {
            return
        }
        
        builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
        
        session?.delegate = self
        builder?.delegate = self
        
        let startDate = Date()
        session?.startActivity(with: startDate)
        builder?.beginCollection(withStart: startDate) {(success, error) in
                //Workout started
            print("Started workout")
        }
    }
    
    //Requests authorization for the healthKit functionality
    func requestAuth() {
        let typesToShare: Set = [
            HKQuantityType.workoutType()
        ]
        
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
//            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
//            HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.activitySummaryType(),
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead){ (success, error) in
            //handle errors
        }
    }
    
    //MARK: - State Control
    
    // The workout session state
    @Published var running = false
    
    func pause() {
        session?.pause()
    }
    
    func resume() {
        session?.resume()
    }
    
    func togglePause() {
        if (running){
            print("pausing workout")
            pause()
        } else {
            print("resuming workout")
            resume()
        }
    }
    
    func endWorkout() {
        if session?.state != .ended{
            print("Ending workout")
            session?.end()
            showingSummaryView = true
        }
    }
    
    //MARK: - Workout Metrics
    @Published var averageHeartRate: Double = 0
    @Published var heartRate: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var workout: HKWorkout?
    
    func updateForStatistics(_ statistics: HKStatistics?) {
        //ensure statistics is not nil
        guard let statistics = statistics else {return}
        
        //Update published workout metrics based on the type of statistic
        DispatchQueue.main.async {
            switch statistics.quantityType {
            case HKQuantityType.quantityType(forIdentifier: .heartRate):
                let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                self.heartRate = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit) ?? 0
                self.averageHeartRate = statistics.averageQuantity()?.doubleValue(for: heartRateUnit) ?? 0
            case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                let energyUnit = HKUnit.kilocalorie()
                self.activeEnergy = statistics.sumQuantity()?.doubleValue(for: energyUnit) ?? 0
            default:
                return
            }
            
        }
    }
    
    func resetWorkout() {
        print("resetting workout")
        selectedWorkout = nil
        builder = nil
        session = nil
        workout = nil
        activeEnergy = 0
        averageHeartRate = 0
        heartRate = 0
    }
}


// MARK: - HKWorkoutSessionDelegate
extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            self.running = toState == .running
        }
        
        //Wait for the session to transition states before ending the builder
        if toState == .ended {
            builder?.endCollection(withEnd: date){ (success, error) in
                if (error != nil){
                    NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.COULDNT_SAVE_WORKOUT_DUE_TO_ERROR), object: error)
                }
                self.builder?.finishWorkout {(workout, error) in
                    if (error != nil){
                        NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.COULDNT_SAVE_WORKOUT_DUE_TO_ERROR), object: error)
                    }
                    DispatchQueue.main.async {
                        self.workout = workout
                    }
                }
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        self.running = false
        print("Workout failed with error: \(error)")
    }
    
    
}

//MARK: - HKLiveWorkoutBuilderDelegate
extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else {return}
            
            let statistics = workoutBuilder.statistics(for: quantityType)
            
            updateForStatistics(statistics)
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        //Necessary stub for conformance - not used
    }
    
}
