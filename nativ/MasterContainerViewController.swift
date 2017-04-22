//
//  MasterContainerViewController.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit

class MasterContainerViewController: UIViewController, MasterPageViewControllerDelegate {

    // MARK: - Outlets/Variables
    
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var pageControl: UIPageControl!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.pageControl.isHidden = true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // - MARK: MasterPageViewController delegate
    
    func masterPageViewController(_ masterPageViewController: MasterPageViewController, didUpdatePageCount count: Int) {
        self.pageControl.numberOfPages = count
    }
    
    func masterPageViewController(_ masterPageViewController: MasterPageViewController, didUpdatePageIndex index: Int) {
        self.pageControl.currentPage = index
    }

}
