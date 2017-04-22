//
//  MasterPageViewController.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit

class MasterPageViewController: UIPageViewController, UIPageViewControllerDelegate, UIPageViewControllerDataSource {
    
    // MARK: - Outlets/Variables
    
    lazy var orderedViewControllers: [UIViewController] = {
        return [ self.newViewController("PondListNavigationController"), self.newViewController("DropListNavigationController"), self.newViewController("FriendListNavigationController"), self.newViewController("NotificationsNavigationController"), self.newViewController("MyProfileNavigationController"), self.newViewController("ReportBugNavigationController"), self.newViewController("FeedbackNavigationController"), self.newViewController("AboutNavigationController"), self.newViewController("SignUpNavigationController")]
    } ()
    
    weak var masterPageViewControllerDelegate: MasterPageViewControllerDelegate?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        delegate = self
        dataSource = nil
        
        if let firstViewController = self.orderedViewControllers.first {
            setViewControllers([firstViewController], direction: .forward, animated: true, completion: nil)
        }
        
        self.masterPageViewControllerDelegate?.masterPageViewController(self, didUpdatePageCount: orderedViewControllers.count)
        
        self.addTurnToPageObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Navigation
    
    func addTurnToPageObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.turnToPondList), name: NSNotification.Name(rawValue: "turnToPondList"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.turnToDropList), name: NSNotification.Name(rawValue: "turnToDropList"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.turnToFriendList), name: NSNotification.Name(rawValue: "turnToFriendList"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.turnToNotifications), name: NSNotification.Name(rawValue: "turnToNotifications"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.turnToMyProfile), name: NSNotification.Name(rawValue: "turnToMyProfile"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.turnToReportBug), name: NSNotification.Name(rawValue: "turnToReportBug"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.turnToFeedback), name: NSNotification.Name(rawValue: "turnToFeedback"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.turnToAbout), name: NSNotification.Name(rawValue: "turnToAbout"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.turnToSignUp), name: NSNotification.Name(rawValue: "turnToSignUp"), object: nil)
    }
    
    func turnToPondList() {
        let pondListViewController = self.orderedViewControllers[0]
        setViewControllers([pondListViewController], direction: .forward, animated: false, completion: nil)
        NotificationCenter.default.post(name: Notification.Name(rawValue: "scrollToTop"), object: nil)
    }
    
    func turnToDropList() {
        let dropListViewController = self.orderedViewControllers[1]
        setViewControllers([dropListViewController], direction: .forward, animated: false, completion: nil)
        NotificationCenter.default.post(name: Notification.Name(rawValue: "scrollToTop"), object: nil)
    }
    
    func turnToFriendList() {
        let friendListViewController = self.orderedViewControllers[2]
        setViewControllers([friendListViewController], direction: .forward, animated: false, completion: nil)
        NotificationCenter.default.post(name: Notification.Name(rawValue: "scrollToTop"), object: nil)
    }
    
    func turnToNotifications() {
        let notificationsViewController = self.orderedViewControllers[3]
        setViewControllers([notificationsViewController], direction: .forward, animated: false, completion: nil)
        NotificationCenter.default.post(name: Notification.Name(rawValue: "scrollToTop"), object: nil)
    }
    
    func turnToMyProfile() {
        let myProfileViewController = self.orderedViewControllers[4]
        setViewControllers([myProfileViewController], direction: .forward, animated: false, completion: nil)
    }
    
    func turnToReportBug() {
        let reportBugViewController = self.orderedViewControllers[5]
        setViewControllers([reportBugViewController], direction: .forward, animated: false, completion: nil)
    }
    
    func turnToFeedback() {
        let reportBugViewController = self.orderedViewControllers[6]
        setViewControllers([reportBugViewController], direction: .forward, animated: false, completion: nil)
    }
    
    func turnToAbout() {
        let aboutViewController = self.orderedViewControllers[7]
        setViewControllers([aboutViewController], direction: .forward, animated: false, completion: nil)
    }
    
    func turnToSignUp() {
        let signUpViewController = self.orderedViewControllers[8]
        setViewControllers([signUpViewController], direction: .forward, animated: false, completion: nil)
    }
    
    func disablePageControl() {
        dataSource = nil
    }
    
    func enablePageControl() {
        dataSource = self
    }

    // MARK: - PageView
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        
        guard let viewControllerIndex = self.orderedViewControllers.index(of: viewController) else {
            return nil
        }
        
        let previousIndex = viewControllerIndex - 1
        
        guard previousIndex >= 0 else {
            return nil
        }
        
        guard self.orderedViewControllers.count > previousIndex else {
            return nil
        }
        
        return self.orderedViewControllers[previousIndex]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        
        guard let viewControllerIndex = self.orderedViewControllers.index(of: viewController) else {
            return nil
        }
        
        let nextIndex = viewControllerIndex + 1
        
        let orderedViewControllersCount = self.orderedViewControllers.count
        
        guard orderedViewControllersCount != nextIndex else {
            return nil
        }
        
        guard orderedViewControllersCount > nextIndex else {
            return nil
        }
        
        return self.orderedViewControllers[nextIndex]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if let firstViewController = viewControllers?.first,
            let index = self.orderedViewControllers.index(of: firstViewController) {
            masterPageViewControllerDelegate?.masterPageViewController(self, didUpdatePageIndex: index)
        }
    }
    
    // MARK: - Views in container
    
    func newViewController(_ storyboardID: String) -> UIViewController {
        switch storyboardID {
        default:
            return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "\(storyboardID)")
        }
    }
    
}

protocol MasterPageViewControllerDelegate: class {
    
    func masterPageViewController(_ masterPageViewController: MasterPageViewController, didUpdatePageCount count: Int)
    
    func masterPageViewController(_ masterPageViewController: MasterPageViewController, didUpdatePageIndex index: Int)
    
}
