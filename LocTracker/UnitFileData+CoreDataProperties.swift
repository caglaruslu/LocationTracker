//
//  UnitFileData+CoreDataProperties.swift
//  LocTracker
//
//  Created by Çağlar Uslu on 28.09.2018.
//  Copyright © 2018 Çağlar Uslu. All rights reserved.
//
//

import Foundation
import CoreData


extension UnitFileData {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UnitFileData> {
        return NSFetchRequest<UnitFileData>(entityName: "UnitFileData")
    }

    @NSManaged public var binData: NSData?
    @NSManaged public var synched: Bool

}
