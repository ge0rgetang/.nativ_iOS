//
//  AppDelegate.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import AWSCore
import UserNotifications
import Firebase
import FirebaseDatabase
import SDWebImage
import FBSDKCoreKit
import GoogleSignIn
import Fabric
import TwitterKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, GIDSignInDelegate {

    var window: UIWindow?
    let misc = Misc() 

    override init() {
        super.init()
        
        FIRApp.configure()
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        GIDSignIn.sharedInstance().clientID = FIRApp.defaultApp()?.options.clientID
        GIDSignIn.sharedInstance().delegate = self
        
        FBSDKApplicationDelegate.sharedInstance().application(application, didFinishLaunchingWithOptions: launchOptions)
        
        Fabric.with([Twitter.self])
        
        GADMobileAds.configure(withApplicationID: "ca-app-pub-3615009076081464~7627478639")
        
        let credentialsProvider = AWSCognitoCredentialsProvider(
            regionType: AWSRegionType.USEast1,
            identityPoolId: "us-east-1:59ec4caa-c8b8-4bda-896b-9fc95339f18b")
        let configuration = AWSServiceConfiguration(
            region: AWSRegionType.USWest1,
            credentialsProvider:  credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        AWSDDLog.removeAllLoggers()
        
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) {(granted, error) in
        }
        application.registerForRemoteNotifications()
        
        let nativColor = UIColor(red: 70/255.0, green: 140/255.0, blue: 115/255.0, alpha: 1)
        let softGrayColor = UIColor(red: 240/255.0, green: 240/255.0, blue: 240/255.0, alpha: 1)
        
        UINavigationBar.appearance().titleTextAttributes = [NSForegroundColorAttributeName : nativColor]
        UINavigationBar.appearance().tintColor = nativColor
        UINavigationBar.appearance().barTintColor = softGrayColor
        UINavigationBar.appearance().isTranslucent = false
        
        self.window?.tintColor = nativColor
        
        SDWebImageDownloader.shared().maxConcurrentDownloads = 10
        SDWebImagePrefetcher.shared().maxConcurrentDownloads = 10
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        let sourceApplication: String? = options[UIApplicationOpenURLOptionsKey.sourceApplication] as? String
        
        if FBSDKApplicationDelegate.sharedInstance().application(app, open: url, sourceApplication: sourceApplication, annotation: nil) {
            return true
        } else if GIDSignIn.sharedInstance().handle(url, sourceApplication: sourceApplication, annotation: [:]) {
            return true
        } else {
            return false
        }
    }
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        if let error = error {
            print(error)
            return
        }
        
    
        NotificationCenter.default.post(name: Notification.Name(rawValue: "googleSignInSuccessFriendList"), object: nil)
        NotificationCenter.default.post(name: Notification.Name(rawValue: "googleSignInSuccess"), object: nil)
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        self.window?.endEditing(true)
        
        if let chatID = UserDefaults.standard.string(forKey: "currentChatID.nativ") {
            let myID: Int = UserDefaults.standard.integer(forKey: "myID.nativ")
            let inConversationRef = FIRDatabase.database().reference().child("chats").child(chatID).child("\(myID)_inConversation")
            inConversationRef.setValue(false)
        }
        
        if let myIDFIR = UserDefaults.standard.string(forKey: "myIDFIR.nativ") {
            let inFriendListRef = FIRDatabase.database().reference().child("users").child(myIDFIR).child("inFriendList")
            inFriendListRef.setValue(false)
            
            let inNotificationsRef = FIRDatabase.database().reference().child("users").child(myIDFIR).child("inNotifications")
            inNotificationsRef.setValue(false)
            
            let inPostIDRef = FIRDatabase.database().reference().child("users").child(myIDFIR).child("inPostID")
            inPostIDRef.setValue(0)
        }
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "setSearchActiveOff"), object: nil)
        misc.removeObserverForLastView()
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        
        if let chatID = UserDefaults.standard.string(forKey: "currentChatID.nativ") {
            let myID: Int = UserDefaults.standard.integer(forKey: "myID.nativ")
            let inConversationRef = FIRDatabase.database().reference().child("chats").child(chatID).child("\(myID)_inConversation")
            inConversationRef.setValue(true)
        }
        
        if let myIDFIR = UserDefaults.standard.string(forKey: "myIDFIR.nativ") {
            let inFriendList = UserDefaults.standard.bool(forKey: "inFriendList.nativ")
            if inFriendList {
                let inFriendListRef = FIRDatabase.database().reference().child("users").child(myIDFIR).child("inFriendList")
                inFriendListRef.setValue(true)
            }
            
            let inNotifications = UserDefaults.standard.bool(forKey: "inNotifications.nativ")
            if inNotifications {
                let inNotificationsRef = FIRDatabase.database().reference().child("users").child(myIDFIR).child("inNotifications")
                inNotificationsRef.setValue(true)
            }
            
            let inPostID = UserDefaults.standard.integer(forKey: "inPostID.nativ")
            if inPostID != 0  {
                let inPostIDRef = FIRDatabase.database().reference().child("users").child(myIDFIR).child("inPostID")
                inPostIDRef.setValue(inPostID)
            }
            
            let isLoggedInRef = FIRDatabase.database().reference().child("users").child(myIDFIR).child("isLoggedIn")
            isLoggedInRef.observeSingleEvent(of: .value, with: { (snapshot) in
                if let value = snapshot.value as? Bool {
                    UserDefaults.standard.set(value, forKey: "isUserLoggedIn.nativ")
                    UserDefaults.standard.synchronize()
                }
            })
        }
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        misc.refreshLastView()
        FBSDKAppEvents.activateApp()
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        if let chatID = UserDefaults.standard.string(forKey: "currentChatID.nativ") {
            let myID: Int = UserDefaults.standard.integer(forKey: "myID.nativ")
            let inConversationRef = FIRDatabase.database().reference().child("chats").child(chatID).child("\(myID)_inConversation")
            inConversationRef.setValue(false)
        }
        
        if let myIDFIR = UserDefaults.standard.string(forKey: "myIDFIR.nativ") {
            let inFriendListRef = FIRDatabase.database().reference().child("users").child(myIDFIR).child("inFriendList")
            inFriendListRef.setValue(false)
            
            let inNotificationsRef = FIRDatabase.database().reference().child("users").child(myIDFIR).child("inNotifications")
            inNotificationsRef.setValue(false)
            
            let inPostIDRef = FIRDatabase.database().reference().child("users").child(myIDFIR).child("inPostID")
            inPostIDRef.setValue(0)
        }
        
        misc.clearTempDirectory()
    }
    
    // MARK: Push notifications
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        var tokenString = ""
        for i in 0..<deviceToken.count {
            tokenString += String(format: "%02.2hhx", arguments: [deviceToken[i]])
        }
        
        UserDefaults.standard.removeObject(forKey: "deviceToken.nativ")
        UserDefaults.standard.set(tokenString, forKey: "deviceToken.nativ")
        UserDefaults.standard.synchronize()
        
        let myID: Int = UserDefaults.standard.integer(forKey: "myID.nativ")
        if myID <= 0 {
            self.sendDeviceToken(myID, deviceToken: tokenString)
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register:", error)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        let aps: NSDictionary = userInfo["aps"] as! NSDictionary
        let badgeNumber = aps["badge"] as! Int
        UserDefaults.standard.set(badgeNumber, forKey: "badgeNumber.nativ")
        
        let subject = aps["subject"] as! String
        if subject == "pond" {
            let oldBadge = UserDefaults.standard.integer(forKey: "badgeNumberDrop.nativ")
            let newBadge = oldBadge + 1
            UserDefaults.standard.set(newBadge, forKey: "badgeNumberDrop.nativ")
        } else if subject == "friendList" || subject == "friendRequest" || subject == "chat" {
            let oldBadge = UserDefaults.standard.integer(forKey: "badgeNumberFriendList.nativ")
            let newBadge = oldBadge + 1
            UserDefaults.standard.set(newBadge, forKey: "badgeNumberFriendList.nativ")
        } else {
            let oldBadge = UserDefaults.standard.integer(forKey: "badgeNumberNotifications.nativ")
            let newBadge = oldBadge + 1
            UserDefaults.standard.set(newBadge, forKey: "badgeNumberNotifications.nativ")
        }
        UserDefaults.standard.synchronize()
        
        UIApplication.shared.applicationIconBadgeNumber = badgeNumber
        NotificationCenter.default.post(name: Notification.Name(rawValue: "didReceiveNotification"), object: nil)
    }
    
    // AWS
    
    func sendDeviceToken(_ myID: Int, deviceToken: String) {
        let sendURL = URL(string: "https://dotnative.io/newDeviceID")
        var sendRequest = URLRequest(url: sendURL!)
        sendRequest.httpMethod = "POST"
        
        let sendString = "userID=\(myID)&deviceID=\(deviceToken)"
        
        sendRequest.httpBody = sendString.data(using: String.Encoding.utf8)
        
        let task = URLSession.shared.dataTask(with: sendRequest as URLRequest) {
            (data, response, error) in
            
            if error != nil {
                print("error=\(String(describing: error))")
                return
            }
            
            do{
                let json = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as? NSDictionary
                
                if let parseJSON = json {
                    let status: String = parseJSON["status"] as! String
                    let message = parseJSON["message"] as! String
                    print("status: \(status), message: \(message)")
                }
                
            } catch {
                print(error)
            }
            
        }
        
        task.resume()
    }
    
}

