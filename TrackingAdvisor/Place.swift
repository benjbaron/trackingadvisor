//
//  Place.swift
//  TrackingAdvisor
//
//  Created by Benjamin BARON on 11/23/17.
//  Copyright © 2017 Benjamin BARON. All rights reserved.
//

import Foundation
import CoreData

@objc(Place)
class Place: NSManagedObject {
    
    class func findPlace(matching userPlaceId: String, in context: NSManagedObjectContext) throws -> Place? {
        let request: NSFetchRequest<Place> = Place.fetchRequest()
        request.predicate = NSPredicate(format: "id = %@", userPlaceId)
        
        do {
            let matches = try context.fetch(request)
            if matches.count > 0 {
                assert(matches.count == 1, "Place.findPlace -- database inconsistency")
                return matches[0]
            }
        } catch {
            throw error
        }
        
        return nil
    }
    
    class func create(userPlace: UserPlace, in context: NSManagedObjectContext) throws -> Void {
        let place = Place(context: context)
        place.id = userPlace.pid
        place.address = userPlace.a
        place.type = userPlace.t
        place.city = userPlace.c
        place.latitude = userPlace.lat
        place.longitude = userPlace.lon
        place.name = userPlace.name
        place.color = userPlace.col
    }
    
    class func findOrCreatePlace(matching userPlace: UserPlace, in context: NSManagedObjectContext) throws -> Place {
        let request: NSFetchRequest<Place> = Place.fetchRequest()
        request.predicate = NSPredicate(format: "id = %@", userPlace.pid)
        
        do {
            let matches = try context.fetch(request)
            if matches.count > 0 {
                assert(matches.count == 1, "Place.findOrCreatePlace -- database inconsistency")
                
                // update the place with the new value
                let managedObject = matches[0]
                
                print("update place \(userPlace.pid)")
                
                managedObject.setValue(userPlace.a, forKey: "address")
                managedObject.setValue(userPlace.t, forKey: "type")
                managedObject.setValue(userPlace.c, forKey: "city")
                managedObject.setValue(userPlace.lat, forKey: "latitude")
                managedObject.setValue(userPlace.lon, forKey: "longitude")
                managedObject.setValue(userPlace.name, forKey: "name")
                managedObject.setValue(userPlace.col, forKey: "color")
                return managedObject
            }
        } catch {
            throw error
        }
        
        let place = Place(context: context)
        place.address = userPlace.a
        place.type = userPlace.t
        place.city = userPlace.c
        place.id = userPlace.pid
        place.latitude = userPlace.lat
        place.longitude = userPlace.lon
        place.name = userPlace.name
        place.color = userPlace.col
        
        return place
    }
    
    func formatAddressString() -> String {
        let addressString = address ?? ""
        let cityString = city ?? ""
        let sep = addressString != "" && cityString != "" ? ", " : ""
        return addressString + sep + cityString
    }
    
    func getPersonalInformation() -> [String: [PersonalInformation]] {
        var categories: [String: [PersonalInformation]] = [:]
        guard let personalInformation = personalInformation else { return categories }
        for case let pi as PersonalInformation in personalInformation {
            guard let picid = pi.category else { continue }
            if categories[picid] == nil {
                categories[picid] = []
            }
            categories[picid]!.append(pi)
        }
        
        return categories
    }
    
    func getPersonalInformationPhrase() -> String {
        let personalInformation = getPersonalInformation()
        var res = ""
        var count = 0
        for (cat, pi) in personalInformation {
            res += "\(cat)"
            if pi.count > 0 {
                res += ": \(pi.map { $0.name! }.joined(separator: ", "))"
            }
            count += 1
            if count < personalInformation.count {
                res += ", "
            }
        }
        return res
    }
    
    func getPlaceColor() -> UIColor {
        if let color = color {
            return UIColor(hex: color)!
        }
        return Constants.colors.orange
    }

}
