//
//  UserProfileContainerViewController.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit

class UserProfileContainerViewController: UIViewController, UserProfilePageViewControllerDelegate {

    // MARK: - Outlets/Variables
    
    var userIDToPass: Int = -2
    var userIDFIRToPass: String = "-2"
    var userHandleToPass: String = ".chat"
    var friendStatusToPass: String = "Z"
    var chatIDToPass: String = "-2"
    var segueSender: String = "chat"
    var picURLToPass: URL!
    
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var pageControl: UIPageControl!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = self.userHandleToPass
        self.navigationController?.navigationBar.isHidden = true

        self.disablePageControl()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let userProfilePageViewController = segue.destination as? UserProfilePageViewController {
            userProfilePageViewController.userProfilePageViewControllerDelegate = self
            userProfilePageViewController.userIDToPass = self.userIDToPass
            userProfilePageViewController.userIDFIRToPass = self.userIDFIRToPass
            userProfilePageViewController.chatIDToPass = self.chatIDToPass
            userProfilePageViewController.friendStatusToPass = self.friendStatusToPass
            userProfilePageViewController.userHandleToPass = self.userHandleToPass
            userProfilePageViewController.picURLToPass = self.picURLToPass
            userProfilePageViewController.segueSender = self.segueSender
        }
    }
    
    func disablePageControl() {
        self.pageControl.isHidden = true
    }
    
    func enablePageControl() {
        self.pageControl.isHidden = false
    }
    
    // - MARK: UserPageViewController delegate
    
    func userProfilePageViewController(_ userProfilePageViewController: UserProfilePageViewController, didUpdatePageCount count: Int) {
        self.pageControl.numberOfPages = count
    }
    
    func userProfilePageViewController(_ userProfilePageViewController: UserProfilePageViewController, didUpdatePageIndex index: Int) {
        self.pageControl.currentPage = index
    }
    
}
