//
//  ViewController.swift
//  LocTracker
//
//  Created by Çağlar Uslu on 25.09.2018.
//  Copyright © 2018 Çağlar Uslu. All rights reserved.
//

import UIKit
import CoreLocation

class ViewController: UIViewController, CLLocationManagerDelegate {
    
    
    // Declare variables and constants
    
    @IBOutlet weak var startStopButton: UIButton!
    let locationManager = CLLocationManager()
    var unitFile = ProtoFiles_UnitFile()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        // Set delegates
        
        locationManager.delegate = self
        
        
        // Check location authorization status
        
        let status  = CLLocationManager.authorizationStatus()
        if status == .notDetermined {
            locationManager.requestAlwaysAuthorization()
            return
        }
    }
    
    
    @IBAction func startStopButtonPressed(_ sender: Any) {
        
        // Begins location tracking on "Start", stops location tracking on "Stop"
        
        if startStopButton.currentTitle! == "Start"{
            startStopButton.setTitle("Stop", for: .normal)
            beginLocationTracking()
        }else{
            startStopButton.setTitle("Start", for: .normal)
            stopLocationTracking()
        }
        
    }
    
    
    func beginLocationTracking(){
        startReceivingLocationChanges()
    }
    
    func stopLocationTracking(){
        locationManager.stopUpdatingLocation()
        setUnitFile()
        print(unitFile)
    }
    
    func startReceivingLocationChanges() {
        let authorizationStatus = CLLocationManager.authorizationStatus()
        if authorizationStatus != .authorizedWhenInUse && authorizationStatus != .authorizedAlways {
            print("User has not authorized access to location information.")
            return
        }
        
        
        // Do not start services that aren't available.
        if !CLLocationManager.locationServicesEnabled() {
            print("Location services are not available.")
            return
        }
        
        
        // Configure and start the service.
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone  // In meters.
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
    }
    
    
    func locationManager(_ manager: CLLocationManager,  didUpdateLocations locations: [CLLocation]) {
        
        
        // Get last location
        
        let lastLocation = locations.last!
        
        
        // Set locData
        
        let locData = ProtoFiles_LocData()
        let lat = Float(lastLocation.coordinate.latitude)
        let lon = Float(lastLocation.coordinate.longitude)
        let speed = Float(lastLocation.speed)
        let timestamp = lastLocation.timestamp.timeIntervalSince1970 // Time interval since 1970 ***
        setLocData(lat: lat, lon: lon, speed: speed, timestamp: timestamp)
        
        
        //Append UnitFile by current LocData
        
        unitFile.locData.append(locData)
        
    }
    
    func setLocData(lat: Float, lon: Float, speed: Float, timestamp: Double){
        var locData = ProtoFiles_LocData()
        locData.latitude = lat
        locData.longitude = lon
        locData.speed = speed
        locData.timestamp = timestamp
    }
    
    func setUnitFile(){
        unitFile.startTime = (unitFile.locData.first?.timestamp)!
        unitFile.endTime = (unitFile.locData.last?.timestamp)!
        unitFile.timezoneoffset = setGMT()
    }
    
    func setGMT() -> Int32 {
        var localTimeZoneAbbreviation: String { return TimeZone.current.abbreviation() ?? ""}
        let gmt = localTimeZoneAbbreviation.replacingOccurrences(of: "GMT", with: "")
        let intGMT = Int32(gmt)!
        return intGMT
    }
    
}










