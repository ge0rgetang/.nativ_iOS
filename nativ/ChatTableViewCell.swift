//
//  ChatTableViewCell.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit

class ChatTableViewCell: UITableViewCell {

    @IBOutlet weak var whiteView: UIView!
    
    @IBOutlet weak var chatMessageLabel: UILabel!
    
    @IBOutlet weak var timestampLabel: UILabel!
    
    @IBOutlet weak var userPicImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
}
