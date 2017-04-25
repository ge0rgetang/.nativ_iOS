//
//  FriendListViewController.swift
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
import FBSDKShareKit
import GoogleSignIn
import FirebaseInvites
import SideMenu
import MIBadgeButton_Swift

class FriendListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, UISearchResultsUpdating, GIDSignInUIDelegate, FIRInviteDelegate {

    // MARK: - Outlets/Variables
    
    var myID: Int = 0
    var myIDFIR: String = "0000000000000000000000000000"
    
    var userIDToPass: Int = -2
    var userIDFIRToPass: String = "-2"
    var userHandleToPass: String = ".chat"
    var picURLToPass: URL!
    var segueSender: String = "profile"
    var firstLoad: Bool = true
    var firstLoadSearch: Bool = true
    var scrollPosition: String = "top"
    var newUpdatesCount: Int = 0
    var friendStatusToPass: String = "Z"
    var chatIDToPass: String = "-2"
    var parentRow: Int = -2
    var parentSection: Int = -2
    var isRemoved: Bool = false
    var lastContentOffset: CGFloat = 0
    
    var searchController: UISearchController!
    
    var urlArray: [URL] = []
    var firstUserID: Int = 0
    var heightAtIndexPath: [IndexPath:CGFloat] = [:]
    var addedMe: [[String:Any]] = []
    var chats: [[String:Any]] = []
    var friendsAddedTo: [[String:Any]] = []
    
    var userSearchResults:[[String:Any]] = []
    
    var ref = FIRDatabase.database().reference().child("users")
    
    let misc = Misc()
    var activityView = UIView()
    var activityIndicator = UIActivityIndicatorView()
    var activityLabel = UILabel()
    var scrollToTopButton = UIButton()
    var badgeButton = MIBadgeButton()
    var badgeBarButton = UIBarButtonItem()
    var dimView = UIView()

    @IBOutlet weak var friendListTableView: UITableView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    
    @IBAction func unwindToFriendList(_ segue: UIStoryboardSegue){}
    
    // MARK - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = "Chats/Friends"
        
        self.friendListTableView.delegate = self
        self.friendListTableView.dataSource = self
        self.friendListTableView.rowHeight = UITableViewAutomaticDimension
        self.friendListTableView.separatorStyle = UITableViewCellSeparatorStyle.none
        self.friendListTableView.backgroundColor = misc.softGrayColor
        self.friendListTableView.showsVerticalScrollIndicator = false
        
        self.segmentedControl.selectedSegmentIndex = 0
        self.segmentedControl.addTarget(self, action: #selector(self.sortCriteriaDidChange), for: .valueChanged)
        
        let swipeRight: UISwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(self.swipeRight))
        swipeRight.direction = .right
        self.friendListTableView.addGestureRecognizer(swipeRight)
        
        let swipeLeft: UISwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(self.swipeLeft))
        swipeLeft.direction = .left
        self.friendListTableView.addGestureRecognizer(swipeLeft)
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(self.handleRefreshControl), for: .valueChanged)
        self.friendListTableView.addSubview(refreshControl)
        
        self.searchController = UISearchController(searchResultsController: nil)
        self.searchController.searchBar.delegate = self
        self.searchController.searchBar.keyboardType = .asciiCapable
        self.searchController.searchResultsUpdater = self
        self.searchController.dimsBackgroundDuringPresentation = false
        self.definesPresentationContext = true
        self.searchController.searchBar.sizeToFit()
        self.searchController.hidesNavigationBarDuringPresentation = false
        self.searchController.searchBar.placeholder = "Search for friends/handle/email"
        self.searchController.searchBar.inputView?.tintColor = misc.nativColor
        self.navigationItem.titleView = self.searchController.searchBar
        
        self.setSideMenu()
        self.setMenuBarButton()
        self.setRetainedNotifications()
        
        self.dimView.isUserInteractionEnabled = false
        self.dimView.backgroundColor = .black
        self.dimView.alpha = 0
        self.dimView.frame = CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: self.view.frame.size.height)
        self.friendListTableView.addSubview(self.dimView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.segueSender = "profile"
        self.firstLoad = true
        self.setNotifications()
        self.navigationController?.navigationBar.isHidden = false
        
        let myInfo = misc.setMyID()
        self.myID = myInfo[1] as! Int
        self.myIDFIR = myInfo[2] as! String
        
        if self.myID <= 0  || self.myIDFIR == "0000000000000000000000000000" {
            self.searchController.searchBar.isUserInteractionEnabled = false
            self.searchController.searchBar.placeholder = "must login to search"
            self.clearArrays()
            NotificationCenter.default.post(name: Notification.Name(rawValue: "signedOut"), object: nil)
            
        } else {
            self.searchController.searchBar.placeholder = "Search for friends/handle/email"
            self.searchController.searchBar.isUserInteractionEnabled = true
            self.logViewFriendList()
            self.writeInFriendList(true)
        }
        
        if let section = UserDefaults.standard.string(forKey: "friendList.nativ") {
            if section == "chat" {
                self.segmentedControl.selectedSegmentIndex = 0
            } else if section == "friends" {
                self.segmentedControl.selectedSegmentIndex = 1
            } else {
                self.segmentedControl.selectedSegmentIndex = 2
            }
            UserDefaults.standard.removeObject(forKey: "friendList.nativ")
            UserDefaults.standard.synchronize() 
        }
        
        self.resetFriendBadge(self.segmentedControl.selectedSegmentIndex)
        misc.setSideMenuIndex(2)
        self.updateBadge()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if !self.searchController.isActive {
            self.observeFriendList()
            self.hideSegementedControl(false)
        } else {
            self.hideSegementedControl(true)
        }
        self.friendListTableView.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.removeNotifications()
        self.removeObserverForFriendList()
        if self.myID > 0 {
            self.writeInFriendList(false)
        }
        if self.urlArray.count >= 210 {
            self.clearArrays()
        }
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        self.removeObserverForFriendList()
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        self.clearArrays()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        self.firstLoad = true
        self.firstLoadSearch = true
        self.clearArrays()
        misc.clearWebImageCache()
    }
    
    // MARK: - TableView
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.myID <= 0  || self.myIDFIR == "0000000000000000000000000000" {
            return 1
        }
        
        if self.searchController.isActive {
            if self.userSearchResults.isEmpty {
                return 1
            }
            return self.userSearchResults.count
            
        } else {
            let segmentIndex = self.segmentedControl.selectedSegmentIndex
            switch segmentIndex {
            case 0:
                if self.chats.isEmpty {
                    return 1
                }
                return self.chats.count
            case 1:
                if self.friendsAddedTo.isEmpty {
                    return 1
                }
                return self.friendsAddedTo.count
            case 2:
                if self.addedMe.isEmpty {
                    return 1
                }
                return self.addedMe.count
            default:
                return 1
            }
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if self.myID <= 0 || self.myIDFIR == "0000000000000000000000000000" {
            let cell = tableView.dequeueReusableCell(withIdentifier: "noFriendsCell", for: indexPath) as! NoContentTableViewCell
            cell.noContentLabel.text = "This is your friends list. You can search for or add friends here. You can also chat with them or view their profiles. Please login/sign up by clicking on the menu button in the top left."
            cell.whiteView.backgroundColor = UIColor.white
            cell.whiteView.layer.masksToBounds = false
            cell.whiteView.layer.cornerRadius = 2.5
            cell.whiteView.layer.shadowOffset = CGSize(width: -1, height: 1)
            cell.whiteView.layer.shadowOpacity = 0.42
            cell.whiteView.sizeToFit()
            cell.noContentLabel.numberOfLines = 0
            cell.noContentLabel.textColor = .lightGray
            return cell
        }
        
        if self.searchController.isActive {
            if self.userSearchResults.isEmpty {
                let cell = tableView.dequeueReusableCell(withIdentifier: "noFriendsCell", for: indexPath) as! NoContentTableViewCell
                cell.noContentLabel.numberOfLines = 0
                cell.noContentLabel.textColor = .lightGray
                if self.firstLoadSearch {
                    cell.noContentLabel.text = "tap search..."
                } else {
                    cell.noContentLabel.text = "Sorry, no results found :("
                }
                cell.whiteView.backgroundColor = UIColor.white
                cell.whiteView.layer.masksToBounds = false
                cell.whiteView.layer.cornerRadius = 2.5
                cell.whiteView.layer.shadowOffset = CGSize(width: -1, height: 1)
                cell.whiteView.layer.shadowOpacity = 0.42
                cell.whiteView.sizeToFit()
                
                return cell
            }
            
            let individualUser = self.userSearchResults[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "userListCell", for: indexPath) as! UserListTableViewCell
            cell.userNameLabel.text = individualUser["userName"] as? String
            let userHandle = individualUser["userHandle"] as! String
            cell.userHandleLabel.text = "@\(userHandle)"
            let picURL = individualUser["picURL"] as! URL
            cell.userPicImageView.layer.cornerRadius = cell.userPicImageView.frame.size.width/2
            cell.userPicImageView.clipsToBounds = true
            cell.userPicImageView.sd_setImage(with: picURL)
            
            cell.whiteView.backgroundColor = UIColor.white
            cell.whiteView.layer.masksToBounds = false
            cell.whiteView.layer.cornerRadius = 2.5
            cell.whiteView.layer.shadowOffset = CGSize(width: -1, height: 1)
            cell.whiteView.layer.shadowOpacity = 0.42
            cell.whiteView.sizeToFit()
            
            return cell
            
        } else {
            let segmentIndex = self.segmentedControl.selectedSegmentIndex
            
            if (segmentIndex == 0 && self.chats.isEmpty) || (segmentIndex == 1 && self.friendsAddedTo.isEmpty) || (segmentIndex == 2 && self.addedMe.isEmpty) {
                let cell = tableView.dequeueReusableCell(withIdentifier: "noFriendsCell", for: indexPath) as! NoContentTableViewCell
                cell.noContentLabel.numberOfLines = 0
                cell.noContentLabel.textColor = .lightGray
                cell.whiteView.backgroundColor = UIColor.white
                cell.whiteView.layer.masksToBounds = false
                cell.whiteView.layer.cornerRadius = 2.5
                cell.whiteView.layer.shadowOffset = CGSize(width: -1, height: 1)
                cell.whiteView.layer.shadowOpacity = 0.42
                cell.whiteView.sizeToFit()
                switch segmentIndex {
                case 0:
                    if self.firstLoad {
                        cell.noContentLabel.text = "loading your chats..."
                    } else {
                        cell.noContentLabel.text = "No chats yet. To chat with someone, you need to add them and they need to add you. You can search for people using the top bar."
                    }
                case 1:
                    if self.firstLoad {
                        cell.noContentLabel.text = "loading people you've added to your Flow and friends..."
                    } else {
                        cell.noContentLabel.text = "No friends or anyone added yet. You can add people to your Flow by using the search in the top bar. Once you've added them, public posts they make will show up in the friend Flow. If they also add you, your public posts will show up in their Flow and you'll become friends. Tap here to invite Facebook and Google friends!"
                    }
                case 2:
                    if self.firstLoad {
                        cell.noContentLabel.text = "loading people that've added you..."
                    } else {
                        cell.noContentLabel.text = "No one has added you to their Flow yet. People who add you to their Flow will show up here. Think of them as your audience. Public posts you drop will show up in their Flow. If you add them back, you become friends."
                    }
                default:
                    cell.noContentLabel.text = "error, no segement selected"
                }
                return cell
                
            }
            
            switch segmentIndex {
            case 0:
                let individualUser = self.chats[indexPath.row]
                let cell = tableView.dequeueReusableCell(withIdentifier: "friendChatCell", for: indexPath) as! UserListTableViewCell
                
                let userHandle = individualUser["userHandle"] as! String
                cell.userHandleLabel.text = "@\(userHandle)"
                let picURL = individualUser["picURL"] as! URL
                cell.userPicImageView.layer.cornerRadius = cell.userPicImageView.frame.size.width/2
                cell.userPicImageView.clipsToBounds = true
                cell.userPicImageView.sd_setImage(with: picURL)
                let tapPicToViewUser = UITapGestureRecognizer(target: self, action: #selector(self.presentUserProfile))
                cell.userPicImageView.addGestureRecognizer(tapPicToViewUser)
                
                cell.userMessageLabel.numberOfLines = 0
                cell.userMessageLabel.text = individualUser["lastChat"] as? String
                let senderID = individualUser["senderID"] as! Int
                if self.myID == senderID {
                    cell.userMessageLabel.textColor = .lightGray
                } else {
                    cell.userMessageLabel.textColor = .black
                }
                
                cell.whiteView.backgroundColor = UIColor.white
                cell.whiteView.layer.masksToBounds = false
                cell.whiteView.layer.cornerRadius = 2.5
                cell.whiteView.layer.shadowOffset = CGSize(width: -1, height: 1)
                cell.whiteView.layer.shadowOpacity = 0.42
                cell.whiteView.sizeToFit()
                
                let userID = individualUser["userID"] as! Int
                if self.firstUserID != userID {
                    cell.whiteView.alpha = 0
                    UIView.animate(withDuration: 0.1, animations: {
                        cell.whiteView.alpha = 1
                    })
                    self.firstUserID = userID
                }
                
                return cell
                
            case 1:
                let individualUser = self.friendsAddedTo[indexPath.row]
                let cell = tableView.dequeueReusableCell(withIdentifier: "addedMeCell", for: indexPath) as! UserListTableViewCell
                
                cell.userNameLabel.text = individualUser["userName"] as? String
                let userHandle = individualUser["userHandle"] as! String
                cell.userHandleLabel.text = "@\(userHandle)"
                let picURL = individualUser["picURL"] as! URL
                cell.userPicImageView.layer.cornerRadius = cell.userPicImageView.frame.size.width/2
                cell.userPicImageView.clipsToBounds = true
                cell.userPicImageView.sd_setImage(with: picURL)
                let tapPicToViewUser = UITapGestureRecognizer(target: self, action: #selector(self.presentUserProfile))
                cell.userPicImageView.addGestureRecognizer(tapPicToViewUser)
                
                let isFriend = individualUser["isFriend"] as! String
                if isFriend == "F" {
                    cell.addButton.setImage(UIImage(named: "acceptedSelected"), for: .normal)
                } else {
                    cell.addButton.setImage(UIImage(named: "addFriendSelected"), for: .normal)
                }
                cell.addLabel.text = ""
                
                cell.whiteView.backgroundColor = UIColor.white
                cell.whiteView.layer.masksToBounds = false
                cell.whiteView.layer.cornerRadius = 2.5
                cell.whiteView.layer.shadowOffset = CGSize(width: -1, height: 1)
                cell.whiteView.layer.shadowOpacity = 0.42
                cell.whiteView.sizeToFit()
                
                return cell
                
            default:
                let individualUser = self.addedMe[indexPath.row]
                let cell = tableView.dequeueReusableCell(withIdentifier: "addedMeCell", for: indexPath) as! UserListTableViewCell
                
                cell.userNameLabel.text = individualUser["userName"] as? String
                let userHandle = individualUser["userHandle"] as! String
                cell.userHandleLabel.text = "@\(userHandle)"
                let picURL = individualUser["picURL"] as! URL
                cell.userPicImageView.layer.cornerRadius = cell.userPicImageView.frame.size.width/2
                cell.userPicImageView.clipsToBounds = true
                cell.userPicImageView.sd_setImage(with: picURL)
                let tapPicToViewUser = UITapGestureRecognizer(target: self, action: #selector(self.presentUserProfile))
                cell.userPicImageView.addGestureRecognizer(tapPicToViewUser)
                
                cell.addButton.setImage(UIImage(named: "addFriendUnselected"), for: .normal)
                cell.addButton.setImage(UIImage(named: "addFriendSelected"), for: .selected)
                cell.addButton.addTarget(self, action: #selector(self.addToFlow), for: .touchUpInside)
                cell.addLabel.text = "" 
                
                cell.whiteView.backgroundColor = UIColor.white
                cell.whiteView.layer.masksToBounds = false
                cell.whiteView.layer.cornerRadius = 2.5
                cell.whiteView.layer.shadowOffset = CGSize(width: -1, height: 1)
                cell.whiteView.layer.shadowOpacity = 0.42
                cell.whiteView.sizeToFit()
                
                return cell
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
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let cell = tableView.dequeueReusableCell(withIdentifier: "friendListHeaderCell") as! HeaderTableViewCell
        
        if self.searchController.isActive {
            cell.headerLabel.text = "Search Results"
            cell.headerLabel.textAlignment = .center
            cell.headerLabel.sizeToFit()
            return cell
            
        } else {
            let segmentIndex = self.segmentedControl.selectedSegmentIndex
            if segmentIndex == 0 {
                cell.headerLabel.text = "Chats"
                cell.headerLabel.textAlignment = .center
                cell.headerLabel.sizeToFit()
                return cell
            }
            if segmentIndex == 1 {
                cell.headerLabel.text = "Friends/Added"
                cell.headerLabel.textAlignment = .center
                cell.headerLabel.sizeToFit()
                return cell
            }
            if segmentIndex == 2 {
                cell.headerLabel.text = "Added Me"
                cell.headerLabel.textAlignment = .center
                cell.headerLabel.sizeToFit()
                return cell
            }
        }
        
        return nil
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 34
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if self.myID > 0 && self.myIDFIR != "0000000000000000000000000000" {
            self.parentSection = indexPath.section
            self.parentRow = indexPath.row
            let segmentIndex = self.segmentedControl.selectedSegmentIndex
            
            if (((segmentIndex == 0 && !self.chats.isEmpty) || (segmentIndex == 1 && !friendsAddedTo.isEmpty) || (segmentIndex == 2 && !self.addedMe.isEmpty)) && !self.searchController.isActive) || (self.searchController.isActive && !self.userSearchResults.isEmpty) {
                let cell = self.friendListTableView.cellForRow(at: indexPath) as! UserListTableViewCell
                var individualUser: [String:Any]
                if self.searchController.isActive {
                    self.segueSender = "profile"
                    individualUser = self.userSearchResults[indexPath.row]
                } else {
                    if segmentIndex == 0 {
                        individualUser = self.chats[indexPath.row]
                        self.segueSender = "chat"
                    } else if segmentIndex == 1 {
                        individualUser = self.friendsAddedTo[indexPath.row]
                        self.segueSender = "profile"
                    } else {
                        individualUser = self.addedMe[indexPath.row]
                        self.segueSender = "profile"
                    }
                }
                
                let userID = individualUser["userID"] as! Int
                self.userIDToPass = userID
                self.userIDFIRToPass = individualUser["userIDFIR"] as! String
                let userHandle = individualUser["userHandle"] as! String
                self.userHandleToPass = "@\(userHandle)"
                let isFriend = individualUser["isFriend"] as! String
                self.friendStatusToPass = isFriend
                self.chatIDToPass = misc.setChatID(self.myID, userID: userID)
                self.picURLToPass = individualUser["picURL"] as! URL
                if self.friendStatusToPass != "Z" {
                    cell.whiteView.backgroundColor = misc.nativFade
                    self.performSegue(withIdentifier: "fromFriendListToUserPage", sender: self)
                } else {
                    self.displayAlert("Oops", alertMessage: "We messed up. Please try again later.")
                    return
                }
            }
            
            if (!self.searchController.isActive && self.friendsAddedTo.isEmpty && segmentIndex == 1 && indexPath.row == 0) {
                let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
                
                let fbAction = UIAlertAction(title: "Invite Facebook Friends", style: .default, handler: { action in
                    self.inviteThroughFB()
                })
                alertController.addAction(fbAction)
                
                let googleAction = UIAlertAction(title: "Sign in/Invite with Google", style: .default, handler: { action in
                    self.inviteThroughGoogle()
                })
                alertController.addAction(googleAction)
                
                alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                alertController.view.tintColor = misc.nativColor
                DispatchQueue.main.async(execute: { self.present(alertController, animated: true, completion: nil) })
            }
        }
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "fromFriendListToUserPage" {
            if let userProfileContainerViewController = segue.destination as? UserProfileContainerViewController {
                userProfileContainerViewController.userIDToPass = self.userIDToPass
                userProfileContainerViewController.userIDFIRToPass = self.userIDFIRToPass
                userProfileContainerViewController.userHandleToPass = self.userHandleToPass
                userProfileContainerViewController.friendStatusToPass = self.friendStatusToPass
                userProfileContainerViewController.chatIDToPass = self.chatIDToPass
                userProfileContainerViewController.picURLToPass = self.picURLToPass
                userProfileContainerViewController.segueSender = self.segueSender
            }
        }
    }
    
    func presentUserProfile(_ sender: UITapGestureRecognizer) {
        let position = sender.location(in: self.friendListTableView)
        let indexPath: IndexPath! = self.friendListTableView.indexPathForRow(at: position)
        let segmentIndex = self.segmentedControl.selectedSegmentIndex

        if (((segmentIndex == 0 && !self.chats.isEmpty) || (segmentIndex == 1 && !self.friendsAddedTo.isEmpty) || (segmentIndex == 2 && !self.addedMe.isEmpty)) && !self.searchController.isActive) || (self.searchController.isActive && !self.userSearchResults.isEmpty) {
            var individualUser: [String:Any]
            if self.searchController.isActive {
                individualUser = self.userSearchResults[indexPath.row]
            } else {
                if segmentIndex == 0 {
                    individualUser = self.chats[indexPath.row]
                } else if segmentIndex == 1 {
                    individualUser = self.friendsAddedTo[indexPath.row]
                } else {
                    individualUser = self.addedMe[indexPath.row]
                }
            }
            
            self.segueSender = "profile"
            let userID = individualUser["userID"] as! Int
            self.userIDToPass = userID
            self.userIDFIRToPass = individualUser["userIDFIR"] as! String
            let userHandle = individualUser["userHandle"] as! String
            self.userHandleToPass = "@\(userHandle)"
            let isFriend = individualUser["isFriend"] as! String
            self.friendStatusToPass = isFriend
            self.chatIDToPass = misc.setChatID(self.myID, userID: userID)
            if self.friendStatusToPass != "Z" {
                self.performSegue(withIdentifier: "fromFriendListToUserPage", sender: self)
            } else {
                self.displayAlert("Oops", alertMessage: "We messed up. Please try again later.")
                return
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
    
    func setFirstLoad() {
        self.firstLoad = true
    }
    
    func setIsFriendN() {
        if self.searchController.isActive {
            if self.parentRow >= 0 {
                self.userSearchResults[self.parentRow]["isFriend"] = "N"
            }
        }
    }
    
    // MARK: - SearchController
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        self.removeObserverForFriendList()
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        self.firstLoadSearch = true
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.searchController.searchBar.text = ""
        self.searchController.resignFirstResponder()
        DispatchQueue.main.async(execute: {
            self.firstLoad = true
            self.observeFriendList()
            self.hideSegementedControl(false)
            self.friendListTableView.reloadData()
        })
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        if self.searchController.searchBar.text != "" {
            self.hideSegementedControl(true)
            self.searchFriend()
            _ = Timer.scheduledTimer(timeInterval: 0.075, target: self, selector: #selector(self.scrollToTop), userInfo: nil, repeats: false)
        } else {
            self.displayAlert("Oops", alertMessage: "Please type in something to search")
            return
        }
    }
    
    func setSearchActiveOff() {
        self.searchController.isActive = false
        self.dimBackground(false)
    }
    
    // MARK: - Sort Options
    
    func sortCriteriaDidChange(_ sender: UISegmentedControl) {
        self.firstLoad = true
        self.searchController.searchBar.text = ""
        self.searchController.resignFirstResponder()
        
        self.scrollToTop()
        _ = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.scrollToTop), userInfo: nil, repeats: false)
        
        switch sender.selectedSegmentIndex {
        case 0:
            self.observeFriendList()
            self.logViewChats()
        case 1:
            self.getFriendList()
            self.logViewAdded()
        case 2:
            self.getFriendList()
            self.logViewAddedMe()
        default:
            return
        }
        
        self.resetFriendBadge(sender.selectedSegmentIndex)
        self.friendListTableView.reloadData()
    }
    
    func swipeLeft() {
        if !self.searchController.isActive {
            let currentIndex = self.segmentedControl.selectedSegmentIndex
            if currentIndex >= 0 && currentIndex < 2 {
                self.firstLoad = true
                
                self.scrollToTop()
                _ = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.scrollToTop), userInfo: nil, repeats: false)
                
                switch currentIndex {
                case 0:
                    self.segmentedControl.selectedSegmentIndex = 1
                    self.getFriendList()
                    self.logViewAdded()
                    self.resetFriendBadge(1)
                case 1:
                    self.segmentedControl.selectedSegmentIndex = 2
                    self.getFriendList()
                    self.logViewAddedMe()
                    self.resetFriendBadge(2)
                default:
                    return
                }
                
                self.friendListTableView.reloadData()
            }
        }
    }
    
    func swipeRight() {
        if !self.searchController.isActive {
            let currentIndex = self.segmentedControl.selectedSegmentIndex
            if currentIndex <= 2 && currentIndex > 0 {
                self.firstLoad = true
                
                self.scrollToTop()
                _ = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.scrollToTop), userInfo: nil, repeats: false)
                
                switch currentIndex {
                case 2:
                    self.segmentedControl.selectedSegmentIndex = 1
                    self.getFriendList()
                    self.logViewAddedMe()
                    self.resetFriendBadge(1)
                case 1:
                    self.segmentedControl.selectedSegmentIndex = 0
                    self.observeFriendList()
                    self.logViewChats()
                    self.resetFriendBadge(0)
                default:
                    return
                }
                
                self.friendListTableView.reloadData()
            }
        }
    }

    // MARK: - ScrollView
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !self.isRemoved {
            self.removeObserverForFriendList()
            self.isRemoved = true
        }
        
        let offset = scrollView.contentOffset.y
        let frameHeight = scrollView.frame.size.height
        let contentHeight = scrollView.contentSize.height
        
        if offset <= 420 {
            self.scrollToTopButton.removeFromSuperview()
        }
        
        var users: [[String:Any]] = []
        if self.searchController.isActive {
            users = self.userSearchResults
        } else {
            let segmentIndex = self.segmentedControl.selectedSegmentIndex
            switch segmentIndex {
            case 0:
                users = self.chats
            case 1:
                users = self.friendsAddedTo
            case 2:
                users = self.addedMe
            default:
                return
            }
        }
        
        if offset == 0 {
            self.scrollPosition = "top"
            if !self.searchController.isActive {
                self.observeFriendList()
            }
        } else if offset == (contentHeight - frameHeight) {
            self.scrollPosition = "bottom"
            if users.count >= 42 && !self.searchController.isActive {
                self.getFriendList()
            }
            if self.userSearchResults.count >= 42 && self.searchController.isActive {
                self.searchFriend()
            }
        } else {
            self.scrollPosition = "middle"
        }
        
        // prefetch images on scroll down
        if !users.isEmpty {
            if self.lastContentOffset < scrollView.contentOffset.y {
                let visibleCells = self.friendListTableView.visibleCells
                if let lastCell = visibleCells.last {
                    let lastIndexPath = self.friendListTableView.indexPath(for: lastCell)
                    let lastRow = lastIndexPath!.row
                    var nextLastRow = lastRow + 10
                    
                    let maxCount = users.count
                    if nextLastRow > (maxCount - 1) {
                        nextLastRow = maxCount - 1
                    }
                    
                    if nextLastRow <= lastRow {
                        nextLastRow = lastRow
                    }
                    
                    var urlsToPrefetch: [URL] = []
                    for index in lastRow...nextLastRow {
                        let user = users[index]
                        if let picURL = user["picURL"] as? URL {
                            urlsToPrefetch.append(picURL)
                        }
                    }
                    SDWebImagePrefetcher.shared().prefetchURLs(urlsToPrefetch)
                }
            }
        }
        self.lastContentOffset = scrollView.contentOffset.y
    }
    
    // MARK: - Keyboard
    
    func keyboardWillShow(_ notification: Notification) {
        self.dimBackground(true)
    }
    
    func keyboardWillHide(_ notification: Notification) {
        self.dimBackground(false)
    }
    
    // MARK: - Notifications
    
    func setSegementedBadgeTitle() {
        let chatBadge = UserDefaults.standard.integer(forKey: "badgeNumberChat.nativ")
        let acceptedBadge = UserDefaults.standard.integer(forKey: "badgeNumberAccepted.nativ")
        let addedMeBadge = UserDefaults.standard.integer(forKey: "badgeNumberAddedMe.nativ")
        
        if chatBadge > 0 {
            let num = misc.setCount(chatBadge)
            self.segmentedControl.setTitle("Chats (\(num))", forSegmentAt: 0)
        } else {
            self.segmentedControl.setTitle("Chats", forSegmentAt: 0)
        }
        
        if acceptedBadge > 0 {
            let num = misc.setCount(acceptedBadge)
            self.segmentedControl.setTitle("Friends (\(num))", forSegmentAt: 1)
        } else {
            self.segmentedControl.setTitle("Friends", forSegmentAt: 1)
        }
        
        if addedMeBadge > 0 {
            let num = misc.setCount(addedMeBadge)
            self.segmentedControl.setTitle("Added Me (\(num))", forSegmentAt: 2)
        } else {
            self.segmentedControl.setTitle("Added Me", forSegmentAt: 2)
        }
    }
    
    func resetFriendBadge(_ index: Int) {
        let chatBadge = UserDefaults.standard.integer(forKey: "badgeNumberChat.nativ")
        let acceptedBadge = UserDefaults.standard.integer(forKey: "badgeNumberAccepted.nativ")
        let addedMeBadge = UserDefaults.standard.integer(forKey: "badgeNumberAddedMe.nativ")
        
        switch index {
        case 0:
            if chatBadge > 0 {
                misc.resetBadgeForKey("badgeNumberChat.nativ")
                misc.clearNotifications("chat")
            }
        case 1:
            if acceptedBadge > 0 {
                misc.resetBadgeForKey("badgeNumberAccepted.nativ")
                misc.clearNotifications("accepted")
            }
        case 2:
            if addedMeBadge > 0 {
                misc.resetBadgeForKey("badgeNumberAddedMe.nativ")
                misc.clearNotifications("friendRequest")
            }
        default:
            return
        }
        
        self.setSegementedBadgeTitle()
    }
    
    func updateBadge() {
        let badge = UserDefaults.standard.integer(forKey: "badgeNumber.native")
        if badge > 0 {
            self.badgeButton.badgeString = "\(badge)"
        } else {
            self.badgeButton.badgeString = nil
        }
    }
    
    func setRetainedNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.setFirstLoad), name: NSNotification.Name(rawValue: "setFirstLoadFriendList"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.setIsFriendN), name: NSNotification.Name(rawValue: "setIsFriendN"), object: nil)
    }
    
    func setNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.setSearchActiveOff), name: NSNotification.Name(rawValue: "setSearchActiveOff"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshWithDelay), name: NSNotification.Name(rawValue: "addFirebaseObservers"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.scrollToTop), name: NSNotification.Name(rawValue: "scrollToTop"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.removeObserverForFriendList), name: NSNotification.Name(rawValue: "removeFirebaseObservers"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateBadge), name: NSNotification.Name(rawValue: "didReceiveNotification"), object: nil)
    }
    
    func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "setSearchActiveOff"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "addFirebaseObservers"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "scrollToTop"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "removeFirebaseObservers"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "didReceiveNotification"), object: nil)
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
        self.scrollToTopButton = UIButton(frame: CGRect(x: self.view.frame.midX - 27.5, y: self.friendListTableView.frame.origin.y + 8, width: 55, height: 30))
        self.scrollToTopButton.layer.backgroundColor = UIColor(white: 0, alpha: 0.025).cgColor
        self.scrollToTopButton.addTarget(self, action: #selector(self.scrollToTop), for: .touchUpInside)
        self.scrollToTopButton.addTarget(self, action: #selector(colorTopButtonUp), for: .touchUpInside)
        self.scrollToTopButton.addTarget(self, action: #selector(self.colorTopButtonDown), for: .touchDown)
        misc.makeTopButtonFancy(self.scrollToTopButton, title: title)
        self.view.addSubview(self.scrollToTopButton)
    }
    
    func scrollToTop() {
        self.lastContentOffset = 0
        if !self.searchController.isActive {
            self.friendListTableView.setContentOffset(.zero, animated: false)
        }
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
    
    func dimBackground(_ bool: Bool) {
        if bool {
            self.dimView.alpha = 0.25
        } else {
            self.dimView.alpha = 0
        }
    }
    
    func hideSegementedControl(_ bool: Bool) {
        if bool {
            self.bottomConstraint.constant = -30
        } else {
            self.bottomConstraint.constant = 0
        }
    }
    
    func clearArrays() {
        self.urlArray = []
        self.heightAtIndexPath = [:]
        self.userSearchResults = []
        self.chats = []
        self.friendsAddedTo = []
        self.addedMe = []
    }
    
    func handleRefreshControl(refreshControl: UIRefreshControl) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            refreshControl.endRefreshing()
        })
        
        if self.searchController.isActive && self.searchController.searchBar.text != "" {
            self.searchFriend()
        } else {
            if !self.searchController.isActive {
                NSObject.cancelPreviousPerformRequests(withTarget: self)
                self.getFriendList()
            }
        }
    }
    
    // MARK: - Analytics
    
    func logViewFriendList() {
        switch self.segmentedControl.selectedSegmentIndex {
        case 0:
            self.logViewChats()
        case 1:
            self.logViewAdded()
        default:
            self.logViewAddedMe()
        }
    }
    
    func logViewChats() {
        FIRAnalytics.logEvent(withName: "viewChatList", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    func logViewAdded() {
        FIRAnalytics.logEvent(withName: "viewAdded", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    func logViewAddedMe() {
        FIRAnalytics.logEvent(withName: "viewAddedMe", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    func logSearchingForFriend() {
        FIRAnalytics.logEvent(withName: "searchingForFriend", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    func logFBTapped() {
        FIRAnalytics.logEvent(withName: "fbInviteTapped", parameters: [
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
    
    // MARK: - Firebase
    
    func observeFriendList() {
        self.removeObserverForFriendList()
        
        let friendsRef = self.ref.child(self.myIDFIR).child("friendList")
        let chatRef = friendsRef.child("lastMessage")
        
        if self.segmentedControl.selectedSegmentIndex == 0 {
            chatRef.observe(.value, with: { (snapshot) -> Void in
                if self.scrollPosition == "top" || self.firstLoad {
                    self.getNewUpdates()
                } else {
                    self.firstLoad = true
                    self.addScrollToTop("New ↑")
                }
            })
        }
    }
    
    func removeObserverForFriendList() {
        let friendsRef = self.ref.child(self.myIDFIR).child("friendList")
        let chatRef = friendsRef.child("lastMessage")

        friendsRef.removeAllObservers()
        chatRef.removeAllObservers()
    }
    
    func writeInFriendList(_ bool: Bool) {
        self.ref.child(self.myIDFIR).child("inFriendList").setValue(bool)
        UserDefaults.standard.set(bool, forKey: "inFriendList.nativ")
        UserDefaults.standard.synchronize()
    }
    
    func writeAcceptAction(_ userIDFIR: String) {
        self.ref.child(userIDFIR).child("friendList").child("added").child(myIDFIR).removeValue()
        self.ref.child(self.myIDFIR).child("friendList").child("addedMe").child(userIDFIR).removeValue()
        
        self.ref.child(self.myIDFIR).child("friendList").child("friends").child(userIDFIR).setValue(true)
        self.ref.child(userIDFIR).child("friendList").child("friends").child(self.myIDFIR).setValue(true)
    }

    
    // MARK: - AWS
    
    func getNewUpdates() {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        
        if !self.firstLoad {
            self.newUpdatesCount += 1
        }
        
        if self.newUpdatesCount == 3 || self.firstLoad {
            self.perform(#selector(self.getFriendList), with: nil, afterDelay: 0.1)
        } else {
            self.perform(#selector(self.getFriendList), with: nil, afterDelay: 0.25)
        }
    }
    
    func appendResults(_ array: [[String:Any]], cellType: String) -> [[String:Any]] {
        
        var users: [[String:Any]] = []
        
        for individualUser in array {
            let userHandle = individualUser["userHandle"] as! String
            let userIDFIR = individualUser["firebaseID"] as! String
            let key = individualUser["key"] as! String
            let bucket = individualUser["bucket"] as! String
            let picURL = URL(string: "https://\(bucket).s3.amazonaws.com/\(key)")!
            if !self.urlArray.contains(picURL) {
                self.urlArray.append(picURL)
            }
            
            if cellType == "user" || cellType == "search" {
                let isFriend = individualUser["isFriend"] as! String
                let userID = individualUser["userID"] as! Int
                let userName = individualUser["userName"] as! String
                
                let user: [String: Any] = ["userID": userID, "userIDFIR": userIDFIR, "userName": userName, "userHandle": userHandle, "picURL": picURL, "isFriend": isFriend]
                users.append(user)
                
            } else {
                let senderID = individualUser["senderID"] as! Int
                let recipID = individualUser["recipID"] as! Int
                var userID: Int
                if self.myID != senderID {
                    userID = senderID
                } else {
                    userID = recipID
                }
                
                let isFriend = individualUser["isFriend"] as! String
                let messageContent = individualUser["messageContent"] as! String
                let timestamp = individualUser["timestamp"] as! String
                let timestampFormatted = self.misc.formatTimestamp(timestamp)
                let lastChat: String = "\(timestampFormatted): \(messageContent)"
                
                let user: [String: Any] = ["userID": userID, "userIDFIR": userIDFIR, "isFriend": isFriend, "senderID": senderID, "userHandle": userHandle, "lastChat": lastChat, "picURL": picURL]
                users.append(user)
            }
        }
        
        return users
    }
    
    func addToFlow(sender: UIButton) {
        let position: CGPoint = sender.convert(CGPoint.zero, to: self.friendListTableView)
        let indexPath: IndexPath! = self.friendListTableView.indexPathForRow(at: position)
        let cell = self.friendListTableView.cellForRow(at: indexPath) as! UserListTableViewCell
        cell.addButton.isSelected = true
        
        let individualUser = self.addedMe[indexPath.row]
        let userID: Int = individualUser["userID"] as! Int
        let userIDFIR: String = individualUser["userIDFIR"] as! String

        let action: String = "accept"
        
        let token = misc.generateToken(16, firebaseID: self.myIDFIR)
        let iv = token.first!
        let tokenString = token.last!
        let key = token[1]
        
        do {
            let aes = try AES(key: key, iv: iv)
            let cipherText = try aes.encrypt(tokenString.utf8.map({$0}))
            
            let actionURL = URL(string: "https://dotnative.io/sendFriendRequest")
            var actionRequest = URLRequest(url: actionURL!)
            actionRequest.httpMethod = "POST"
            
            let actionString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&userID=\(userID)&action=\(action)"
            
            actionRequest.httpBody = actionString.data(using: String.Encoding.utf8)
            
            let task = URLSession.shared.dataTask(with: actionRequest as URLRequest) {
                (data, response, error) in
                
                if error != nil {
                    print(error ?? "error")
                    self.displayAlert(":(", alertMessage: "Sorry, no internet. Please try again later to respond to request.")
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
                                self.displayAlert("Oops", alertMessage: "Sorry, we messed up. Your response may not have gone through. Please report the bug in the report section of the menu.")
                                return
                            }
                            
                            if status == "success" {
                                cell.addLabel.text = "Added"
                                self.writeAcceptAction(userIDFIR)
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
            self.displayAlert("Token Error", alertMessage: "We messed up. Please report the bug in the report section of the menu if this persists.")
            return
        }
    }
    
    func searchFriend() {
        let criteria = searchController.searchBar.text
        self.firstLoadSearch = false
        let size: String = "medium"
        var lastUserID: Int = 0
        
        if self.scrollPosition == "bottom" && self.userSearchResults.count >= 42 {
            let lastUser = self.userSearchResults.last!
            lastUserID = lastUser["userID"] as! Int
            self.displayActivity("loading more people...", indicator: true)
        } else {
            lastUserID = 0
            self.userSearchResults = []
        }
        
        if criteria == "" {
            return
        } else {
            let token = misc.generateToken(16, firebaseID: self.myIDFIR)
            let iv = token.first!
            let tokenString = token.last!
            let key = token[1]
            
            do {
                let aes = try AES(key: key, iv: iv)
                let cipherText = try aes.encrypt(tokenString.utf8.map({$0}))
                let getSearchURL = URL(string: "https://dotnative.io/searchFriend")
                var getSearchRequest = URLRequest(url: getSearchURL!)
                getSearchRequest.httpMethod = "POST"
                
                let getString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&criteria=\(criteria!)&lastUserID=\(lastUserID)&size=\(size)"
                
                getSearchRequest.httpBody = getString.data(using: String.Encoding.utf8)
                
                let task = URLSession.shared.dataTask(with: getSearchRequest as URLRequest) {
                    (data, response, error) in
                    
                    if error != nil {
                        print(error ?? "error")
                        self.displayAlert("uhh, Houston, we have a problem", alertMessage: "Sorry, could not connect to le internet. :(")
                        return
                    }
                    
                    do{
                        let json = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as? NSDictionary
                        
                        if let parseJSON = json {
                            let status = parseJSON["status"] as! String
                            let message = parseJSON["message"] as! String
                            print("status: \(status), message: \(message)")
                            
                            DispatchQueue.main.async(execute: {
                                self.activityView.removeFromSuperview()
                                
                                if status == "error" {
                                    self.friendListTableView.reloadData()
                                    self.displayAlert("Oops", alertMessage: "We've encountered an error and can't load search results. Please report the bug in the report section of the menu.")
                                    return
                                }
                                
                                if status == "success" {
                                    if let users = parseJSON["users"] as? [[String:Any]] {
                                        let usersArray = self.appendResults(users, cellType: "search")
                                        self.logSearchingForFriend()
                                        
                                        if lastUserID != 0 {
                                            self.userSearchResults.append(contentsOf: usersArray)
                                            if self.userSearchResults.count > 210 {
                                                let difference = self.userSearchResults.count - 210
                                                let indicesToRemove = 0...(difference-1)
                                                self.userSearchResults = self.userSearchResults.enumerated().filter{!indicesToRemove.contains($0.offset)}.map{$0.element}
                                            }
                                        } else {
                                            self.userSearchResults = usersArray
                                        }
                                    }
                                    
                                    let users = self.userSearchResults
                                    if !users.isEmpty {
                                        var firstRows = 5
                                        let maxCount = users.count
                                        if firstRows > (maxCount - 1) {
                                            firstRows = maxCount - 1
                                        }
                                        
                                        var urlsToPrefetch: [URL] = []
                                        for index in 0...firstRows {
                                            let user = users[index]
                                            if let picURL = user["picURL"] as? URL {
                                                urlsToPrefetch.append(picURL)
                                            }
                                        }
                                        
                                        SDWebImagePrefetcher.shared().prefetchURLs(urlsToPrefetch, progress: nil, completed: { (completed, skipped) in
                                            self.friendListTableView.reloadData()
                                        })
                                    }  else {
                                        self.friendListTableView.reloadData()
                                    }

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
                self.displayAlert("Token Error", alertMessage: "We messed up. Please report the bug in the report section of the menu if this persists.")
                return
            }
        }
    }
    
    func getFriendList() {
        self.newUpdatesCount = 0
        let size: String = "medium"
        var lastUserName: String = "0"
        
        if self.scrollPosition == "bottom" && self.segmentedControl.selectedSegmentIndex == 1 && self.friendsAddedTo.count >= 42  {
            let lastUser = self.friendsAddedTo.last!
            lastUserName = lastUser["userName"] as! String
            self.displayActivity("loading more friends/added...", indicator: true)
        } else {
            lastUserName = "0"
            self.userSearchResults = []
        }
        
        let token = misc.generateToken(16, firebaseID: self.myIDFIR)
        let iv = token.first!
        let tokenString = token.last!
        let key = token[1]
        
        do {
            let aes = try AES(key: key, iv: iv)
            let cipherText = try aes.encrypt(tokenString.utf8.map({$0}))
            
            let getURL = URL(string: "https://dotnative.io/getFriendList")
            var getRequest = URLRequest(url: getURL!)
            getRequest.httpMethod = "POST"

            let getString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&lastUserName=\(lastUserName)&size=\(size)"
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
                            self.activityView.removeFromSuperview()
                            
                            if status == "error" {
                                self.firstLoad = false
                                self.friendListTableView.reloadData()
                                self.displayAlert("Oops", alertMessage: "We've encountered an error and can't load your friends. Please report the bug in your profile if this persists.")
                                return
                            }
                            
                            if status == "success" {
                                
                                if let receivedRequestsArray = parseJSON["receivedRequests"] as? [[String:Any]] {
                                    let receivedArray = self.appendResults(receivedRequestsArray, cellType: "user")
                                    self.addedMe = receivedArray
                                }
                                
                                if let currentChatsArray = parseJSON["chats"] as? [[String:Any]] {
                                    let chatsArray = self.appendResults(currentChatsArray, cellType: "chat")
                                    self.chats = chatsArray
                                }
                                
                                if let currentFriendsArray = parseJSON["currentFriends"] as? [[String:Any]] {
                                    let friendsArray = self.appendResults(currentFriendsArray, cellType: "user")
                                    if lastUserName != "0" {
                                        let latestUser = friendsArray.last!
                                        if lastUserName.lowercased() != (latestUser["userName"] as! String).lowercased() {
                                            self.friendsAddedTo.append(contentsOf: friendsArray)
                                            if self.friendsAddedTo.count > 210 {
                                                let difference = self.friendsAddedTo.count - 210
                                                let indicesToRemove = 0...(difference-1)
                                                self.friendsAddedTo = self.friendsAddedTo.enumerated().filter{!indicesToRemove.contains($0.offset)}.map{$0.element}
                                            }
                                        }
                                    } else {
                                        self.friendsAddedTo = friendsArray
                                    }
                                }
                                
                                var users: [[String:Any]] = []
                                switch self.segmentedControl.selectedSegmentIndex {
                                case 0:
                                    users = self.chats
                                case 1:
                                    users = self.friendsAddedTo
                                default:
                                    users = self.addedMe
                                }
                                if !users.isEmpty {
                                    var firstRows = 5
                                    let maxCount = users.count
                                    if firstRows >= (maxCount - 1) {
                                        firstRows = maxCount - 1
                                    }
                                    
                                    var urlsToPrefetch: [URL] = []
                                    for index in 0...firstRows {
                                        let user = users[index]
                                        if let picURL = user["picURL"] as? URL {
                                            urlsToPrefetch.append(picURL)
                                        }
                                    }
                                    
                                    SDWebImagePrefetcher.shared().prefetchURLs(urlsToPrefetch, progress: nil, completed: { (completed, skipped) in
                                        self.firstLoad = false
                                        self.friendListTableView.reloadData()
                                    })
                                }  else {
                                    self.firstLoad = false
                                    self.friendListTableView.reloadData()
                                }
                                
                            } // success
                            self.firstLoad = false
                            self.friendListTableView.reloadData()
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
            self.displayAlert("Token Error", alertMessage: "We messed up. Please report the bug using the report bug button in your profile if this persists.")
            return
        }
    }
    
    func refreshWithDelay() {
        self.firstLoad = true
        self.searchController.isActive = false
        if self.scrollPosition == "top" {
            self.perform(#selector(self.observeFriendList), with: nil, afterDelay: 0.1)
        } else {
            self.perform(#selector(self.getFriendList), with: nil, afterDelay: 0.5)
            
        }
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
}

// MARK: - FB

extension FriendListViewController: FBSDKAppInviteDialogDelegate {
    func appInviteDialog(_ appInviteDialog: FBSDKAppInviteDialog!, didCompleteWithResults results: [AnyHashable : Any]!) {
        print("fb success")
    }
    
    func appInviteDialog(_ appInviteDialog: FBSDKAppInviteDialog!, didFailWithError error: Error!) {
        self.displayAlert("No Face :(", alertMessage: "Sorry, we encountered an error and are unable to invite through facebook. Please report this bug in your profile.")
        return
    }
}
