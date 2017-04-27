//
//  AboutViewController.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseAnalytics
import SideMenu
import MIBadgeButton_Swift

class AboutViewController: UIViewController, UIPopoverPresentationControllerDelegate {

    // MARK: - Outlets/Variables
    
    var myID: Int = 0
    var myIDFIR: String = "0000000000000000000000000000"
    var badgeButton = MIBadgeButton()
    var badgeBarButton = UIBarButtonItem()
    let misc = Misc()
    
    @IBOutlet weak var scrollView: UIScrollView!
    
    @IBOutlet weak var aboutLabel: UILabel!
    @IBOutlet weak var authorLabel: UILabel!
    @IBOutlet weak var aboutWhiteView: UIView!
    @IBOutlet weak var creditWhiteView: UIView!
    @IBOutlet weak var termsWhiteView: UIView!
    
    @IBOutlet weak var creditLabel: UILabel!
    @IBOutlet weak var creativeCommonsButton: UIButton!
    @IBAction func creativeCommonsButtonTapped(_ sender: AnyObject) {
        self.linkToCC()
    }
    
    @IBOutlet weak var privacyPolicyButton: UIButton!
    @IBAction func privacyPolicyButtonTapped(_ sender: Any) {
        self.openPrivacyPolicy()
    }
    
    @IBOutlet weak var termsButton: UIButton!
    @IBAction func termsButtonTapped(_ sender: Any) {
        self.presentTermsPop()
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = ".nativ"
        
        self.creativeCommonsButton.setTitle("Link to Creative Commons License", for: .normal)
        self.privacyPolicyButton.setTitle("View our Privacy Policy", for: .normal)
        self.termsButton.setTitle("View our Terms & Conditions", for: .normal)
        
        self.aboutLabel.numberOfLines = 0
        self.aboutLabel.attributedText = misc.stringWithColoredTags(self.aboutText, time: "default", fontSize: 17, timeSize: 17)
        
        self.authorLabel.text = "-@ge0rgetang"
        
        self.creditLabel.numberOfLines = 0
        self.creditLabel.text = self.creditText
        
        self.makeWhiteViewsFancy()
        self.setMenuBarButton()
        self.setSideMenu()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        misc.setSideMenuIndex(8)
        
        let myInfo = misc.setMyID()
        self.myID = myInfo[1] as! Int
        self.myIDFIR = myInfo[2] as! String
        
        if self.myID <= 0 || self.myIDFIR == "0000000000000000000000000000" {
            NotificationCenter.default.post(name: Notification.Name(rawValue: "signedOut"), object: nil)
        } else {
            self.logViewAboutdotnative()
        }
        
        self.setNotifications()
        self.updateBadge()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.removeNotifications()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        misc.clearWebImageCache()
    }
    
    //MARK: - Navigation
    
    func openPrivacyPolicy() {
        if let linkURL = URL(string: "https://www.iubenda.com/privacy-policy/7955712") {
            UIApplication.shared.open(linkURL, options: [:], completionHandler: nil)
        }
    }
    
    func presentTermsPop() {
        let termsPopViewController = storyboard?.instantiateViewController(withIdentifier: "TermsPopViewController") as! TermsPopViewController
        termsPopViewController.modalPresentationStyle = .popover
        termsPopViewController.preferredContentSize = CGSize(width: 320, height: 320)
        
        if let popoverController = termsPopViewController.popoverPresentationController {
            popoverController.delegate = self
            popoverController.sourceView = self.termsButton
            popoverController.sourceRect = self.termsButton.bounds
        }
        
        self.present(termsPopViewController, animated: true, completion: nil)
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
    
    func presentSideMenu() {
        self.present(SideMenuManager.menuLeftNavigationController!, animated: true, completion: nil)
    }
    
    // MARK: - Popover
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    // MARK: - Label content
    
    var aboutText =
        "There was no sudden epiphany. It was the train ride on the BART on a rainy day. It was watching the steady flow of foot traffic from a corner cafe. It was daydreaming during lecture. It was even waiting in one of many indiscernable lines. The idea was a series of small moments that added up over time." + "\r\n\n" +
        "I wanted to get people in touch with someone that could be sitting right next to them. I wanted actual, tangible, real connection with real participation in the real world. I wanted change. So I got together with my buddy Tam and decided to try to change something. I figured, even if that change was a tiny drop, at the end of the day, I'd still have a cool app." + "\r\n\n" +
        ".nativ was born."
    
    var creditText =
        "Our main app icon, was designed by Ashley J.B. Chen. Check her out at ashleyjbchen.com!" + "\r\n\n" +
            "The following icons fall under Creative Commons and were all downloaded from thenounproject.com (The Noun Project):" + "\r\n\n" +
            "Camera, by Alfa Design" + "\r\n\n" +
            "Paper Airplane, Upvote, by artworkbean" + "\r\n\n" +
            "Menu, by Arunkumar" + "\r\n\n" +
            "Profile, by Awesome" + "\r\n\n" +
            "Share, by Aya Sofya" + "\r\n\n" +
            "Notification (flipped across y-axis), by Dinosoft Labs" + "\r\n\n" +
            "Drops, by Drishya" + "\r\n\n" +
            "Fire, by HLD" + "\r\n\n" +
            "Loading (rotated over several angles), by Hopkins" + "\r\n\n" +
            "Chat, by i cons" + "\r\n\n" +
            "Eye Mask, by Jems Mayor" + "\r\n\n" +
            "Reply (flipped across y-axis), by joe pictos" + "\r\n\n" +
            "Accept, by Kiran Joseph" + "\r\n\n" +
            "List, by Laurent Sutterlity" + "\r\n\n" +
            "Add Person, Mail, by MFRA" + "\r\n\n" +
            "My Location, by Miguel C Balandrano" + "\r\n\n" +
            "Settings, by mikicon" + "\r\n\n" +
            "Add Location, by Oliviu Stoian" + "\r\n\n" +
            "Upload Photos, by Ryan Beck" + "\r\n\n" +
            "Team, by Samy Menai" + "\r\n\n" +
            "Water, by Sergey Demushkin" + "\r\n\n" +
            "Add Profile, by Shastry" + "\r\n\n" +
            "Trend Up Right, by Travis Avery" + "\r\n\n" +
            "Map, by Yo! Baba" + "\r\n\n" +
    "Additionally, all icons were modified when selected by filling with our main color. A link to the Creative Commons license is provided below."
    
    // MARK: - Button link
    
    func linkToCC() {
        if let linkURL = URL(string: "https://creativecommons.org/licenses/by/4.0/legalcode") {
            UIApplication.shared.open(linkURL, options: [:], completionHandler: nil)
        }
    }
    
    // MARK: - Notifications
    
    func updateBadge() {
        let badge = UserDefaults.standard.integer(forKey: "badgeNumber.native")
        if badge > 0 {
            self.badgeButton.badgeString = "\(badge)"
        } else {
            self.badgeButton.badgeString = nil
        }
    }
    
    func setNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateBadge), name: NSNotification.Name(rawValue: "didReceiveNotification"), object: nil)
    }
    
    func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "didReceiveNotification"), object: nil)
    }
    
    // MARK: - Misc
    
    func makeWhiteViewsFancy () {
        self.aboutWhiteView.backgroundColor = UIColor.white
        self.aboutWhiteView.layer.masksToBounds = false
        self.aboutWhiteView.layer.cornerRadius = 2.5
        self.aboutWhiteView.layer.shadowOffset = CGSize(width: -1, height: 1)
        self.aboutWhiteView.layer.shadowOpacity = 0.42
        self.aboutWhiteView.sizeToFit()
        
        self.creditWhiteView.backgroundColor = UIColor.white
        self.creditWhiteView.layer.masksToBounds = false
        self.creditWhiteView.layer.cornerRadius = 2.5
        self.creditWhiteView.layer.shadowOffset = CGSize(width: -1, height: 1)
        self.creditWhiteView.layer.shadowOpacity = 0.42
        self.creditWhiteView.sizeToFit()
        
        self.termsWhiteView.backgroundColor = UIColor.white
        self.termsWhiteView.layer.masksToBounds = false
        self.termsWhiteView.layer.cornerRadius = 2.5
        self.termsWhiteView.layer.shadowOffset = CGSize(width: -1, height: 1)
        self.termsWhiteView.layer.shadowOpacity = 0.42
        self.termsWhiteView.sizeToFit()
    }
    
    func setMenuBarButton() {
        self.badgeButton.setImage(UIImage(named: "menu"), for: .normal)
        self.badgeButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        self.badgeButton.addTarget(self, action: #selector(self.presentSideMenu), for: .touchUpInside)
        
        let badgeNumber = UserDefaults.standard.integer(forKey: "badgeNumber.nativ")
        if badgeNumber > 0 {
            self.badgeButton.badgeString = "\(badgeNumber)"
        }
        self.badgeButton.badgeTextColor = .white
        self.badgeButton.badgeBackgroundColor = .red
        self.badgeButton.badgeEdgeInsets = UIEdgeInsetsMake(2, 0, 0, 0)
        
        self.badgeBarButton.customView = self.badgeButton
        self.navigationItem.setLeftBarButton(self.badgeBarButton, animated: false)
    }
    
    // MARK: - Analytics
    
    func logViewAboutdotnative() {
        FIRAnalytics.logEvent(withName: "viewAbout", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
}
