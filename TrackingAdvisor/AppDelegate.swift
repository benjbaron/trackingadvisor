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
        
        // Override point for customization after application launch.
        if launchOptions?[.location] != nil {
            FileService.shared.log("App launched (location-triggered)", classname: "AppDelegate")
        } else if launchOptions?[.remoteNotification] != nil {
            FileService.shared.log("App launched (pushNotification-triggered)", classname: "AppDelegate")
        } else {
            FileService.shared.log("App launched (user-triggered)", classname: "AppDelegate")
        }
        
        // if the app was launched for a notification
        if let notification = launchOptions?[.remoteNotification] as? [String:Any] {
            let aps = notification["aps"] as! [String:Any]
            print(aps)
        }
        
        // check if this is the first app launch
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: Constants.defaultsKeys.onboarding) {
            launchStoryboard(storyboard: "Onboarding")
            return true
        } else {
            launchStoryboard(storyboard: "Main")
        }
        
        // start updating the location services again
        LocationRegionService.shared.startUpdatingLocation()
        
        // retrieve the latest data from the server
        DispatchQueue.global(qos: .background).async {
            // update the personal categories if needed
            PersonalInformationCategory.updateIfNeeded()
            
            // get today's update
            UserUpdateHandler.retrieveLatestUserUpdates(for: DateHandler.dateToDayString(from: Date()))
        }
        
        return true
    }
    
    func launchStoryboard(storyboard: String) {
        UIApplication.shared.isStatusBarHidden = true
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
        
        FileService.shared.log("call -- applicationDidEnterBackground", classname: "AppDelegate")
        LocationRegionService.shared.restartUpdatingLocation()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        FileService.shared.log("call -- applicationWillEnterForeground", classname: "AppDelegate")
        LocationRegionService.shared.restartUpdatingLocation()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        self.saveContext()
        FileService.shared.log("call -- applicationWillTerminate", classname: "AppDelegate")
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
            print("Permission granted: \(granted)")
            
            guard granted else { return }
            self.getNotificationSettings()
        }
    }
    
    func getNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            print("Notification settings: \(settings)")
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
        let defaults = UserDefaults.standard
        defaults.set(token, forKey: Constants.defaultsKeys.pushNotificationToken)
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register: \(error)")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        FileService.shared.log("call -- didReceiveRemoteNotification", classname: "AppDelegate")
        LocationRegionService.shared.restartUpdatingLocation()
    }
}

