//
//  WorkoutInterfaceController.swift
//  Watch10
//
//  Created by Macbook on 12/06/2017.
//  Copyright © 2017 Chappy-App. All rights reserved.
//

import WatchKit
import Foundation
import HealthKit

enum DisplayMode {
     case distance, energy, heartRate
}


class WorkoutInterfaceController: WKInterfaceController, HKWorkoutSessionDelegate {

     @IBOutlet var quantityLabel: WKInterfaceLabel!
     @IBOutlet var unitLabel: WKInterfaceLabel!
     @IBOutlet var stopButton: WKInterfaceButton!
     @IBOutlet var resumeButton: WKInterfaceButton!
     @IBOutlet var endButton: WKInterfaceButton!
     
     var healthStore: HKHealthStore?
     var distanceType = HKQuantityTypeIdentifier.distanceCycling
     var workoutStartDate = Date()
     var activeDataQueries = [HKQuery]()
     var workoutSession: HKWorkoutSession?
     var totalEnergyBurned = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: 0)
     var totalDistance = HKQuantity(unit: HKUnit.meter(), doubleValue: 0)
     var lastHeartRate = 0.0
     let countPerMinuteUnit = HKUnit(from: "count/min")
     var displayMode = DisplayMode.distance
     var workoutIsActive = true
     
     override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        guard let activity = context as? HKWorkoutActivityType else { return }
        
        switch activity {
          
          case .cycling:
               distanceType = .distanceCycling
          
          case .running:
               distanceType = .distanceWalkingRunning
          
          case .swimming:
               distanceType = .distanceSwimming
          
          default:
               distanceType = .distanceWheelchair
          }
          
          //configure the values we want to write
          let writeTypes: Set<HKSampleType> = [.workoutType(),
          HKSampleType.quantityType(forIdentifier: .heartRate)!,
          HKSampleType.quantityType(forIdentifier: .activeEnergyBurned)!,
          HKSampleType.quantityType(forIdentifier: distanceType)!]
          
          //configure the values we want to read
          let readTypes: Set<HKObjectType> = [.activitySummaryType(), .workoutType(),
          HKObjectType.quantityType(forIdentifier: .heartRate)!,
          HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
          HKObjectType.quantityType(forIdentifier: distanceType)!]
          
          //create our health store
          healthStore = HKHealthStore()
          
          //use it to request authorization for our types
          healthStore?.requestAuthorization(toShare: writeTypes, read: readTypes) { success, error in
               
               if success {
                    
                    //start workout
                    if success {
                         
                         self.startWorkout(type: activity)
                         
                    }
               }
          }
    }
    
    func startQuery(quantityTypeIdentifier: HKQuantityTypeIdentifier) {
     
     //we only want data points after our workout start date
     let datePredicate = HKQuery.predicateForSamples(withStart: workoutStartDate, end: nil, options: .strictStartDate)
     
     //we only want data points that come from our current device
     let devicePredicate = HKQuery.predicateForObjects(from: [HKDevice.local()])
     
     //combine the two predicates into one
     let queryPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, devicePredicate])
     
     //write code to receive results from our query
     let updateHandler: (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?,
     Error?) -> Void = { query, samples, deletedObjects, queryAnchor, error in
     
     //safely typecast to a quantity sample so we can read values
     guard let samples = samples as? [HKQuantitySample] else { return }
     
     self.process(samples, type: quantityTypeIdentifier)
     
          
     }
     
     //create the query out of our type (eg. heart rate), predicate, and result handling code
     let query = HKAnchoredObjectQuery(type: HKObjectType.quantityType(forIdentifier: quantityTypeIdentifier)!, predicate: queryPredicate, anchor: nil , limit: HKObjectQueryNoLimit, resultsHandler: updateHandler)
     
     //tell HealthKit to re-run the code every time new data is available
     query.updateHandler = updateHandler
     
     //start the query running
     healthStore?.execute(query)
     
     //stash it away so we can stop it later
     activeDataQueries.append(query)
     
     
     }
     
     func startQueries() {
          
          startQuery(quantityTypeIdentifier: distanceType)
          startQuery(quantityTypeIdentifier: .activeEnergyBurned)
          startQuery(quantityTypeIdentifier: .heartRate)
          WKInterfaceDevice.current().play(.start)
          
          
     }

     override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }

     override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
     func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
     
          switch toState {
               
               case .running:
                    if fromState == .notStarted {
                         startQueries()
               }
               
               default:
                    break
          }
     
     }
     
     func startWorkout(type: HKWorkoutActivityType) {
          
          //create a workout configuration
          let config = HKWorkoutConfiguration()
          config.activityType = type
          config.locationType = .outdoor
          
          //create a workout session from that
          if let session = try? HKWorkoutSession(configuration: config) {
               
               workoutSession = session
               
               //start the workout now
               healthStore?.start(session)
               
               //reset our start date
               workoutStartDate = Date()
               
               //register to receive status updates
               session.delegate = self
               
          }
          
          
     }
     
     func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
     
     
     }
     
     func updateLabels() {
          
          switch displayMode {
               
          case .distance:
               let meters = totalDistance.doubleValue(for: HKUnit.meter())
               let kilometers = meters / 1000
               let formattedKilometers = String(format: "%.2f", kilometers)
               quantityLabel.setText(formattedKilometers)
               unitLabel.setText("KILOMETERS")
          
          case .energy:
               let kiloCalories = totalEnergyBurned.doubleValue(for: HKUnit.kilocalorie())
               let formattedKiloCalories = String(format: "%.02", kiloCalories)
               quantityLabel.setText(formattedKiloCalories)
               unitLabel.setText("CALORIES")
               
          case .heartRate:
               let heartRate = String(Int(lastHeartRate))
               quantityLabel.setText(heartRate)
               unitLabel.setText("BEATS / MINUTE")
               
          }
     }
     
     func process(_ samples: [HKQuantitySample], type: HKQuantityTypeIdentifier) {
          
          //ignore updates while we are paused
          guard workoutIsActive else { return }
          
          //loop over all the samples we have been sent
          for sample in samples {
               
               //this is a calorie count
               if type == .activeEnergyBurned {
                    
                    //find out how many calaries were burned
                    let newEnergy = sample.quantity.doubleValue(for: HKUnit.kilocalorie())
                    
                    //get our current total calorie burn
                    let currentEnergy = totalEnergyBurned.doubleValue(for: HKUnit.kilocalorie())
                    
                    //add the two together
                    totalEnergyBurned = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: currentEnergy + newEnergy)
                    
                    //print out the new total for debugging purposes
                    print("Total energy: \(totalEnergyBurned)")
                    
               } else if type == .heartRate {
                    
                    //we've got a heart rate - just update the property
                    lastHeartRate = sample.quantity.doubleValue(for: countPerMinuteUnit)
                    print("Last heart rate: \(lastHeartRate)")
                    
               } else if type == distanceType {
               
                    //we've got a distance travelled value
                    let newDistance = sample.quantity.doubleValue(for: HKUnit.meter())
                    let currentDistance = totalDistance.doubleValue(for: HKUnit.meter())
                    totalDistance = HKQuantity(unit: HKUnit.meter(), doubleValue: currentDistance + newDistance)
                    print("Total distance: \(totalDistance)")
               
               }
           
          }
          
          //update labels
               updateLabels()
     }

     @IBAction func changedisplayMode() {
     
     
     }
     
     @IBAction func stopWorkout() {
     
     
     }
    
     @IBAction func resumeWorkout() {
     
     
     }
     
     @IBAction func endWorkout() {
     
     
     }
     
     
    }
