//
//  SideMenuTableViewCell.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit

class SideMenuTableViewCell: UITableViewCell {
    
    @IBOutlet weak var badgeLabel: UILabel!
    @IBOutlet weak var menuImageView: UIImageView!
    @IBOutlet weak var menuLabel: UILabel!
    
    @IBOutlet weak var imageLeading: NSLayoutConstraint!
    @IBOutlet weak var imageWidth: NSLayoutConstraint!
    @IBOutlet weak var labelLeading: NSLayoutConstraint!
    
    @IBOutlet weak var buttonView: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

}
