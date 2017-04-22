//
//  ReportPopViewController.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseAnalytics
import FirebaseDatabase
import CryptoSwift

class ReportPopViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    // MARK: - Outlets/Variables
    
    var myID: Int = UserDefaults.standard.integer(forKey: "myID.nativ")
    var myIDFIR: String = UserDefaults.standard.string(forKey: "myIDFIR.nativ")!
    var postID: Int = -2
    var postType: String = "pond"
    
    var reportHeightArray: [CGFloat] = []
    var reportOptions: [String] = []
    
    var ref = FIRDatabase.database().reference()
    
    let misc = Misc()
    
    @IBOutlet weak var reportTableView: UITableView!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.preferredContentSize = CGSize(width: 200, height: 150)
        
        self.reportTableView.delegate = self
        self.reportTableView.dataSource = self
        self.reportTableView.estimatedRowHeight = 50
        self.reportTableView.rowHeight = UITableViewAutomaticDimension
        self.reportTableView.layoutMargins = UIEdgeInsets.zero
        self.reportTableView.separatorInset = UIEdgeInsets.zero
        
        self.reportOptions = ["This post is offensive/abusive/illegal", "This post is spam", "Other"]
    }
    
    override func viewWillAppear(_ animated: Bool) {
        let myInfo = misc.setMyID()
        self.myID = myInfo[1] as! Int
        self.myIDFIR = myInfo[2] as! String
        switch self.postType {
        case "pond":
            self.logViewPondReport()
        case "anon":
            self.logViewAnonymousPondReport()
        default:
            return
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.reportHeightArray.remove(at: self.reportHeightArray.count - 1)
        let preferredHeight = self.reportHeightArray.reduce(0,+)
        self.preferredContentSize = CGSize(width: 200, height: preferredHeight)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - TableView
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.reportOptions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reportCell", for: indexPath) as! ReportTableViewCell
        cell.reportOptionLabel.numberOfLines = 0
        cell.reportOptionLabel.sizeToFit()
        cell.layoutMargins = UIEdgeInsets.zero
        cell.reportOptionLabel.text = self.reportOptions[(indexPath as NSIndexPath).row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let height = cell.frame.size.height
        self.reportHeightArray.insert(height, at: indexPath.row)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.row {
        case 0:
            self.reportPost("Offensive")
        case 1:
            self.reportPost("Spam")
        case 2:
            self.reportPost("Other")
        default:
            return
        }
    }
    
    // MARK: - Misc
    
    func displayAlert(_ alertTitle: String, alertMessage: String) {
        let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alertController.addAction(okAction)
        alertController.view.tintColor = misc.nativColor
        DispatchQueue.main.async(execute: {
            self.present(alertController, animated: true, completion: nil)
        })
    }
    
    // MARK: - Analytics
    
    func logViewPondReport() {
        FIRAnalytics.logEvent(withName: "viewPondPostReport", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "postID": self.postID as NSObject
            ])
    }
    
    func logViewAnonymousPondReport() {
        FIRAnalytics.logEvent(withName: "viewAnonymousPondPostReport", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "postID": self.postID as NSObject
            ])
    }
    
    func logPondPostReported(_ reportMessage: String) {
        FIRAnalytics.logEvent(withName: "pondPostReported", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "postID": self.postID as NSObject,
            "reportMessage": reportMessage as NSObject
            ])
    }
    
    func logAnonymousPondPostReported(_ reportMessage: String) {
        FIRAnalytics.logEvent(withName: "anonymousPondPostReported", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "postID": self.postID as NSObject,
            "reportMessage": reportMessage as NSObject
            ])
    }
    
    // MARK: - Firebase
    
    func reportPostFIR(_ message: String) {
        self.ref.child("reported").childByAutoId().setValue(["postID": self.postID, "myIDFIR": self.postType, "message": message])
    }
    
    // MARK: - AWS
    
    func reportPost(_ reportMessage: String) {
        let token = misc.generateToken(16, firebaseID: self.myIDFIR)
        let iv = token.first!
        let tokenString = token.last!
        let key = token[1]
        
        do {
            let aes = try AES(key: key, iv: iv)
            let cipherText = try aes.encrypt(tokenString.utf8.map({$0}))
            
            let sendURL = URL(string: "https://dotnative.io/editPost")
            var sendRequest = URLRequest(url: sendURL!)
            sendRequest.httpMethod = "POST"
            
            let action: String = "report"
            
            let sendString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&postID=\(self.postID)&action=\(action)&postType=\(self.postType)&reportReason=\(reportMessage)"
            
            sendRequest.httpBody = sendString.data(using: String.Encoding.utf8)
            
            let task = URLSession.shared.dataTask(with: sendRequest as URLRequest) {
                (data, response, error) in
                
                if error != nil {
                    print(error ?? "error")
                    self.displayAlert("uhh, Houston, we have a problem", alertMessage: "Sorry, could not connect to le internet. :(")
                    return
                }
                
                do{
                    let json = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as? NSDictionary
                    
                    if let parseJSON = json {
                        let status: String = parseJSON["status"] as! String
                        let message = parseJSON["message"] as! String
                        print("status: \(status), message: \(message)")
                        
                        DispatchQueue.main.async(execute: {
                            
                            if status == "error" {
                                self.displayAlert("Oops", alertMessage: "Sorry, we messed up. Your report may not have gone through. Please report the bug in the report section of the menu.")
                                return
                            }
                            
                            if status == "success" {
                                self.reportPostFIR(reportMessage)
                                let alertController = UIAlertController(title: "Thank you", message: "Report complete. We will look into the issue. Unfortunately, not everyone is awesome - don't let it ruin your day!", preferredStyle: .alert)
                                let okAction = UIAlertAction(title: "Ok", style: .default) { action in
                                    switch self.postType {
                                    case "pond":
                                        self.logPondPostReported(reportMessage)
                                        NotificationCenter.default.post(name: Notification.Name(rawValue: "unselectSettingsPond"), object: nil)
                                    case "anon":
                                        self.logAnonymousPondPostReported(reportMessage)
                                        NotificationCenter.default.post(name: Notification.Name(rawValue: "unselectSettingsPond"), object: nil)
                                    default:
                                        return
                                    }
                                    self.dismiss(animated: true, completion: nil)
                                }
                                alertController.addAction(okAction)
                                alertController.view.tintColor = self.misc.nativColor
                                self.present(alertController, animated: true, completion: nil)
                            }
                            
                        })
                    }
                    
                } catch {
                    self.displayAlert("Oops", alertMessage: "We're updating our servers right now. Please try again later.")
                    print(error)
                    return
                }
                
            }
            
            task.resume()
            
        } catch {
            self.displayAlert("Token Error", alertMessage: "We messed up. Please report the bug in the report section of the menu.")
            return
        }
    }
    
}
