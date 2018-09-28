//
//  ViewController.swift
//  LocTracker
//
//  Created by Çağlar Uslu on 25.09.2018.
//  Copyright © 2018 Çağlar Uslu. All rights reserved.
//

import UIKit
import CoreLocation
import CoreData

class ViewController: UIViewController, CLLocationManagerDelegate {
    
    
    // Declare variables and constants
    
    @IBOutlet weak var startStopButton: UIButton!
    let locationManager = CLLocationManager()
    var unitFile = ProtoFiles_UnitFile()
    
    var containerURL = "https://drivebuddy.blob.core.windows.net/testere?spr=https&sr=c&sp=rwdl&sv=2017-07-29&sig=46YvUTugp6ah8JSTmqPHuC19sZkYTyIop43VOBsOGxU%3D&se=2018-09-27T10%3A36%3A46Z"
    
    var blobs = [AZSCloudBlob]()
    var container : AZSCloudBlobContainer
    var continuationToken : AZSContinuationToken?
    
    
    
    required init?(coder aDecoder: NSCoder) {
        
        var error: NSError?
        self.container = AZSCloudBlobContainer(url: URL(string: containerURL)!, error: &error)
        if ((error) != nil) {
            print("Error in creating blob container object.  Error code = %ld, error domain = %@, error userinfo = %@", error!.code, error!.domain, error!.userInfo);
        }
        
        
        self.continuationToken = nil
        
        super.init(coder: aDecoder)
    }
    
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
        
        reloadBlobList()
        synchPreviousRecords()
        
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
        unitFile = ProtoFiles_UnitFile()
        startReceivingLocationChanges()
    }
    
    func stopLocationTracking(){
        locationManager.stopUpdatingLocation()
        setUnitFile()
        
        saveDataAndSendDataToServer()
        
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
        
        
        let lat = Float(lastLocation.coordinate.latitude)
        let lon = Float(lastLocation.coordinate.longitude)
        let speed = Float(lastLocation.speed)
        let timestamp = lastLocation.timestamp.timeIntervalSince1970 // Time interval since 1970 ***
        let locData = setLocData(lat: lat, lon: lon, speed: speed, timestamp: timestamp)
        
        
        //Append UnitFile by current LocData
        
        unitFile.locData.append(locData)
        
        
        
    }
    
    func setLocData(lat: Float, lon: Float, speed: Float, timestamp: Double) -> ProtoFiles_LocData{
        var locData = ProtoFiles_LocData()
        locData.latitude = lat
        locData.longitude = lon
        locData.speed = speed
        locData.timestamp = timestamp
        return locData
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
    
    func saveDataAndSendDataToServer(){
        
        do{
            
            // SERIALIZE DATA
            
            let binaryData: Data = try unitFile.serializedData()
            
            // CORE DATA STUFF
            
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let context = appDelegate.persistentContainer.viewContext
            
            let coreUnitFile = NSEntityDescription.insertNewObject(forEntityName: "UnitFileData", into: context)
            coreUnitFile.setValue(binaryData, forKey: "binData")
            do{
                try context.save()
                print("Binary Data saved to Core Data")
            }catch{
                print("** ERROR: Binary Data couldnt be saved to Core Data")
            }
            
            ////////////////////
            
            
            let blob = container.blockBlobReference(fromName: "testere-\(NSDate().timeIntervalSince1970)")
            blob.upload(from: binaryData) { (err) in
                if err != nil{
                    coreUnitFile.setValue(false, forKey: "synched")
                    print(err!.localizedDescription)
                }else{
                    coreUnitFile.setValue(true, forKey: "synched")
                    print("UPLOADED")
                }
            }
            
            
        }catch{
            print("** ERROR: couldnt build binary data")
        }
        
        
    }
    
    
    func reloadBlobList() {
        
        print("container name " + container.name)
        
        container.listBlobsSegmented(with: nil, prefix: nil, useFlatBlobListing: false, blobListingDetails: AZSBlobListingDetails(), maxResults: 50) { (error : Error?, results : AZSBlobResultSegment?) -> Void in
            
            if error != nil {
                print("** ERROR: couldnt reload blob list   " + error!.localizedDescription)
            }else{
                self.blobs = [AZSCloudBlob]()
                
                
                for blob in results!.blobs!
                {
                    self.blobs.append(blob as! AZSCloudBlob)
                    let newBlob: AZSCloudBlob = blob as! AZSCloudBlob
                    print("blob name: " + newBlob.blobName)
                    print("counter: " + "\(self.blobs.count)")
                }
                
                self.continuationToken = results!.continuationToken
            }
            
            
            
        }
    }
    
    func synchPreviousRecords(){
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "UnitFileData")
        
        request.returnsObjectsAsFaults = false
        
        do{
            
            let results = try context.fetch(request)
            
            if results.count > 0 {
                
                for result in results as! [NSManagedObject] {
                    
                    if let synched = result.value(forKey: "synched") as? Bool {
                        
                        if !synched {
                            
                            // try uploading again
                            
                            if let binData = result.value(forKey: "binData") as? Data{
                                let blob = container.blockBlobReference(fromName: "testere-\(NSDate().timeIntervalSince1970)")
                                blob.upload(from: binData) { (err) in
                                    if err != nil{
                                        print(err!.localizedDescription)
                                    }else{
                                        
                                        do{
                                            print("UPDATED")
                                            result.setValue(true, forKey: "synched")
                                            try context.save()
                                        }catch{
                                            print("** ERROR: binary data couldnt be updated")
                                        }
                                        
                                        
                                        print("UPLOADED")
                                    }
                                }
                            }
                            
                        }
                        
                    }
                    
                }
                
            }
            
        }catch{
            
            print("** ERROR: binary data couldnt be fetched from core data")
            
        }
        
    }
    
    
    
    
    
}










