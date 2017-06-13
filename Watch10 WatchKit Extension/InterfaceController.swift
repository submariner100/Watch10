//
//  InterfaceController.swift
//  Watch10 WatchKit Extension
//
//  Created by Macbook on 12/06/2017.
//  Copyright © 2017 Chappy-App. All rights reserved.
//

import WatchKit
import Foundation
import HealthKit


class InterfaceController: WKInterfaceController {

     @IBOutlet var activityType: WKInterfacePicker!
     
     let activities: [(String, HKWorkoutActivityType)] = [("Cycling", .cycling), ("Running", .running), ("Swimming", .swimming), ("Wheelchair", .wheelchairRunPace)]
     
     var selectedActivity = HKWorkoutActivityType.cycling
     
     
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        var items = [WKPickerItem]()
     
        for activity in activities {
          
          let item = WKPickerItem()
          item.title = activity.0
          items.append(item)
          
     }
     
     activityType.setItems(items)
     
     }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
     @IBAction func activityPickerChange(_ value: Int) {
     
          selectedActivity = activities[value].1
     
     }

     @IBAction func startWorkoutTapped() {
     
          guard HKHealthStore.isHealthDataAvailable() else { return }
          
          WKInterfaceController.reloadRootControllers(withNames: ["WorkoutInterfaceController"], contexts: [selectedActivity])
          
     
     }
}
