//
//  UserProfilePageViewController.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit

class UserProfilePageViewController: UIPageViewController, UIPageViewControllerDelegate, UIPageViewControllerDataSource {

    // MARK: - Outlets/Variables
    
    var userIDToPass: Int = -2
    var userIDFIRToPass: String = "-2"
    var friendStatusToPass: String = "Z"
    var chatIDToPass: String = "-2"
    var userHandleToPass: String = ".chat"
    var segueSender: String = "chat"
    var picURLToPass: URL!
    
    lazy var orderedViewControllers: [UIViewController] = {
        return [ self.newViewController("UserProfileNavigationController"), self.newViewController("ChatNavigationController")]
    } ()
    
    weak var userProfilePageViewControllerDelegate: UserProfilePageViewControllerDelegate?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        delegate = self
        dataSource = self
        
        if self.segueSender == "chat" {
            if let secondViewController = self.orderedViewControllers.last {
                setViewControllers([secondViewController], direction: .forward, animated: false, completion: nil)
            }
        } else {
            if let firstViewController = self.orderedViewControllers.first {
                setViewControllers([firstViewController], direction: .forward, animated: false, completion: nil)
            }
        }
        
        self.userProfilePageViewControllerDelegate?.userProfilePageViewController(self, didUpdatePageCount: orderedViewControllers.count)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.turnToFirstPage), name: NSNotification.Name(rawValue: "turnToUserProfile"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.turnToSecondPage), name: NSNotification.Name(rawValue: "turnToChat"), object: nil)
        
        self.disablePageControl()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Navigation
    
    func disablePageControl() {
        dataSource = nil
    }
    
    func enablePageControl() {
        dataSource = self
    }
    
    func turnToFirstPage() {
        if let firstViewController = self.orderedViewControllers.first {
            setViewControllers([firstViewController], direction: .forward, animated: false, completion: nil)
        }
    }
    
    func turnToSecondPage() {
        if let secondViewController = self.orderedViewControllers.last {
            setViewControllers([secondViewController], direction: .forward, animated: false, completion: nil)
        }
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
            userProfilePageViewControllerDelegate?.userProfilePageViewController(self, didUpdatePageIndex: index)
        }
    }
    
    
    // MARK: - Views in container
    
    func newViewController(_ storyboardID: String) -> UIViewController {
        if storyboardID == "ChatNavigationController" {
            let navigationController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "\(storyboardID)") as! UINavigationController
            let viewController = navigationController.topViewController as! ChatViewController
            viewController.userID = self.userIDToPass
            viewController.userIDFIR = self.userIDFIRToPass
            viewController.isFriend = self.friendStatusToPass
            viewController.chatID = self.chatIDToPass
            viewController.userHandle = self.userHandleToPass
            viewController.picURL = self.picURLToPass
            viewController.segueSender = "userProfile"
            return navigationController
        } else {
            let navigationController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "\(storyboardID)") as! UINavigationController
            let viewController = navigationController.topViewController as! UserProfileViewController
            viewController.userID = self.userIDToPass
            viewController.userIDFIR = self.userIDFIRToPass
            viewController.isFriend = self.friendStatusToPass
            viewController.userHandle = self.userHandleToPass
            viewController.chatID = self.chatIDToPass
            viewController.segueSender = "userProfile"
            return navigationController
        }
    }
}

protocol UserProfilePageViewControllerDelegate: class {
    
    func userProfilePageViewController(_ userProfilePageViewController: UserProfilePageViewController, didUpdatePageCount count: Int)
    
    func userProfilePageViewController(_ userProfilePageViewController: UserProfilePageViewController, didUpdatePageIndex index: Int)
    
}
