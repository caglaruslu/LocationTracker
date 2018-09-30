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
import CoreMotion
import Reachability

class ViewController: UIViewController, CLLocationManagerDelegate, NSFetchedResultsControllerDelegate {
    
    
    // Declare variables and constants
    
    @IBOutlet weak var startStopButton: UIButton!
    let locationManager = CLLocationManager()
    var unitFile = ProtoFiles_UnitFile()
    var locData = ProtoFiles_LocData()
    
    var containerURL = "https://drivebuddy.blob.core.windows.net/testere?sp=rwdl&sr=c&sig=BdWX/DBW%2ByiBQmgRzi8nNsi8luVMCAHGt1H%2BAwdDsuA%3D&spr=https&sv=2017-07-29&se=2018-09-30T11%3A09%3A06Z"
    
    var blobs = [AZSCloudBlob]()
    var container : AZSCloudBlobContainer
    var continuationToken : AZSContinuationToken?
    
    
    var motionManager = CMMotionManager()
    
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
        
//        deleteCoreDataObjects()
        
        locationManager.delegate = self
        
        // Check location authorization status
        
        let status  = CLLocationManager.authorizationStatus()
        if status == .notDetermined {
            locationManager.requestAlwaysAuthorization()
            return
        }
        
        
        
//        reloadBlobList()
        
        checkConnection {
            self.synchPreviousRecords()
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
        unitFile = ProtoFiles_UnitFile()
        measureAcceleration()
        startReceivingLocationChanges()
    }
    
    func stopLocationTracking(){
        stopMeasuringAcceleration()
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
    
    
    func measureAcceleration(){
        
        motionManager.startAccelerometerUpdates(to: OperationQueue.current!) { (data, error) in
            if let myData = data{
                
                let accX = myData.acceleration.x
                let accY = myData.acceleration.y
                let accZ = myData.acceleration.z
                
                let timestp = Date().timeIntervalSince1970
                
                var accData = ProtoFiles_AccData()
                accData.timestamp = timestp
                accData.x = Float(accX)
                accData.y = Float(accY)
                accData.z = Float(accZ)
                self.locData.accData.append(accData)
            }
        }
        
    }
    
    func stopMeasuringAcceleration(){
        
        motionManager.stopAccelerometerUpdates()
        
    }
    
    
    func locationManager(_ manager: CLLocationManager,  didUpdateLocations locations: [CLLocation]) {
        
        
        // Get last location
        
        let lastLocation = locations.last!
        
        
        // Set locData
        
        locData.latitude = Float(lastLocation.coordinate.latitude)
        locData.longitude = Float(lastLocation.coordinate.longitude)
        locData.speed = Float(lastLocation.speed)
        locData.timestamp = lastLocation.timestamp.timeIntervalSince1970 // Time interval since 1970 ***
        
        if locData.accData.count > 0 {
            unitFile.locData.append(locData)
        }
        
        locData.accData.removeAll()
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
            coreUnitFile.setValue(false, forKey: "synched")
            do{
                try context.save()
                print("Binary Data saved to Core Data")
            }catch{
                print("** ERROR: Binary Data couldnt be saved to Core Data")
            }
            
            ////////////////////
            
            
            let blob = container.blockBlobReference(fromName: "caglar-\(NSDate().timeIntervalSince1970)")
            blob.upload(from: binaryData) { (err) in
                if err != nil{
                    coreUnitFile.setValue(false, forKey: "synched")
                    do{
                        try context.save()
                        print("synched false saved to Core Data")
                    }catch{
                        print("** ERROR: synched false couldnt be saved to Core Data")
                    }
//                    print(err!.localizedDescription)
                    
                }else{
                    coreUnitFile.setValue(true, forKey: "synched")
                    do{
                        try context.save()
                        print("synched true saved to Core Data")
                    }catch{
                        print("** ERROR: synched true couldnt be saved to Core Data")
                    }
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
//                print("** ERROR: couldnt reload blob list   " + error!.localizedDescription)
                print("ERROR reloading blob list")
            }else{
                self.blobs = [AZSCloudBlob]()
                
                
                for blob in results!.blobs!
                {
                    self.blobs.append(blob as! AZSCloudBlob)
                    let newBlob: AZSCloudBlob = blob as! AZSCloudBlob
                    print("blob name: " + newBlob.blobName + "  URL: " + newBlob.storageUri.primaryUri.absoluteString)
                    print("counter: " + "\(self.blobs.count)")
                    
//                    let blobWillBeRemoved = self.container.blockBlobReference(fromName: "caglar-1538225262.5781")
//                    blobWillBeRemoved.delete(completionHandler: { (error) in
//                        if error != nil{
//                            print("** ERROR: Blob couldnt be deleted")
//                        }else{
//                            print("blob deleted")
//                        }
//                    })
                    
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
                
                print("\(results.count)" + " core data objects")
                
                for result in results as! [NSManagedObject] {
                    
                    
                    if let synched = result.value(forKey: "synched") as? Bool {
                        
                        print(synched)
                        
                        if !synched {
                            
                            // try uploading again
                            
                            if let binData = result.value(forKey: "binData") as? Data{
                                let blob = container.blockBlobReference(fromName: "caglar-\(NSDate().timeIntervalSince1970)")
                                blob.upload(from: binData) { (err) in
                                    if err != nil{
//                                        print(err!.localizedDescription)
                                        print("ERROR uploading blob")
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
                        
                    }else{
                        print("SYNCHED NOT FOUND")
                    }
                    
                }
                
            }
            
        }catch{
            
            print("** ERROR: binary data couldnt be fetched from core data")
            
        }
        
    }
    
    
    func deleteCoreDataObjects(){
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "UnitFileData")
        
        request.returnsObjectsAsFaults = false
        
        do{
            
            let results = try context.fetch(request)
            
            if results.count > 0 {
                
                print("\(results.count)" + " core data objects")
                
                for result in results as! [NSManagedObject] {
                    
                    context.delete(result)
                    do{
                        try context.save()
                    }catch{
                        
                    }
                    
                    
                }
                
            }else{
                print("NO CORE DATA ITEM")
            }
            
        }catch{
            
            print("** ERROR: binary data couldnt be fetched from core data")
            
        }
        
    }
    
    
    func checkConnection(completion: @escaping () -> ()){
        
        let reachability = Reachability()!
        
        reachability.whenReachable = { reachability in
            
            print("Internet reachable")
            
            completion()
        }
        
        reachability.whenUnreachable = { _ in
            print("Internet unreachable")
        }
        
        do{
            try reachability.startNotifier()
        } catch {
            print("Could not start notifier")
        }
        
    }
    
    
    
}










