//
//  SettingsTableTableViewController.swift
//  TrackingAdvisor
//
//  Created by Benjamin BARON on 11/27/17.
//  Copyright © 2017 Benjamin BARON. All rights reserved.
//

import UIKit
import Alamofire

class SettingsTableTableViewController: UITableViewController {

    @IBOutlet weak var versionNumber: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.delegate = self
        
        self.versionNumber.text = "\(Bundle.main.appName) v \(Bundle.main.versionNumber) (Build \(Bundle.main.buildNumber))"
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    /*
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 0
    }
    */
    
    /*
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 0
    }
    */

    /*
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)

        // Configure the cell...

        return cell
    }
    */

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) {
            let id = cell.reuseIdentifier
            
            if id == "deleteAll" {
                let alertController = UIAlertController(title: "Delete all", message: "This will delete all the data stored locally on your phone. It will not delete the data we collected about you from our servers.", preferredStyle: UIAlertControllerStyle.alert)
                
                let deleteAllAction = UIAlertAction(title: "Delete all",
                                                    style: UIAlertActionStyle.destructive) {
                    (result : UIAlertAction) -> Void in
                    print("Delete all -- proceed")
                    DataStoreService.shared.deleteAll()
                }
                
                let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel) {
                    (result : UIAlertAction) -> Void in
                    print("Cancel delete all")
                }
                
                alertController.addAction(deleteAllAction)
                alertController.addAction(cancelAction)
                self.present(alertController, animated: true, completion: nil)
                tableView.deselectRow(at: indexPath, animated: true)
            } else if id == "onboarding" {
                print("Show onboarding screen")
                
                // Load the onboarding view and the navigation controller
                let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
                 let initialViewController = storyboard.instantiateViewController(withIdentifier: "InitialOnboarding")

                initialViewController.modalTransitionStyle = .crossDissolve
                initialViewController.modalPresentationStyle = .fullScreen
                present(initialViewController, animated: true, completion: nil)
            } else if id == "optout" {
                print("Opt-out of the study")
                let alertController = UIAlertController(title: "Opt-out", message: "You will not be able to use this app and all the data we collected about you will be deleted from our servers.", preferredStyle: UIAlertControllerStyle.alert)
                
                let deleteAllAction = UIAlertAction(title: "Opt-out",
                                                    style: UIAlertActionStyle.destructive) {
                                                        (result : UIAlertAction) -> Void in
                                                        print("opt-out -- proceed")
                    UserUpdateHandler.optOut(callback: {
                        Settings.saveOptOut(with: true)
                        let appDelegate = UIApplication.shared.delegate as! AppDelegate
                        appDelegate.launchStoryboard(storyboard: "OptOut")
                    })
                }
                
                let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel) {
                    (result : UIAlertAction) -> Void in
                    print("Cancel opt-out")
                }
                
                alertController.addAction(deleteAllAction)
                alertController.addAction(cancelAction)
                self.present(alertController, animated: true, completion: nil)
                tableView.deselectRow(at: indexPath, animated: true)
            }
        }
    }
}

struct TermsStruct : Codable {
    let type: String
    let text: String
}

fileprivate func getTextFromServer(url: String?, for text: UITextView?) {
    guard let url = url, let text = text else { return }
    Alamofire.request(url, method: .get, parameters: nil)
        .responseJSON { response in
            if response.result.isSuccess {
                guard let data = response.data else { return }
                do {
                    let decoder = JSONDecoder()
                    let terms = try decoder.decode([TermsStruct].self, from: data)
                    formatText(terms, for: text)
                    
                } catch {
                    print("Error serializing the json", error)
                }
            }
    }
}

fileprivate func formatText(_ terms: [TermsStruct], for text: UITextView?) {
    guard let text = text else { return }
    
    let paraStyle = NSMutableParagraphStyle()
    paraStyle.firstLineHeadIndent = 15.0
    paraStyle.paragraphSpacingBefore = 10.0
    
    let textFont = [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 14.0)]
    let titleFont = [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 25.0, weight: .black)]
    
    let textBlock = NSMutableAttributedString()
    
    for line in terms {
        if line.type == "S" {
            textBlock.append(NSAttributedString(string: "\n" + line.text + "\n\n", attributes: titleFont))
        } else if line.type == "P" {
            textBlock.append(NSAttributedString(string: line.text + "\n", attributes: textFont))
        }
    }
    
    text.attributedText = textBlock
}


class SettingsPrivacyPolicyViewController: UIViewController {
    @IBOutlet weak var text: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        getTextFromServer(url: Constants.urls.privacyPolicyURL, for: text)
    }
    
}

class SettingsStudyTermsViewController: UIViewController {
    @IBOutlet weak var text: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        getTextFromServer(url: Constants.urls.termsURL, for: text)
    }
}