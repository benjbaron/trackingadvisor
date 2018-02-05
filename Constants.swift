//
//  constants.swift
//  TrackingAdvisor
//
//  Created by Benjamin BARON on 11/15/17.
//  Copyright © 2017 Benjamin BARON. All rights reserved.
//

import Foundation

struct Constants {
    
    struct defaultsKeys {
        static let lastLocationUpdate = "lastLocationUpdate"
        static let lastFileUpdate = "lastFileUpdate"
        static let lastUserUpdate = "lastUserUpdate"
        static let lastPersonalInformationCategoryUpdate = "lastPersonalInformationCategoryUpdate"
        static let pushNotificationToken = "pushNotificationToken"
        static let userid = "userid"
    }
    
    struct variables {
        static let minimumDurationBetweenLocationFileUploads: TimeInterval = 3600 // one hour
        static let minimumDurationBetweenUserUpdates: TimeInterval = 600 // 10 minutes
        static let minimumDurationBetweenPersonalInformationCategoryUpdates: TimeInterval = 62400 // one day
    }
    
    struct colors {
        static let defaultColor = UIColor.init(red: 0.75, green: 0.75, blue: 0.75, alpha: 1.0);
        static let primaryDark = UIColor.init(red: 48.0/255.0, green: 63.0/255.0, blue: 159.0/255.0, alpha: 1)
        static let primaryLight = UIColor.init(red: 167.0/255.0, green: 175.0/255.0, blue: 217.0/255.0, alpha: 1.0)
        static let descriptionColor = UIColor.gray
        static let titleColor = UIColor.white
        static let black = UIColor.black
        static let white = UIColor.white
        static let green = UIColor.init(red: 76/255, green: 175/255, blue: 80/255, alpha: 1)
        static let noColor = UIColor.clear
        static let superLightGray = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        static let lightGray = UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0)
        static let darkRed = UIColor(red: 0.698, green: 0.1529, blue: 0.1529, alpha: 1.0)
        static let orange = UIColor(red: 247/255, green: 148/255, blue: 29/255, alpha: 1.0)
        static let lightOrange = UIColor(red: 244/255, green: 197/255, blue: 146/255, alpha: 1.0)
    }
    
    struct filenames {
        static let locationFile = "locations.csv"
    }
    
    struct urls {
        static let locationUploadURL = "https://iss-lab.geog.ucl.ac.uk/semantica/uploader"
        static let sendMailURL = "https://iss-lab.geog.ucl.ac.uk/semantica/mail"
        static let userUpdateURL = "https://iss-lab.geog.ucl.ac.uk/semantica/userupdate"
        static let placeAutcompleteURL = "https://iss-lab.geog.ucl.ac.uk/semantica/autocomplete"
        static let personalInformationCategoriesURL = "https://iss-lab.geog.ucl.ac.uk/semantica/personalinformationcategories"
        static let userChallengeURL = "https://iss-lab.geog.ucl.ac.uk/semantica/userchallenge"
    }
    
}
