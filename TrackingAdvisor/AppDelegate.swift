//
//  AppDelegate.swift
//  TrackingAdvisor
//
//  Created by Benjamin BARON on 10/25/17.
//  Copyright © 2017 Benjamin BARON. All rights reserved.
//

import UIKit
import CoreData
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        Settings.registerDefaults()
        registerNotificationCustomActions()
        
        Settings.incrementCurrentSessionId()
        Settings.saveCurrentAppState(with: "active")
        
        // Override point for customization after application launch.
        if launchOptions?[.location] != nil {
            LogService.shared.log(LogService.types.appLaunchType,
                                  args: [LogService.args.launchType: "location"])
        } else if launchOptions?[.remoteNotification] != nil {
            LogService.shared.log(LogService.types.appLaunchType,
                                  args: [LogService.args.launchType: "pushNotification"])
        } else {
            LogService.shared.log(LogService.types.appLaunchType,
                                  args: [LogService.args.launchType: "user"])
        }
        
        // if the app was launched for a notification
        if let notification = launchOptions?[.remoteNotification] as? [String:Any] {
            handleRemoteNotifications(with: notification)
        }
        
        let locationStatus = LocationRegionService.getLocationServiceStatus()
        if locationStatus == .denied || locationStatus == .restricted {
            launchStoryboard(storyboard: "LocationServicesDenied")
            return true
        } else if locationStatus == .authorizedWhenInUse {
            launchStoryboard(storyboard: "LocationServicesWhenInUse")
            
        } else {
        
            // check if this is the first app launch
            if !Settings.getOnboarding() {
                launchStoryboard(storyboard: "Onboarding")
                return true
            } else if Settings.getOptOut() {
                launchStoryboard(storyboard: "OptOut")
                return true
            } else {
                launchStoryboard(storyboard: "Main")
            }
        }
        
        handleLaunchingOperations(application)
        
        return true
    }
    
    func launchStoryboard(storyboard: String) {
        UIApplication.shared.isStatusBarHidden = true
        
        LogService.shared.log(LogService.types.appStoryboard,
                              args: [LogService.args.storyboard: storyboard])
        
        let storyboard = UIStoryboard(name: storyboard, bundle: nil)
        let controller = storyboard.instantiateInitialViewController()
        self.window?.rootViewController = controller
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        
        LogService.shared.log(LogService.types.appBackground)
        LocationRegionService.shared.restartUpdatingLocation()
        Settings.saveCurrentAppState(with: "background")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        LogService.shared.log(LogService.types.appForeground)
        
        let locationStatus = LocationRegionService.getLocationServiceStatus()
        if locationStatus == .denied || locationStatus == .restricted {
            launchStoryboard(storyboard: "LocationServicesDenied")
            return
        }
        
        // check if this is the first app launch
        if !Settings.getOnboarding() {
            launchStoryboard(storyboard: "Onboarding")
            return
        } else if Settings.getOptOut() {
            launchStoryboard(storyboard: "OptOut")
            return
        } else {
            launchStoryboard(storyboard: "Main")
        }
        
        LocationRegionService.shared.restartUpdatingLocation()
        handleLaunchingOperations(application)
        Settings.saveCurrentAppState(with: "foreground")
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        self.saveContext()
        Settings.saveCurrentAppState(with: "inactive")
        LogService.shared.log(LogService.types.appTerminate)
        
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "TrackingAdvisor")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    // MARK: - Push notification registration
    func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge]) {
            (granted, error) in
            
            guard granted else { return }
            
            let viewAction = UNNotificationAction(identifier: "VIEW",
                                                  title: "View",
                                                  options: [.foreground])
            
            let category = UNNotificationCategory(identifier: "REVIEW_CHALLENGE",
                                                      actions: [viewAction],
                                                      intentIdentifiers: [],
                                                      options: [])
            
            UNUserNotificationCenter.current().setNotificationCategories([category])
            self.getNotificationSettings()
        }
    }
    
    func registerNotificationCustomActions() {
        let generalCategory = UNNotificationCategory(identifier: "GENERAL",
                                                     actions: [],
                                                     intentIdentifiers: [],
                                                     options: .customDismissAction)
        
        // Create the custom actions for the PLACE_CHECKIN category.
        let checkinYesAction = UNNotificationAction(identifier: "CHECKIN_YES_ACTION",
                                                title: "Yes!",
                                                options: UNNotificationActionOptions(rawValue: 0))
        let checkinNotAPlaceAction = UNNotificationAction(identifier: "CHECKIN_NOT_A_PLACE_ACTION",
                                              title: "Not at a place",
                                              options: UNNotificationActionOptions(rawValue: 0))
        let checkinOtherPlaceAction = UNNotificationAction(identifier: "CHECKIN_OTHER_PLACE_ACTION",
                                                          title: "Pick another place",
                                                          options: UNNotificationActionOptions(rawValue: 0))
        
        let expiredCategory = UNNotificationCategory(identifier: "PLACE_CHECKIN",
                                                     actions: [checkinYesAction, checkinNotAPlaceAction, checkinOtherPlaceAction],
                                                     intentIdentifiers: [],
                                                     options: UNNotificationCategoryOptions(rawValue: 0))
        
        // Register the notification categories.
        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([generalCategory, expiredCategory])
    }
    
    func getNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            guard settings.authorizationStatus == .authorized else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data -> String in
            return String(format: "%02.2hhx", data)
        }
        
        let token = tokenParts.joined()
        Settings.savePushNotificationId(with: token)
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register: \(error)")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        handleRemoteNotifications(with: userInfo)
        LocationRegionService.shared.restartUpdatingLocation()
        
        LogService.shared.log(LogService.types.notificationReceived)
    }
    
    private func handleRemoteNotifications(with userInfo: [AnyHashable : Any]) {
        // retrieve the latest data from the server
        DispatchQueue.global(qos: .background).async { [weak self] in
            if let aps = userInfo["aps"] as? [String: AnyObject] {
                if aps["content-available"] as? Int == 1 {
                    // update the personal categories if needed
                    PersonalInformationCategory.updateIfNeeded()
                    
                    // get today's update
                    UserUpdateHandler.retrieveLatestUserUpdates(for: DateHandler.dateToDayString(from: Date()))
                    
                    // get latest aggregated personal information
                    UserUpdateHandler.retrieveLatestAggregatedPersonalInformation()
                    
                    LogService.shared.log(LogService.types.notificationReceived,
                                          args: [LogService.args.launchType: "content-available"])
                } else  {
                    // get the notification type
                    print("user notification: \(userInfo)")
                    if let notificationType = userInfo["type"] as? String {
                        if notificationType == "timeline" {
                            if let day = userInfo["day"] as? String {
                                DispatchQueue.main.async { () -> Void in
                                    // show the timeline tab
                                    if let tabController = self?.window?.rootViewController as? UITabBarController {
                                        tabController.selectedIndex = 0
                                        
                                        if let vc = tabController.viewControllers?[0] {
                                            if let timelineVC = vc.childViewControllers[0] as? TimelineSwipeViewController {
                                                
                                                if let index = timelineVC.days.index(of: day) {
                                                    if let newCurrentViewController = timelineVC.viewController(at: index) {
                                                    timelineVC.pageViewController?.selectViewController(newCurrentViewController, direction: .forward, animated: false, completion: nil)
                                                    }
                                                }
                                                
                                            }
                                        } else {
                                            print("Could not get the first controller")
                                        }
                                        
                                        // get today's  udpate
                                        UserUpdateHandler.retrieveLatestUserUpdates(for: day)
                                        
                                        LogService.shared.log(LogService.types.notificationOpen,
                                                              args: [LogService.args.launchType: "timeline"])
                                    }
                                }
                            }
                        } else if notificationType == "review" {
                            DispatchQueue.main.async { () -> Void in
                                // get latest aggregated personal information
                                UserUpdateHandler.retrieveLatestAggregatedPersonalInformation() {
                                    // show the review tab
                                    if let tabController = self?.window?.rootViewController as? UITabBarController {
                                        tabController.selectedIndex = 1
                                        
                                        LogService.shared.log(LogService.types.notificationOpen,
                                                              args: [LogService.args.launchType: "review"])
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func handleLaunchingOperations(_ application: UIApplication) {
        // force the location upload after one location has been collected
        Settings.saveForceUploadLocation(with: true)
        
        // start updating the location services again
        LocationRegionService.shared.startUpdatingLocation()
        
        // update the dates from the database
        DataStoreService.shared.updateIfNeeded()
        
        // update tab badges
        updateTabBadges()
        
        // retrieve the latest data from the server
        DispatchQueue.global(qos: .background).async {
            
            // update the personal categories if needed
            PersonalInformationCategory.updateIfNeeded()
            
            UserUpdateHandler.retrieveLatestAggregatedPersonalInformation()
            
            // get today's update
            UserUpdateHandler.retrieveLatestUserUpdates(for: DateHandler.dateToDayString(from: Date()))
            
        }
    }
    
    func updateTabBadges(type: String? = nil) {
        if let tabController = self.window?.rootViewController as? UITabBarController {
            
            if type == nil || type == "visits" {
                // get the number of visits to confirm
                let today = DateHandler.dateToDayString(from: Date())
                let numberOfVisitsToConfirm = DataStoreService.shared.getVisits(for: today, sameContext: true).filter({ $0.visited == 0 }).count
                                
                if numberOfVisitsToConfirm == 0 {
                    tabController.tabBar.items?[0].badgeValue = nil
                } else {
                    tabController.tabBar.items?[0].badgeValue = String(numberOfVisitsToConfirm)
                }
            }
            
            if type == nil || type == "reviews" {
                // get the number of places to review
                let numberOfPlacesToReview = DataStoreService.shared.getAllPlacesToReview(sameContext: true).count
                
                // get the number of personal information to review
                let numberOfAggregatePersonalInformationToReview = DataStoreService.shared.getAggregatedPersonalInformationToReview(sameContext: true).count
                
                let sum = numberOfPlacesToReview + numberOfAggregatePersonalInformationToReview
                if sum == 0 {
                    tabController.tabBar.items?[1].badgeValue = nil
                } else {
                    tabController.tabBar.items?[1].badgeValue = String(sum)
                }
            }
            
        }
    }
}

