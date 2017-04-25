//
//  DropListViewController.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseAnalytics
import FirebaseDatabase
import SDWebImage
import CryptoSwift
import SideMenu
import MIBadgeButton_Swift

class DropListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, EditPondParentProtocol {

    // MARK: - Outlets/Variables
    
    var myID: Int = 0
    var myIDFIR: String = "0000000000000000000000000000"
    
    var firstLoad: Bool = true
    var firstLoadNewObservers = false
    var scrollPosition: String = "top"
    var newPostsCount: Int = 0
    var parentRow: Int = 0
    var isRemoved = false
    var lastContentOffset: CGFloat = 0
    
    var parentPostToPass: [String:Any] = [:]
    var userIDToPass: Int = -2
    var userIDFIRToPass: String = "-2"
    var userHandleToPass: String = "-2"
    
    var urlArray: [URL] = []
    var firstPostID: Int = 0
    var dropHeightAtIndexPath: [IndexPath:CGFloat] = [:]
    var dropList: [[String:Any]] = []
    var observedPosts: [(postType: String, postID: Int)] = [] {
        didSet {
            var isDifferent: Bool = false
            for (index, post) in oldValue.enumerated() {
                if post != self.observedPosts[index] {
                    isDifferent = true
                    break
                }
            }
            
            if isDifferent {
                self.firstLoadNewObservers = true
                self.observeDropList()
            }
        }
    }
    
    let misc = Misc()
    var activityView = UIView()
    var activityIndicator = UIActivityIndicatorView()
    var activityLabel = UILabel()
    var scrollToTopButton = UIButton()
    var badgeButton = MIBadgeButton()
    var badgeBarButton = UIBarButtonItem()
    
    var ref = FIRDatabase.database().reference()
    
    @IBOutlet weak var dropListTableView: UITableView!
    
    @IBAction func unwindToDropList(_ segue: UIStoryboardSegue){}
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = "Drops"
        
        self.dropListTableView.delegate = self
        self.dropListTableView.dataSource = self
        self.dropListTableView.rowHeight = UITableViewAutomaticDimension
        self.dropListTableView.separatorStyle = UITableViewCellSeparatorStyle.none
        self.dropListTableView.backgroundColor = misc.softGrayColor
        self.dropListTableView.showsVerticalScrollIndicator = false
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(self.handleRefreshControl), for: .valueChanged)
        self.dropListTableView.addSubview(refreshControl)
        
        self.setMenuBarButton()
        self.setSideMenu()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.firstLoad = true
        
        let myInfo = misc.setMyID()
        self.myID = myInfo[1] as! Int
        self.myIDFIR = myInfo[2] as! String
        
        if self.myID <= 0 || self.myIDFIR == "0000000000000000000000000000" {
            NotificationCenter.default.post(name: Notification.Name(rawValue: "signedOut"), object: nil)
        }
        
        self.logViewDropList()
        self.setNotifications()
        let badge = UserDefaults.standard.integer(forKey: "badgeNumberDrop.nativ")
        if badge > 0 {
            misc.clearNotifications("pond")
        }
        misc.resetBadgeForKey("badgeNumberDrop.nativ")
        misc.setSideMenuIndex(1)
        self.updateBadge()
        self.observeDropList()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.dropListTableView.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        self.removeNotifications()
        self.removeObserverForDropList()
        if self.urlArray.count >= 210 {
            self.clearArrays()
        }
    }
    
    deinit {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        NotificationCenter.default.removeObserver(self)
        self.removeObserverForDropList()
        self.clearArrays()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        self.firstLoad = true
        self.clearArrays()
        misc.clearWebImageCache()
        self.observeDropList()
    }
    
    // MARK: - TableView
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.dropList.isEmpty {
            return 1
        } else {
            return dropList.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: PostTableViewCell
        
        if self.dropList.isEmpty {
            cell = tableView.dequeueReusableCell(withIdentifier: "anonParentNoReplyCell", for: indexPath) as! PostTableViewCell
            cell.whiteView.backgroundColor = UIColor.white
            cell.whiteView.layer.masksToBounds = false
            cell.whiteView.layer.cornerRadius = 2.5
            cell.whiteView.layer.shadowOffset = CGSize(width: -1, height: 1)
            cell.whiteView.layer.shadowOpacity = 0.42
            cell.whiteView.sizeToFit()
            cell.postContentTextView.textColor = .lightGray
            
            if self.firstLoad {
                cell.postContentTextView.text = "loading drops..."
            } else {
                cell.postContentTextView.text = "This is a list of all posts you've created or responded to. You don't have any drops right now. Switch to the Flow to start a conversation!"
            }
            
            return cell
        }
        
        let individualPost = self.dropList[indexPath.row]
        let postContent = individualPost["postContent"] as! String
        let timestamp = individualPost["timestamp"] as! String
        
        var postType: String
        if let _ = individualPost["userHandle"] as? String {
            postType = "pond"
        } else {
            postType = "anon"
        }
        
        if postType == "pond" {
            if let reply = individualPost["reply"] as? [String:Any] {
                cell = tableView.dequeueReusableCell(withIdentifier: "pondParentCell", for: indexPath) as! PostTableViewCell
                let replyContent = reply["replyContent"] as! String
                let replyHandle = reply["replyHandle"] as! String
                let replyTimestamp = reply["replyTimestamp"] as! String
                
                let contentString = "@\(replyHandle) \(replyTimestamp)" + "\r\n" + "\(replyContent)"
                cell.recentReplyLabel.attributedText = misc.stringWithColoredTags(contentString, time: replyTimestamp, fontSize: 18, timeSize: 14)
                cell.recentReplyLabel.numberOfLines = 0
                
                let replyPicURL = reply["replyPicURL"] as! URL
                cell.userReplyPicImageView.layer.cornerRadius = cell.userReplyPicImageView.frame.size.width/2
                cell.userReplyPicImageView.clipsToBounds = true
                cell.userReplyPicImageView.sd_setImage(with: replyPicURL)
                let replyTap = UITapGestureRecognizer(target: self, action: #selector(self.presentUserProfileFromReply))
                cell.userReplyPicImageView.addGestureRecognizer(replyTap)
            } else {
                cell = tableView.dequeueReusableCell(withIdentifier: "pondParentNoReplyCell", for: indexPath) as! PostTableViewCell
            }
            
            let picURL = individualPost["picURL"] as! URL
            cell.userPicImageView.layer.cornerRadius = cell.userPicImageView.frame.size.width/2
            cell.userPicImageView.clipsToBounds = true
            cell.userPicImageView.sd_setImage(with: picURL)
            let tap = UITapGestureRecognizer(target: self, action: #selector(self.presentUserProfile))
            cell.userPicImageView.addGestureRecognizer(tap)
            
            let handle = individualPost["userHandle"] as! String
            let string = "@\(handle) \(timestamp)" + "\r\n" + "\(postContent)"
            cell.postContentTextView.attributedText = misc.stringWithColoredTags(string, time: timestamp, fontSize: 14, timeSize: 11)
            
        } else {
            if let reply = individualPost["reply"] as? [String:Any] {
                cell = tableView.dequeueReusableCell(withIdentifier: "anonParentCell", for: indexPath) as! PostTableViewCell
                let replyContent = reply["replyContent"] as! String
                let replyTimestamp = reply["replyTimestamp"] as! String
                
                let contentString = "\(replyTimestamp)" + "\r\n" + "\(replyContent)"
                cell.recentReplyLabel.attributedText = misc.anonStringWithColoredTags(contentString, time: replyTimestamp, fontSize: 18, timeSize: 14)
                cell.recentReplyLabel.numberOfLines = 0
            } else {
                cell = tableView.dequeueReusableCell(withIdentifier: "anonParentNoReplyCell", for: indexPath) as! PostTableViewCell
            }
            
            let string = "\(timestamp)" + "\r\n" + "\(postContent)"
            cell.postContentTextView.attributedText = misc.anonStringWithColoredTags(string, time:timestamp, fontSize: 14, timeSize: 11)
        }
        
        cell.whiteView.backgroundColor = UIColor.white
        cell.whiteView.layer.masksToBounds = false
        cell.whiteView.layer.cornerRadius = 2.5
        cell.whiteView.layer.shadowOffset = CGSize(width: -1, height: 1)
        cell.whiteView.layer.shadowOpacity = 0.42
        cell.whiteView.sizeToFit()
        
        let postID = individualPost["postID"] as! Int
        if indexPath.row == 0 &&  postID != self.firstPostID {
            cell.whiteView.alpha = 0
            UIView.animate(withDuration: 0.1, animations: {
                cell.whiteView.alpha = 1
            })
            self.firstPostID = postID
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let height = cell.frame.size.height
        self.dropHeightAtIndexPath.updateValue(height, forKey: indexPath)
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if !self.firstLoad {
            let heightAtIndexPath = self.dropHeightAtIndexPath
            
            if let height = heightAtIndexPath[indexPath] {
                return height
            } else {
                return UITableViewAutomaticDimension
            }
        }
        
        return UITableViewAutomaticDimension
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.parentRow = indexPath.row
        let cell = tableView.cellForRow(at: indexPath) as! PostTableViewCell
        cell.whiteView.backgroundColor = misc.nativFade
        
        if !self.dropList.isEmpty {
            let individualPost = self.dropList[indexPath.row]
            let postID = individualPost["postID"] as! Int
            if postID > 0 {
                self.parentPostToPass = individualPost
                self.performSegue(withIdentifier: "fromDropListToDrop", sender: self)
            }
        } else {
            NotificationCenter.default.post(name: Notification.Name(rawValue: "turnToPondList"), object: nil)
        }
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "fromDropListToDrop" {
            if let dropViewController = segue.destination as? DropViewController {
                dropViewController.parentPost = self.parentPostToPass
                dropViewController.postID = self.parentPostToPass["postID"] as! Int
                if let _ = self.parentPostToPass["userHandle"] as? String {
                    dropViewController.isAnon = false
                } else {
                    dropViewController.isAnon = true
                }
                dropViewController.segueSender = "dropList"
                dropViewController.editPondParentDelegate = self
            }
        }
        
        if segue.identifier == "fromDropListToUserProfile" {
            if let userProfileViewController = segue.destination as? UserProfileViewController {
                userProfileViewController.segueSender = "dropList"
                userProfileViewController.userID = self.userIDToPass
                userProfileViewController.userIDFIR = self.userIDFIRToPass
                userProfileViewController.userHandle = "@\(self.userHandleToPass)"
                userProfileViewController.chatID = misc.setChatID(self.myID, userID: self.userIDToPass)
            }
        }
    }
    
    func presentUserProfile(sender: UITapGestureRecognizer) {
        let position = sender.location(in: self.dropListTableView)
        let indexPath: IndexPath! = self.dropListTableView.indexPathForRow(at: position)
        self.parentRow = indexPath.row
        
        let individualPost = self.dropList[indexPath.row]
        let userID = individualPost["userID"] as! Int
        self.userIDToPass = userID
        self.userIDFIRToPass = individualPost["userIDFIR"] as! String
        self.userHandleToPass = individualPost["userHandle"] as! String
        if self.myID != userID && userID > 0 {
            self.performSegue(withIdentifier: "fromDropListToUserProfile", sender: self)
        }
    }
    
    func presentUserProfileFromReply(sender: UITapGestureRecognizer) {
        let position = sender.location(in: self.dropListTableView)
        let indexPath: IndexPath! = self.dropListTableView.indexPathForRow(at: position)
        self.parentRow = indexPath.row
        
        let individualPost = self.dropList[indexPath.row]
        if let reply = individualPost["reply"] as? [String:Any] {
            let userID = reply["replyID"] as! Int
            self.userIDToPass = userID
            self.userIDFIRToPass = reply["replyIDFIR"] as! String
            self.userHandleToPass = reply["replyHandle"] as! String
            if self.myID != userID && userID > 0 {
                self.performSegue(withIdentifier: "fromDropListToUserProfile", sender: self)
            }
        }
    }
    
    func setSideMenu() {
        if let sideMenuNavigationController = storyboard?.instantiateViewController(withIdentifier: "SideMenuNavigationController") as? UISideMenuNavigationController {
            sideMenuNavigationController.leftSide = true
            SideMenuManager.menuLeftNavigationController = sideMenuNavigationController
            SideMenuManager.menuPresentMode = .menuSlideIn
            SideMenuManager.menuAnimationBackgroundColor = misc.nativSideMenu
            SideMenuManager.menuAnimationFadeStrength = 0.35
            SideMenuManager.menuAnimationTransformScaleFactor = 0.95
            SideMenuManager.menuAddPanGestureToPresent(toView: self.navigationController!.navigationBar)
            SideMenuManager.menuAddScreenEdgePanGesturesToPresent(toView: self.navigationController!.view)
        }
    }
    
    func presentSideMenu() {
        self.present(SideMenuManager.menuLeftNavigationController!, animated: true, completion: nil)
    }
    
    // MARK: - EditPondParent Protocol
    
    func editPondContent(_ postContent: String, timestamp: String) {
        self.dropList[self.parentRow]["postContent"] = postContent
        self.dropList[self.parentRow]["timestamp"] = "edited \(timestamp)"
        self.dropListTableView.reloadRows(at: [IndexPath(row: self.parentRow, section: 0)], with: .none)
    }
    
    func deletePondParent() {
        if self.dropList.count == 1 {
            self.dropList = []
        } else {
            self.dropList.remove(at: self.parentRow)
        }
        self.dropListTableView.reloadData()
    }
    
    func updatePondReplyCount(_ replyCount: Int) {
        self.dropList[self.parentRow]["replyCount"] = replyCount
        self.dropListTableView.reloadRows(at: [IndexPath(row: self.parentRow, section: 0)], with: .none)
    }
    
    func updatePondPointCount(_ pointsCount: Int) {
        self.dropList[self.parentRow]["pointsCount"] = pointsCount
        self.dropList[self.parentRow]["didIVote"] = "yes"
        self.dropListTableView.reloadRows(at: [IndexPath(row: self.parentRow, section: 0)], with: .none)
    }
    
    // MARK: - ScrollView
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !self.isRemoved {
            self.removeObserverForDropList()
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
            self.observeDropList()
        } else if offset == (contentHeight - frameHeight) {
            self.scrollPosition = "bottom"
            if self.dropList.count >= 42 {
                self.getDropList()
            }
        } else {
            self.scrollPosition = "middle"
        }
        
        // prefetch images on scroll down
        let posts = self.dropList
        if !posts.isEmpty {
            if self.lastContentOffset < scrollView.contentOffset.y {
                let visibleCells = self.dropListTableView.visibleCells
                if let lastCell = visibleCells.last {
                    let lastIndexPath = self.dropListTableView.indexPath(for: lastCell)
                    let lastRow = lastIndexPath!.row
                    var nextLastRow = lastRow + 10
                    
                    let maxCount = posts.count
                    if nextLastRow > (maxCount - 1) {
                        nextLastRow = maxCount - 1
                    }
                    
                    if nextLastRow <= lastRow {
                        nextLastRow = lastRow
                    }
                    
                    var urlsToPrefetch: [URL] = []
                    for index in lastRow...nextLastRow {
                        let post = posts[index]
                        if let picURL = post["picURL"] as? URL {
                            urlsToPrefetch.append(picURL)
                        }
                        if let replyPicURL = post["replyPicURL"] as? URL {
                            urlsToPrefetch.append(replyPicURL)
                        }
                    }
                    SDWebImagePrefetcher.shared().prefetchURLs(urlsToPrefetch)
                }
            }
        }
        self.lastContentOffset = scrollView.contentOffset.y
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
            self.firstLoad = false
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
        self.scrollToTopButton = UIButton(frame: CGRect(x: self.view.frame.midX - 27.5, y: self.dropListTableView.frame.origin.y, width: 55, height: 30))
        self.scrollToTopButton.layer.backgroundColor = UIColor(white: 0, alpha: 0.025).cgColor
        self.scrollToTopButton.addTarget(self, action: #selector(self.scrollToTop), for: .touchUpInside)
        self.scrollToTopButton.addTarget(self, action: #selector(self.colorTopButtonUp), for: .touchUpInside)
        self.scrollToTopButton.addTarget(self, action: #selector(self.colorTopButtonDown), for: .touchDown)
        misc.makeTopButtonFancy(self.scrollToTopButton, title: title)
        self.view.addSubview(self.scrollToTopButton)
    }
    
    func scrollToTop() {
        self.lastContentOffset = 0 
        self.dropListTableView.setContentOffset(.zero, animated: false)
        self.scrollToTopButton.removeFromSuperview()
    }
    
    func colorTopButtonDown() {
        self.scrollToTopButton.backgroundColor = misc.nativSemiFade
    }
    
    func colorTopButtonUp() {
        self.scrollToTopButton.backgroundColor = UIColor(white: 0, alpha: 0.025)
    }
    
    func setMenuBarButton() {
        self.badgeButton.setImage(UIImage(named: "menu"), for: .normal)
        self.badgeButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        self.badgeButton.addTarget(self, action: #selector(self.presentSideMenu), for: .touchUpInside)
        
        let badgeNumber = UserDefaults.standard.integer(forKey: "badgeNumber.nativ")
        if badgeNumber > 0 {
            self.badgeButton.badgeString = misc.setCount(badgeNumber)
        }
        self.badgeButton.badgeTextColor = .white
        self.badgeButton.badgeBackgroundColor = .red
        self.badgeButton.badgeEdgeInsets = UIEdgeInsetsMake(2, 0, 0, 0)
        
        self.badgeBarButton.customView = self.badgeButton
        self.navigationItem.setLeftBarButton(self.badgeBarButton, animated: false)
    }
    
    func clearArrays() {
        self.urlArray = []
        self.dropHeightAtIndexPath = [:]
        self.dropList = []
    }
    
    func handleRefreshControl(refreshControl: UIRefreshControl) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            refreshControl.endRefreshing()
        })
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
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshWithDelay), name: NSNotification.Name(rawValue: "addFirebaseObservers"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.scrollToTop), name: NSNotification.Name(rawValue: "scrollToTop"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.removeObserverForDropList), name: NSNotification.Name(rawValue: "removeFirebaseObservers"), object: nil)
    }
    
    func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "didReceiveNotification"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "addFirebaseObservers"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "scrollToTop"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "removeFirebaseObservers"), object: nil)
    }
    
    // MARK: - Analytics
    
    func logViewDropList() {
        FIRAnalytics.logEvent(withName: "viewDropList", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    // MARK: - Firebase
    
    func getPostIDArray() -> [(postType: String, postID: Int)] {
        var firstPosts: [[String:Any]]
        if self.dropList.count > 5 {
            let firstSlice = self.dropList.prefix(5)
            firstPosts = Array(firstSlice)
        } else {
            let firstSlice = self.dropList.prefix(self.dropList.count)
            firstPosts = Array(firstSlice)
        }
        
        var tupleArray: [(postType: String, postID: Int)] = []
        for post in firstPosts {
            let postID = post["postID"] as! Int
            if let _ = post["userHandle"] as? String {
                let tuple = (postType: "pond", postID: postID)
                tupleArray.append(tuple)
            } else {
                let tuple = (postType: "anon", postID: postID)
                tupleArray.append(tuple)
            }
        }
        
        return tupleArray
    }
    
    func observeDropList() {
        self.removeObserverForDropList()
        if !self.dropList.isEmpty {
            self.isRemoved = false
            let firstPosts = self.getPostIDArray()
            self.observedPosts = firstPosts
            let pondRef = self.ref.child("posts")
            let anonRef = self.ref.child("anonPosts")
            
            for post in firstPosts {
                let postID: String = "\(post.postID)"
                
                if post.postType == "pond" {
                    pondRef.child(postID).observe(.value, with: {
                        (snapshot) -> Void in
                        if !self.firstLoadNewObservers {
                            if self.scrollPosition == "top" || self.firstLoad {
                                self.getNewPosts()
                            } else {
                                self.firstLoad = true
                                self.addScrollToTop("New ↑")
                            }
                        }
                    })
                } else {
                    anonRef.child(postID).observe(.value, with: {
                        (snapshot) -> Void in
                        if !self.firstLoadNewObservers {
                            if self.scrollPosition == "top" || self.firstLoad {
                                self.getNewPosts()
                            } else {
                                self.firstLoad = true
                                self.addScrollToTop("New ↑")
                            }
                        }
                    })
                }
            }
        } else {
            self.getDropList()
        }
        
        self.firstLoadNewObservers = false
    }
    
    func removeObserverForDropList() {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        let pondRef = self.ref.child("posts")
        let anonRef = self.ref.child("anonPosts")
        pondRef.removeAllObservers()
        anonRef.removeAllObservers()
        
        if !self.observedPosts.isEmpty {
            for post in self.observedPosts {
                let postID: String = "\(post.postID)"
                
                if post.postType == "pond" {
                    pondRef.child(postID).removeAllObservers()
                } else {
                    anonRef.child(postID).removeAllObservers()
                }
            }
        }
    }
    
    // MARK: - AWS
    
    func getNewPosts() {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        
        if !self.firstLoad {
            self.newPostsCount += 1
        }
        
        if self.newPostsCount == 3 || self.firstLoad {
            self.perform(#selector(self.getDropList), with: nil, afterDelay: 0.1)
        } else {
            self.perform(#selector(self.getDropList), with: nil, afterDelay: 0.5)
        }
    }
    
    func getDropList() {
        self.newPostsCount = 0
        let postID: Int = 0
        let picSize: String = "small"
        let isMine: String = "yes"
        
        var lastPostID: Int
        var pageNumber: Int
        if self.scrollPosition == "bottom" && self.dropList.count >= 42 {
            let lastPost = dropList.last!
            lastPostID = lastPost["postID"] as! Int
            pageNumber = misc.getNextPageNumberNoAd(self.dropList)
            self.displayActivity("loading more posts...", indicator: true)
        } else {
            lastPostID = 0
            pageNumber = 0
        }
        
        let token = misc.generateToken(16, firebaseID: self.myIDFIR)
        let iv = token.first!
        let tokenString = token.last!
        let key = token[1]
        
        do {
            let aes = try AES(key: key, iv: iv)
            let cipherText = try aes.encrypt(tokenString.utf8.map({$0}))
            
            let getURL = URL(string: "https://dotnative.io/getMixedPost")
            var getRequest = URLRequest(url: getURL!)
            getRequest.httpMethod = "POST"
            
            let getString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&postID=\(postID)&lastPostID=\(lastPostID)&pageNumber=\(pageNumber)&isMine=\(isMine)&size=\(picSize)"
            getRequest.httpBody = getString.data(using: String.Encoding.utf8)
            
            let task = URLSession.shared.dataTask(with: getRequest as URLRequest) {
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
                                self.firstLoad = false
                                self.dropListTableView.reloadData()
                                self.displayAlert("Oops", alertMessage: "We've encountered an error and can't load posts. Please report the bug by going to the report section in the menu if this persists.")
                                return
                            }
                            
                            if status == "success" {
                                if let postsArray = parseJSON["posts"] as? [[String:Any]] {
                                    
                                    var posts: [[String:Any]] = []
                                    for individualPost in postsArray {
                                        var postType: String
                                        if let _ = individualPost["userHandle"] as? String {
                                            postType = "pond"
                                        } else {
                                            postType = "anon"
                                        }
                                        
                                        let postID = individualPost["postID"] as! Int
                                        
                                        let userID = individualPost["userID"] as! Int
                                        let userIDFIR = individualPost["firebaseID"] as! String
                                        
                                        var timestamp: String!
                                        let time = individualPost["timestamp"] as! String
                                        let timeEdited = individualPost["timestampEdited"] as! String
                                        if time == timeEdited {
                                            let timeFormatted = self.misc.formatTimestamp(time)
                                            timestamp = timeFormatted
                                        } else {
                                            let timeEditedFormatted = self.misc.formatTimestamp(timeEdited)
                                            timestamp = "edited \(timeEditedFormatted)"
                                        }
                                        
                                        let postContent = individualPost["postContent"] as! String
                                        let pointsCount = individualPost["pointsCount"] as! Int
                                        let didIVote = individualPost["didIVote"] as! String
                                        let replyCount = individualPost["replyCount"] as! Int
                                        let shareCount = individualPost["shareCount"] as! Int
                                        
                                        let long = individualPost["longitude"] as! String
                                        let longitude: Double = Double(long)!
                                        let lat = individualPost["latitude"] as! String
                                        let latitude: Double = Double(lat)!
                                        
                                        let imageKey = individualPost["imageKey"] as! String
                                        let imageBucket = individualPost["imageBucket"] as! String
                                        
                                        if postType == "anon"  {
                                            var post: [String:Any] = ["postID": postID, "userID": userID, "userIDFIR": userIDFIR, "postContent": postContent, "timestamp": timestamp, "replyCount": replyCount, "pointsCount": pointsCount, "didIVote": didIVote, "shareCount": shareCount, "longitude": longitude, "latitude": latitude]
                                            if !imageKey.contains("default") {
                                                let imageURL = URL(string: "https://\(imageBucket).s3.amazonaws.com/\(imageKey)")!
                                                if !self.urlArray.contains(imageURL) {
                                                    self.urlArray.append(imageURL)
                                                }
                                                post["imageURL"] = imageURL
                                            }
                                            if let reply = individualPost["reply"] as? [String:Any] {
                                                let replyContent = reply["postContent"] as! String
                                                let time = reply["timestamp"] as! String
                                                let replyTimestamp = self.misc.formatTimestamp(time)
                                                
                                                let replyDrop: [String:Any] = ["replyContent": replyContent, "replyTimestamp": replyTimestamp]
                                                post["reply"] = replyDrop
                                            }
                                            posts.append(post)
                                            
                                        } else {
                                            let userName = individualPost["userName"] as! String
                                            let userHandle = individualPost["userHandle"] as! String
                                            
                                            let key = individualPost["key"] as! String
                                            let bucket = individualPost["bucket"] as! String
                                            let picURL = URL(string: "https://\(bucket).s3.amazonaws.com/\(key)")!
                                            if !self.urlArray.contains(picURL) {
                                                self.urlArray.append(picURL)
                                            }
                                            
                                            var post: [String:Any] = ["postID": postID, "userID": userID, "userIDFIR": userIDFIR, "userName": userName, "userHandle": userHandle, "postContent": postContent, "timestamp": timestamp, "replyCount": replyCount, "pointsCount": pointsCount, "didIVote": didIVote, "picURL": picURL, "shareCount": shareCount, "longitude": longitude, "latitude": latitude]
                                            if !imageKey.contains("default") {
                                                let imageURL = URL(string: "https://\(imageBucket).s3.amazonaws.com/\(imageKey)")!
                                                if !self.urlArray.contains(imageURL) {
                                                    self.urlArray.append(imageURL)
                                                    SDWebImagePrefetcher.shared().prefetchURLs([imageURL])
                                                }
                                                post["imageURL"] = imageURL
                                            }
                                            if let reply = individualPost["reply"] as? [String:Any] {
                                                let replyID = reply["userID"] as! Int
                                                let replyIDFIR = reply["firebaseID"] as! String
                                                let replyContent = reply["postContent"] as! String
                                                let time = reply["timestamp"] as! String
                                                let replyTimestamp = self.misc.formatTimestamp(time)
                                                let replyHandle = reply["userHandle"] as! String
                                                let replyKey = reply["key"] as! String
                                                let replyBucket = reply["bucket"] as! String
                                                let replyPicURL = URL(string: "https://\(replyBucket).s3.amazonaws.com/\(replyKey)")!
                                                if !self.urlArray.contains(replyPicURL) {
                                                    self.urlArray.append(replyPicURL)
                                                }

                                                let replyDrop: [String:Any] = ["replyID": replyID, "replyIDFIR": replyIDFIR, "replyContent": replyContent, "replyTimestamp": replyTimestamp, "replyHandle": replyHandle, "replyPicURL": replyPicURL]
                                                post["reply"] = replyDrop
                                            }
                                            posts.append(post)
                                        }
                                    }
                                    
                                    if lastPostID != 0 {
                                        let latestPost = posts.last!
                                        if lastPostID != latestPost["postID"] as! Int {
                                            self.dropList.append(contentsOf: posts)
                                            if self.dropList.count > 210 {
                                                let difference = self.dropList.count - 210
                                                let indicesToRemove = 0...(difference-1)
                                                self.dropList = self.dropList.enumerated().filter{!indicesToRemove.contains($0.offset)}.map{$0.element}
                                            }
                                        }
                                    } else {
                                        self.dropList = posts
                                    }
                                    
                                    if !posts.isEmpty {
                                        var firstRows = 8
                                        let maxCount = posts.count
                                        if firstRows >= (maxCount - 1) {
                                            firstRows = maxCount - 1
                                        }
                                        
                                        var urlsToPrefetch: [URL] = []
                                        for index in 0...firstRows {
                                            let post = posts[index]
                                            if let picURL = post["picURL"] as? URL {
                                                urlsToPrefetch.append(picURL)
                                            }
                                            if let replyPicURL = post["replyPicURL"] as? URL {
                                                urlsToPrefetch.append(replyPicURL)
                                            }
                                        }
                                        
                                        SDWebImagePrefetcher.shared().prefetchURLs(urlsToPrefetch, progress: nil, completed: { (completed, skipped) in
                                            self.firstLoad = false
                                            self.dropListTableView.reloadData()
                                        })
                                    } else {
                                        self.firstLoad = false
                                        self.dropListTableView.reloadData()
                                    }
                                } else {
                                    self.firstLoad = false
                                    self.dropListTableView.reloadData()
                                } // parse dict
                                
                            } // success
                        }) // main
                    }
                    
                } catch {
                    self.displayAlert("Oops", alertMessage: "We're updating our servers right now. Please try again later.")
                    print(error)
                    return
                }
            }
            
            task.resume()
            
        } catch {
            self.displayAlert("Token Error", alertMessage: "We messed up. Please report the bug by going to the report section in the menu if this persists.")
            return
        }
    }
    
    func refreshWithDelay() {
        if self.scrollPosition == "top" {
            self.perform(#selector(self.observeDropList), with: nil, afterDelay: 0.1)
        } else {
            self.perform(#selector(self.getDropList), with: nil, afterDelay: 0.5)
        }
    }
    
}
