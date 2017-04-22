//
//  SideMenuTableViewController.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FBSDKShareKit
import TwitterKit
import GoogleSignIn
import FirebaseInvites
import FirebaseAnalytics

class SideMenuTableViewController: UITableViewController, GIDSignInUIDelegate, FIRInviteDelegate {

    // MARK: - Outlets/Variables
    
    var myID: Int = 0
    var myIDFIR: String = "0000000000000000000000000000"
    let misc = Misc()
    
    var selectedIndex: Int = 0
    
    var dropBadge: Int = 0
    var friendBadge: Int = 0
    var notificationsBadge: Int = 0
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.estimatedRowHeight = 56
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.layoutMargins = UIEdgeInsets.zero
        self.tableView.separatorInset = UIEdgeInsets.zero
        self.clearsSelectionOnViewWillAppear = true 
    }
    
    override func viewWillAppear(_ animated: Bool) {
        let myInfo = misc.setMyID()
        self.myID = myInfo[1] as! Int
        self.myIDFIR = myInfo[2] as! String
        if self.myID > 0 {
            self.setBadgeNumbers()
        }
        
        self.selectedIndex = UserDefaults.standard.integer(forKey: "sideMenuIndex.nativ")
        self.tableView.reloadData()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - TableView
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.myID <= 0 {
            return 2
        } else {
            return 13
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // not signed in
        if self.myID <= 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "menuCell", for: indexPath) as! SideMenuTableViewCell
            if indexPath.row == 0 {
                if self.selectedIndex == indexPath.row {
                    cell.menuLabel.textColor = misc.nativColor
                    cell.menuImageView.image = UIImage(named: "pondIconSelected")
                    cell.backgroundColor = misc.nativFade
                } else {
                    cell.menuLabel.textColor = .black
                    cell.menuImageView.image = UIImage(named: "pondIconUnselected")
                    cell.backgroundColor = .white
                }
                cell.menuLabel.text = "Flow"
            } else {
                if self.selectedIndex == indexPath.row {
                    cell.menuLabel.textColor = misc.nativColor
                    cell.menuImageView.image = UIImage(named: "signUpIconSelected")
                    cell.backgroundColor = misc.nativFade
                } else {
                    cell.menuLabel.textColor = .black
                    cell.menuImageView.image = UIImage(named: "signUpIconUnselected")
                    cell.backgroundColor = .white
                }
                cell.menuLabel.text = "Sign Up :)"
            }
            return cell

        } else {
            // spacers 
            if indexPath.row == 5 || indexPath.row == 9 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "menuSpacerCell", for: indexPath) as! SideMenuTableViewCell
                return cell
            }
            
            // connect buttons
            if indexPath.row >= 10 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "menuButtonCell", for: indexPath) as! SideMenuTableViewCell
                switch indexPath.row {
                case 10:
                    cell.buttonView.backgroundColor = UIColor(red: 59/255.0, green: 89/255.0, blue: 152/255.0, alpha: 1)
                    cell.buttonView.layer.shadowOffset = CGSize(width: -1, height: 1)
                    cell.buttonView.layer.shadowOpacity = 0.42
                    cell.buttonView.layer.masksToBounds = false
                    cell.buttonView.layer.cornerRadius = 2.5
                    cell.menuLabel.text = "Connect with Facebook"
                    cell.menuLabel.textColor = .white
                    cell.menuLabel.adjustsFontSizeToFitWidth = true
                    cell.menuImageView.image = UIImage(named: "fbLogo")
                    let tapButtonView = UITapGestureRecognizer(target: self, action: #selector(self.inviteThroughFB))
                    cell.buttonView.addGestureRecognizer(tapButtonView)
                    let tapLabel = UITapGestureRecognizer(target: self, action: #selector(self.inviteThroughFB))
                    cell.menuLabel.addGestureRecognizer(tapLabel)
                    let tapImageView = UITapGestureRecognizer(target: self, action: #selector(self.inviteThroughFB))
                    cell.menuImageView.addGestureRecognizer(tapImageView)
                case 11:
                    cell.buttonView.backgroundColor = UIColor(red: 29/255.0, green: 161/255.0, blue: 242/255.0, alpha: 1)
                    cell.buttonView.layer.shadowOffset = CGSize(width: -1, height: 1)
                    cell.buttonView.layer.shadowOpacity = 0.42
                    cell.buttonView.layer.masksToBounds = false
                    cell.buttonView.layer.cornerRadius = 2.5
                    cell.menuLabel.text = "Connect with Twitter"
                    cell.menuLabel.adjustsFontSizeToFitWidth = true
                    cell.menuLabel.textColor = .white
                    cell.menuImageView.image = UIImage(named: "twitterLogo")
                    let tapButtonView = UITapGestureRecognizer(target: self, action: #selector(self.connectWithTwitter))
                    cell.buttonView.addGestureRecognizer(tapButtonView)
                    let tapLabel = UITapGestureRecognizer(target: self, action: #selector(self.connectWithTwitter))
                    cell.menuLabel.addGestureRecognizer(tapLabel)
                    let tapImageView = UITapGestureRecognizer(target: self, action: #selector(self.connectWithTwitter))
                    cell.menuImageView.addGestureRecognizer(tapImageView)
                default:
                    cell.buttonView.backgroundColor = .white
                    cell.buttonView.layer.shadowOffset = CGSize(width: -1, height: 1)
                    cell.buttonView.layer.shadowOpacity = 0.42
                    cell.buttonView.layer.masksToBounds = false
                    cell.buttonView.layer.cornerRadius = 2.5
                    cell.menuLabel.text = "Connect with Google"
                    cell.menuLabel.textColor = .black
                    cell.menuLabel.font = UIFont(name: "Roboto", size: 17)
                    cell.menuImageView.image = UIImage(named: "googleLogo")
                    cell.imageWidth.constant = 25
                    cell.imageLeading.constant = 7.5
                    cell.labelLeading.constant = 15.5
                    let tapButtonView = UITapGestureRecognizer(target: self, action: #selector(self.inviteThroughGoogle))
                    cell.buttonView.addGestureRecognizer(tapButtonView)
                    let tapLabel = UITapGestureRecognizer(target: self, action: #selector(self.inviteThroughGoogle))
                    cell.menuLabel.addGestureRecognizer(tapLabel)
                    let tapImageView = UITapGestureRecognizer(target: self, action: #selector(self.inviteThroughGoogle))
                    cell.menuImageView.addGestureRecognizer(tapImageView)
                }
                return cell
            }
            
            // secondary cells
            if indexPath.row > 5 && indexPath.row < 9 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "menuLabelCell", for: indexPath) as! SideMenuTableViewCell
                if selectedIndex == indexPath.row {
                    cell.menuLabel.textColor = misc.nativColor
                    cell.backgroundColor = misc.nativFade
                } else {
                    cell.menuLabel.textColor = .black
                    cell.backgroundColor = .white
                }
                
                switch indexPath.row {
                case 6:
                    cell.menuLabel.text = "Report Bug"
                case 7:
                    cell.menuLabel.text = "Feedback"
                default:
                    cell.menuLabel.text = "About .nativ"
                }
            
                return cell
            }
            
            // normal navigation
            let cell = tableView.dequeueReusableCell(withIdentifier: "menuCell", for: indexPath) as! SideMenuTableViewCell
            if self.selectedIndex == indexPath.row {
                cell.menuLabel.textColor = misc.nativColor
                cell.backgroundColor = misc.nativFade
            } else {
                cell.menuLabel.textColor = .black
                cell.backgroundColor = .white
            }
            cell.badgeLabel.isHidden = true
            switch indexPath.row {
            case 0:
                cell.menuLabel.text = "Flow"
                if self.selectedIndex == indexPath.row {
                    cell.menuImageView.image = UIImage(named: "pondIconSelected")
                } else {
                    cell.menuImageView.image = UIImage(named: "pondIconUnselected")
                }
            case 1:
                cell.menuLabel.text = "Drops"
                if self.selectedIndex == indexPath.row {
                    cell.menuImageView.image = UIImage(named: "dropsIconSelected")
                } else {
                    cell.menuImageView.image = UIImage(named: "dropsIconUnselected")
                }
                if self.dropBadge > 0 {
                    cell.badgeLabel.isHidden = false
                    cell.badgeLabel.text = misc.setCount(self.dropBadge)
                    cell.badgeLabel.textColor = .white
                    cell.badgeLabel.backgroundColor = .red
                    cell.badgeLabel.layer.cornerRadius = cell.badgeLabel.frame.size.height/2
                    cell.badgeLabel.layer.masksToBounds = true
                }
            case 2:
                cell.menuLabel.text = "Chat/Friends"
                if self.selectedIndex == indexPath.row {
                    cell.menuImageView.image = UIImage(named: "chatIconSelected")
                } else {
                    cell.menuImageView.image = UIImage(named: "chatIconUnselected")
                }
                if self.friendBadge > 0 {
                    cell.badgeLabel.isHidden = false
                    cell.badgeLabel.text = misc.setCount(self.friendBadge)
                    cell.badgeLabel.textColor = .white
                    cell.badgeLabel.backgroundColor = .red
                    cell.badgeLabel.layer.cornerRadius = cell.badgeLabel.frame.size.height/2
                    cell.badgeLabel.layer.masksToBounds = true
                }
            case 3:
                cell.menuLabel.text = "Notifications"
                if self.selectedIndex == indexPath.row {
                    cell.menuImageView.image = UIImage(named: "notificationsIconSelected")
                } else {
                    cell.menuImageView.image = UIImage(named: "notificationsIconUnselected")
                }
                if self.notificationsBadge > 0 {
                    cell.badgeLabel.isHidden = false
                    cell.badgeLabel.text = misc.setCount(self.notificationsBadge)
                    cell.badgeLabel.textColor = .white
                    cell.badgeLabel.backgroundColor = .red
                    cell.badgeLabel.layer.cornerRadius = cell.badgeLabel.frame.size.height/2
                    cell.badgeLabel.layer.masksToBounds = true
                }
            case 4:
                cell.menuLabel.text = "Me"
                if self.selectedIndex == indexPath.row {
                    cell.menuImageView.image = UIImage(named: "myProfileIconSelected")
                } else {
                    cell.menuImageView.image = UIImage(named: "myProfileIconUnselected")
                }
            default:
                cell.menuLabel.text = "how did this show up?"
                cell.menuImageView.image = UIImage(named: "anonSegment")
            }
            
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath) as! SideMenuTableViewCell
        
        if self.myID <= 0 {
            if indexPath.row == 0 {
                NotificationCenter.default.post(name: Notification.Name(rawValue: "turnToPondList"), object: nil)
            } else {
                NotificationCenter.default.post(name: Notification.Name(rawValue: "turnToSignUp"), object: nil)
            }
            cell.backgroundColor = misc.nativFade
            
        } else {
            switch indexPath.row {
            case 0:
                NotificationCenter.default.post(name: Notification.Name(rawValue: "turnToPondList"), object: nil)
                cell.backgroundColor = misc.nativFade

            case 1:
                NotificationCenter.default.post(name: Notification.Name(rawValue: "turnToDropList"), object: nil)
                cell.backgroundColor = misc.nativFade

            case 2:
                NotificationCenter.default.post(name: Notification.Name(rawValue: "turnToFriendList"), object: nil)
                cell.backgroundColor = misc.nativFade

            case 3:
                NotificationCenter.default.post(name: Notification.Name(rawValue: "turnToNotifications"), object: nil)
                cell.backgroundColor = misc.nativFade

            case 4:
                NotificationCenter.default.post(name: Notification.Name(rawValue: "turnToMyProfile"), object: nil)
                cell.backgroundColor = misc.nativFade

            case 6:
                NotificationCenter.default.post(name: Notification.Name(rawValue: "turnToReportBug"), object: nil)
                cell.backgroundColor = misc.nativFade
                
            case 7:
                NotificationCenter.default.post(name: Notification.Name(rawValue: "turnToFeedback"), object: nil)
                cell.backgroundColor = misc.nativFade
                
            case 8:
                NotificationCenter.default.post(name: Notification.Name(rawValue: "turnToAbout"), object: nil)
                cell.backgroundColor = misc.nativFade

            default:
                return
            }
            
        }
        
        if indexPath.row <= 4 || (indexPath.row >= 6 && indexPath.row <= 8) {
            self.dismiss(animated: true, completion: nil)
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
    
    func setBadgeNumbers() {
        let dropBadge = UserDefaults.standard.integer(forKey: "badgeNumberDrop.nativ")
        self.dropBadge = dropBadge
        let friendBadge = UserDefaults.standard.integer(forKey: "badgeNumberFriendList.nativ")
        self.friendBadge = friendBadge
        let notificationsBadge =  UserDefaults.standard.integer(forKey: "badgeNumberNotifications.nativ")
        self.notificationsBadge = notificationsBadge
    }
    
    // MARK: - Invites
    
    func inviteThroughFB() {
        self.logFBTapped()
        let content = FBSDKAppInviteContent()
        content.appLinkURL = URL(string: "https://fb.me/1830365443917748")
        content.appInvitePreviewImageURL = URL(string: "https://ibb.co/iKW6GQ")
        FBSDKAppInviteDialog.show(from: self, with: content, delegate: self)
    }
    
    func inviteThroughGoogle() {
        GIDSignIn.sharedInstance().uiDelegate = self
        GIDSignIn.sharedInstance().signIn()
    }
    
    func connectWithTwitter() {
        Twitter.sharedInstance().logIn { session, error in
            if (session != nil) {
                self.logTwitterTapped()
                self.displayAlert("Signed in as \(session!.userName)", alertMessage: "You can now share pond posts, host posts, your pages, and your pinned scrapbook entries on Twitter!")
                return
            } else {
                self.displayAlert("Error", alertMessage: "Could not sign in to Twitter with the information on your phone. Please check your stored Twitter account information.")
                print ("error: \(String(describing: error?.localizedDescription))")
            }
        }
    }
  
    func googleSignInSuccess() {
        if let invite = FIRInvites.inviteDialog() {
            var uName: String
            if let name = GIDSignIn.sharedInstance().currentUser.profile.name {
                uName = name
            } else {
                if let fullName = UserDefaults.standard.string(forKey: "myFullName.nativ") {
                    uName = fullName
                } else {
                    uName = ".nativ"
                }
            }
            invite.setInviteDelegate(self)
            invite.setMessage(".nativ Invite from \(uName)")
            invite.setTitle(".nativ invite")
            invite.setDeepLink("https://itunes.apple.com/us/app/.nativ/id1226225830")
            invite.setCallToActionText("Dive In!")
            invite.setCustomImage("https://ibb.co/iKW6GQ")
            invite.open()
        }
    }
    
    private func inviteFinished(withInvitations invitationIds: [Any], error: Error?) {
        if let error = error {
            if error.localizedDescription.lowercased() != "canceled by user" {
                self.displayAlert("Google Invite Error", alertMessage: "Sorry, we could not send your friends invites. Please report this bug. " + error.localizedDescription)
                return
            }
        } else {
            self.logGoogleTapped()
            self.displayAlert(":)", alertMessage: "Google invites sent!")
            return
        }
    }
    
    func googleSignInFail() {
        self.displayAlert("Google Sign In Error", alertMessage: "Sorry, we've encountered an error trying to sign into your google account. Please report the bug if this persists.")
        return
    }
    
    // MARK: Analytics
    
    func logFBTapped() {
        FIRAnalytics.logEvent(withName: "fbInviteTapped", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    func logTwitterTapped() {
        FIRAnalytics.logEvent(withName: "twitterConnectTapped", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    func logGoogleTapped() {
        FIRAnalytics.logEvent(withName: "googleInviteTapped", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
}

// MARK: - FB Extension

extension SideMenuTableViewController: FBSDKAppInviteDialogDelegate {
    func appInviteDialog(_ appInviteDialog: FBSDKAppInviteDialog!, didCompleteWithResults results: [AnyHashable : Any]!) {
        print("fb success")
    }
    
    func appInviteDialog(_ appInviteDialog: FBSDKAppInviteDialog!, didFailWithError error: Error!) {
        self.displayAlert("No Face :(", alertMessage: "Sorry, we encountered an error and are unable to invite through facebook. Please report this bug.")
        return
    }
}
