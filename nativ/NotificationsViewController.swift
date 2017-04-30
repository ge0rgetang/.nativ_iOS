//
//  NotificationsViewController.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseAnalytics
import FirebaseDatabase
import CryptoSwift
import SDWebImage
import SideMenu

class NotificationsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    // MARK: - Outlets/Variables
    
    var myID: Int = 0
    var myIDFIR: String = "0000000000000000000000000000"
    var firstLoad: Bool = true
    var scrollPosition: String = "top"
    var newUpdatesCount: Int = 0
    var isRemoved: Bool = false
    
    var postIDToPass: Int = -2
    var isAnonToPass: Bool = false
    var userIDToPass: Int = -2
    var userIDFIRToPass: String = "-2"
    var chatIDToPass: String = "-2"
    var parentRow: Int = -2
    var userHandleToPass: String = "chat"
    var picURLToPass: URL!
    
    var notificationIDArray: [Int] = []
    var heightAtIndexPath: [IndexPath:CGFloat] = [:]
    var myNotifications: [[String:Any]] = []
    
    let misc = Misc()
    var activityView = UIView()
    var activityIndicator = UIActivityIndicatorView()
    var activityLabel = UILabel()
    var scrollToTopButton = UIButton()
    
    var ref = FIRDatabase.database().reference()
    
    @IBOutlet weak var sideMenuBarButton: UIBarButtonItem!
    @IBAction func sideMenuBarButtonTapped(_ sender: Any) {
        self.present(SideMenuManager.menuLeftNavigationController!, animated: true, completion: nil)
    }
    
    @IBOutlet weak var notificationsTableView: UITableView!
    
    @IBAction func unwindToNotifications(_ segue: UIStoryboardSegue){}
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = "Notifications"
        
        self.notificationsTableView.delegate = self
        self.notificationsTableView.dataSource = self
        self.notificationsTableView.rowHeight = UITableViewAutomaticDimension
        self.notificationsTableView.separatorStyle = UITableViewCellSeparatorStyle.none
        self.notificationsTableView.backgroundColor = misc.softGrayColor
        self.notificationsTableView.showsVerticalScrollIndicator = false
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(self.handleRefreshControl), for: .valueChanged)
        self.notificationsTableView.addSubview(refreshControl)
        
        self.setSideMenu()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.setNotifications()
        misc.setSideMenuIndex(3)

        let myInfo = misc.setMyID()
        self.myID = myInfo[1] as! Int
        self.myIDFIR = myInfo[2] as! String
        
        if self.myID <= 0 || self.myIDFIR == "0000000000000000000000000000" {
            self.myNotifications = []
            self.notificationIDArray = []
            self.heightAtIndexPath = [:]
            NotificationCenter.default.post(name: Notification.Name(rawValue: "signedOut"), object: nil)
        } else {
            self.logViewNotifications()
            self.firstLoad = true
            self.observeNotifications()
            self.writeInNotifications(true)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.resetBadge()
        self.notificationsTableView.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.removeNotifications()
        if self.myID > 0 {
            self.writeInNotifications(false)
        }
        self.removeObserverForNotifications()
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }
    
    deinit {
        self.removeObserverForNotifications()
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        self.myNotifications = []
        self.notificationIDArray = []
        self.heightAtIndexPath = [:]
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        self.firstLoad = true
        misc.clearWebImageCache()
        self.myNotifications = []
        self.notificationIDArray = []
        self.heightAtIndexPath = [:]
        self.observeNotifications()
    }
    
    // MARK: - TableView
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.myNotifications.isEmpty || self.myID <= 0 || self.myIDFIR == "0000000000000000000000000000" {
            return 1
        }
        
        return self.myNotifications.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if self.myNotifications.isEmpty || self.myID <= 0 || self.myIDFIR == "0000000000000000000000000000" {
            let cell = tableView.dequeueReusableCell(withIdentifier: "noNotificationsCell", for: indexPath) as! NoContentTableViewCell
            cell.noContentLabel.numberOfLines = 0
            cell.noContentLabel.textColor = .lightGray
            cell.whiteView.backgroundColor = UIColor.white
            cell.whiteView.layer.masksToBounds = false
            cell.whiteView.layer.cornerRadius = 2.5
            cell.whiteView.layer.shadowOffset = CGSize(width: -1, height: 1)
            cell.whiteView.layer.shadowOpacity = 0.42
            cell.whiteView.sizeToFit()
            cell.noContentLabel.textColor = .gray
            if self.myID <= 0 || self.myIDFIR == "0000000000000000000000000000"{
                cell.noContentLabel.text = "These are your notifications. Please sign up/login in the sign up section to view them!"
            } else if self.firstLoad {
                cell.noContentLabel.text = "loading notifications..."
            } else {
                cell.noContentLabel.text = "You do not have any notifications."
            }
            
            return cell
            
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "notificationCell", for: indexPath) as! NotificationTableViewCell
        cell.notificationLabel.numberOfLines = 0
        cell.whiteView.backgroundColor = UIColor.white
        cell.whiteView.layer.masksToBounds = false
        cell.whiteView.layer.cornerRadius = 2.5
        cell.whiteView.layer.shadowOffset = CGSize(width: -1, height: 1)
        cell.whiteView.layer.shadowOpacity = 0.42
        cell.whiteView.sizeToFit()
        
        let individualNotification = self.myNotifications[indexPath.row]
        let type = individualNotification["type"] as! String
        let seen = individualNotification["seen"] as! String
        let content = individualNotification["notification"] as! String
        if type == "global" {
            cell.notificationLabel.textColor = misc.nativColor
            cell.notificationLabel.text = content
        } else if seen == "Y" {
            cell.notificationLabel.textColor = .lightGray
            cell.notificationLabel.text = content
        } else {
            cell.notificationLabel.textColor = .black
            let attributedString = misc.stringWithColoredTags(content, time: "default", fontSize: 18, timeSize: 18)
            cell.notificationLabel.attributedText = attributedString
        }
        cell.timestampLabel.text = individualNotification["timestamp"] as? String
        
        let notificationID = individualNotification["notificationID"] as! Int
        if !self.notificationIDArray.contains(notificationID) {
            cell.alpha = 0
            UIView.animate(withDuration: 0.25, animations: {
                cell.alpha = 1
            })
            self.notificationIDArray.append(notificationID)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (self.myID <= 0 || self.myIDFIR == "0000000000000000000000000000") && indexPath.row == 0 {
            self.tabBarController?.selectedIndex = 3
        }
        
        if !self.myNotifications.isEmpty && self.myID > 0 {
            let individualNotification = self.myNotifications[indexPath.row]
            let type = individualNotification["type"] as! String
            let cell = self.notificationsTableView.cellForRow(at: indexPath) as! NotificationTableViewCell
            self.parentRow = indexPath.row
            
            if type != "global" {
                cell.whiteView.backgroundColor = misc.nativFade
            }
            
            switch type {
            case "pond", "anon":
                self.postIDToPass = individualNotification["postID"] as! Int
                if type == "pond" {
                    self.isAnonToPass = false
                } else {
                    self.isAnonToPass = true 
                }
                if let url = individualNotification["imageURL"] as? URL {
                    SDWebImagePrefetcher.shared().prefetchURLs([url])
                }
                self.performSegue(withIdentifier: "fromNotificationsToDrop", sender: self)
                
            case "friendRequest", "accepted":
                if type == "friendRequest" {
                    UserDefaults.standard.set("addedMe", forKey: "friendList.nativ")
                    UserDefaults.standard.synchronize()
                } else {
                    UserDefaults.standard.set("friends", forKey: "friendList.nativ")
                    UserDefaults.standard.synchronize()
                }
                NotificationCenter.default.post(name: Notification.Name(rawValue: "turnToFriendList"), object: nil)
                
            case "chat":
                let userID = individualNotification["userID"] as! Int
                self.userIDToPass = userID
                self.userIDFIRToPass = individualNotification["userIDFIR"] as! String
                let userHandle = individualNotification["userHandle"] as! String
                self.userHandleToPass = "@\(userHandle)"
                self.picURLToPass = individualNotification["picURL"] as! URL
                if self.myID < userID {
                    self.chatIDToPass = "\(self.myID)_\(userID)"
                } else {
                    self.chatIDToPass = "\(userID)_\(self.myID)"
                }
                self.performSegue(withIdentifier: "fromNotificationsToChat", sender: self)
                
            default:
                return
            }
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let height = cell.frame.size.height
        self.heightAtIndexPath.updateValue(height, forKey: indexPath)
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if !self.firstLoad {
            if let height = self.heightAtIndexPath[indexPath] {
                return height
            } else {
                return UITableViewAutomaticDimension
            }
        }
        
        return UITableViewAutomaticDimension
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "fromNotificationsToDrop" {
            if let dropViewController = segue.destination as? DropViewController {
                dropViewController.postID = self.postIDToPass
                dropViewController.isAnon = self.isAnonToPass
                dropViewController.segueSender = "notification"
            }
        }
        
        if segue.identifier == "fromNotificationsToChat" {
            if let chatViewController = segue.destination as? ChatViewController {
                chatViewController.userID = self.userIDToPass
                chatViewController.userIDFIR = self.userIDFIRToPass
                chatViewController.chatID = self.chatIDToPass
                chatViewController.segueSender = "notification"
                chatViewController.userHandle = self.userHandleToPass
                chatViewController.picURL = self.picURLToPass
            }
        }
    }
    
    func setSideMenu() {
        if let sideMenuNavigationController = storyboard?.instantiateViewController(withIdentifier: "SideMenuNavigationController") as? UISideMenuNavigationController {
            sideMenuNavigationController.leftSide = true
            SideMenuManager.menuLeftNavigationController = sideMenuNavigationController
            SideMenuManager.menuRightNavigationController = nil
            SideMenuManager.menuPresentMode = .menuSlideIn
            SideMenuManager.menuAnimationBackgroundColor = misc.nativSideMenu
            SideMenuManager.menuAnimationFadeStrength = 0.35
            SideMenuManager.menuAnimationTransformScaleFactor = 0.95
            SideMenuManager.menuAddPanGestureToPresent(toView: self.navigationController!.navigationBar)
            SideMenuManager.menuAddScreenEdgePanGesturesToPresent(toView: self.navigationController!.view, forMenu: UIRectEdge.left)
        }
    }
    
    func resetBadge() {
        UserDefaults.standard.removeObject(forKey: "badgeNumber.nativ")
        UserDefaults.standard.removeObject(forKey: "badgeNumberDrop.nativ")
        UserDefaults.standard.removeObject(forKey: "badgeNumberNotifications.nativ")
        UserDefaults.standard.removeObject(forKey: "badgeNumberFriendList.nativ")
        UserDefaults.standard.synchronize()
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    // MARK: - ScrollView
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !self.isRemoved {
            self.removeObserverForNotifications()
            self.isRemoved = true
        }
        
        let offset = scrollView.contentOffset.y
        let frameHeight = scrollView.frame.size.height
        let contentHeight = scrollView.contentSize.height
        
        if offset <= 420 {
            self.scrollToTopButton.removeFromSuperview()
        }
        
        if offset <= 0 {
            self.scrollPosition = "top"
            self.observeNotifications()
        } else if (offset == (contentHeight - frameHeight)) {
            self.scrollPosition = "bottom"
            if self.myNotifications.count >= 88 {
                self.getNotifications()
            }
        } else {
            self.scrollPosition = "middle"
        }
    }
    
    // MARK: - Notifications
    
    func setNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshWithDelay), name: NSNotification.Name(rawValue: "addFirebaseObservers"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.scrollToTop), name: NSNotification.Name(rawValue: "scrollToTop"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.removeObserverForNotifications), name: NSNotification.Name(rawValue: "removeFirebaseObservers"), object: nil)
    }
    
    func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "addFirebaseObservers"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "scrollToTop"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "removeFirebaseObservers"), object: nil)
    }
    
    // MARK: - Misc
    
    func displayAlert(_ alertTitle: String, alertMessage: String) {
        let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alertController.addAction(okAction)
        alertController.view.tintColor = misc.nativColor
        DispatchQueue.main.async(execute: {
            self.activityView.removeFromSuperview()
            self.scrollToTopButton.removeFromSuperview()
            self.present(alertController, animated: true, completion: nil)
        })
    }
    
    func displayActivity(_ message: String, indicator: Bool) {
        self.activityLabel = UILabel(frame: CGRect(x: 8, y: 0, width: self.view.frame.width - 16, height: 50))
        self.activityLabel.text = message
        self.activityLabel.textAlignment = .center
        self.activityLabel.textColor = .white
        self.activityView = UIView(frame: CGRect(x: 8, y: self.view.frame.height/2 - 77.5, width: self.view.frame.width - 16, height: 50))
        self.activityView.backgroundColor = UIColor(white: 0, alpha: 0.5)
        self.activityView.layer.cornerRadius = 5
        if indicator {
            self.activityIndicator.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
            self.activityView.addSubview(self.activityIndicator)
            self.activityIndicator.activityIndicatorViewStyle = .white
            self.activityIndicator.startAnimating()
        }
        self.activityView.addSubview(self.activityLabel)
        self.view.addSubview(self.activityView)
        
        self.addScrollToTop("top")
    }
    
    func addScrollToTop(_ title: String) {
        self.scrollToTopButton.removeFromSuperview()
        self.scrollToTopButton = UIButton(frame: CGRect(x: self.view.frame.midX - 27.5, y: self.notificationsTableView.frame.origin.y + 8, width: 65, height: 30))
        self.scrollToTopButton.layer.backgroundColor = UIColor(white: 0, alpha: 0.025).cgColor
        self.scrollToTopButton.addTarget(self, action: #selector(self.scrollToTop), for: .touchUpInside)
        self.scrollToTopButton.addTarget(self, action: #selector(colorTopButtonUp), for: .touchUpInside)
        self.scrollToTopButton.addTarget(self, action: #selector(self.colorTopButtonDown), for: .touchDown)
        misc.makeTopButtonFancy(self.scrollToTopButton, title: title)
        self.view.addSubview(self.scrollToTopButton)
    }
    
    func scrollToTop() {
        self.notificationsTableView.setContentOffset(.zero, animated: false)
        self.scrollToTopButton.removeFromSuperview()
    }
    
    func colorTopButtonDown() {
        self.scrollToTopButton.backgroundColor = misc.nativSemiFade
    }
    
    func colorTopButtonUp() {
        self.scrollToTopButton.backgroundColor = UIColor(white: 0, alpha: 0.025)
    }
    
    func handleRefreshControl(refreshControl: UIRefreshControl) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            refreshControl.endRefreshing()
        })
    }
    
    // MARK: - Analytics
    
    func logViewNotifications() {
        FIRAnalytics.logEvent(withName: "viewNotifications", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    // MARK: - Firebase
    
    func observeNotifications() {
        self.removeObserverForNotifications()
        
        let notificationsRef = self.ref.child("users").child(self.myIDFIR).child("notifications")
        notificationsRef.observe(.value, with: { (snapshot) -> Void in
            if self.scrollPosition == "top" || self.firstLoad {
                self.getNewUpdates()
            } else {
                self.addScrollToTop("New ↑")
                self.firstLoad = true
            }
        })
    }
    
    func removeObserverForNotifications() {
        let notificationsRef = self.ref.child("users").child(self.myIDFIR).child("notifications")
        notificationsRef.removeAllObservers()
    }
    
    func writeInNotifications(_ bool: Bool) {
        self.ref.child("users").child(self.myIDFIR).child("inNotifications").setValue(bool)
        UserDefaults.standard.set(bool, forKey: "inNotifications.nativ")
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - AWS
    
    func getNewUpdates() {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        
        if !self.firstLoad {
            self.newUpdatesCount += 1
        }
        
        if self.newUpdatesCount == 3 || self.firstLoad {
            self.perform(#selector(self.getNotifications), with: nil, afterDelay: 0.1)
        } else {
            self.perform(#selector(self.getNotifications), with: nil, afterDelay: 0.5)
        }
    }
    
    func getNotifications() {
        self.newUpdatesCount = 0
        var lastNotificationID:Int = 0
        
        if self.scrollPosition == "bottom" && self.myNotifications.count >= 88 {
            let lastNotification = self.myNotifications.last!
            lastNotificationID = lastNotification["notificationID"] as! Int
            self.displayActivity("going back in time...", indicator: true)
        } else {
            lastNotificationID = 0
        }
        
        let token = misc.generateToken(16, firebaseID: self.myIDFIR)
        let iv = token.first!
        let tokenString = token.last!
        let key = token[1]
        
        do {
            let aes = try AES(key: key, iv: iv)
            let cipherText = try aes.encrypt(tokenString.utf8.map({$0}))
            
            let sendURL = URL(string: "https://dotnative.io/getNotifications")
            var sendRequest = URLRequest(url: sendURL!)
            sendRequest.httpMethod = "POST"
            
            let sendString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&lastNotificationID=\(lastNotificationID)"
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
                            self.activityView.removeFromSuperview()
                            
                            if status == "error" {
                                self.displayAlert("Oops", alertMessage: "We've encountered an error and can't load your notifications. Please report the bug by going to the report section in the menu.")
                                return
                            }
                            
                            if status == "success" {
                                self.resetBadge()
                                
                                if let notificationsArray = parseJSON["notifications"] as? [[String:Any]] {
                                    var notifications: [[String:Any]] = []
                                    
                                    for individualNotification in notificationsArray {
                                        let notificationID = individualNotification["notificationID"] as! Int
                                        let content = individualNotification["contents"] as! String
                                        let timestamp = individualNotification["timestamp"] as! String
                                        let timestampFormatted = self.misc.formatTimestamp(timestamp)
                                        let type = individualNotification["notificationType"] as! String
                                        let seen = individualNotification["notificationSeen"] as! String
                                        
                                        var note: [String:Any] = [:]
                                        switch type {
                                        case "pond", "anon":
                                            let postID = individualNotification["postID"] as! Int
                                            note = ["notificationID": notificationID, "notification": content, "timestamp": timestampFormatted, "type": type, "seen": seen, "postID": postID]
                                            
                                        case "chat":
                                            let userID = individualNotification["userID"] as! Int
                                            let userHandle = individualNotification["userHandle"] as! String
                                            let userIDFIR = individualNotification["firebaseID"] as! String
                                            let key = individualNotification["key"] as! String
                                            let bucket = individualNotification["bucket"] as! String
                                            let picURL = URL(string: "https://\(bucket).s3.amazonaws.com/\(key)")!
                                            note = ["notificationID": notificationID, "notification": content, "timestamp": timestampFormatted, "type": type, "seen": seen, "userID": userID,  "userHandle": userHandle, "userIDFIR": userIDFIR, "picURL": picURL]
                                            
                                        default:
                                            note = ["notificationID": notificationID, "notification": content, "timestamp": timestampFormatted, "type": type, "seen": seen]
                                        }
                                        
                                        notifications.append(note)
                                    }
                                    
                                    if lastNotificationID != 0 {
                                        let latestNotification = notifications.last!
                                        if lastNotificationID != latestNotification["notificationID"] as! Int {
                                            self.myNotifications.append(contentsOf: notifications)
                                            if self.myNotifications.count > 210 {
                                                let difference = self.myNotifications.count - 210
                                                let indicesToRemove = 0...(difference-1)
                                                self.myNotifications = self.myNotifications.enumerated().filter{!indicesToRemove.contains($0.offset)}.map{$0.element}
                                            }
                                        }
                                    } else {
                                        self.myNotifications = notifications
                                    }
                                }
                                
                                self.firstLoad = false
                                self.notificationsTableView.reloadData()
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
            self.displayAlert("Token Error", alertMessage: "We messed up. Please report the bug by going to the report section in the menu.")
            return
        }
    }
    
    func refreshWithDelay() {
        if self.scrollPosition == "top" {
            self.perform(#selector(self.observeNotifications), with: nil, afterDelay: 0.1)
        } else {
            self.perform(#selector(self.getNotifications), with: nil, afterDelay: 0.5)
        }
    }
}
