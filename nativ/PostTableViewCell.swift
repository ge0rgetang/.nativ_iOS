//
//  PostTableViewCell.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit

class PostTableViewCell: UITableViewCell {

    @IBOutlet weak var whiteView: UIView!
    
    @IBOutlet weak var userPicImageView: UIImageView!
    @IBOutlet weak var userHandleLabel: UILabel!
    @IBOutlet weak var userNameLabel: UILabel!
    
    @IBOutlet weak var pointsLabel: UILabel!
    @IBOutlet weak var actionButton: UIButton!
    @IBOutlet weak var actionSpacerLabel: UILabel!
    
    @IBOutlet weak var postContentTextView: UITextView!
    
    @IBOutlet weak var timestampLabel: UILabel!
    @IBOutlet weak var shareCountLabel: UILabel!
    @IBOutlet weak var sharePicImageView: UIImageView!
    @IBOutlet weak var shareSpacerLabel: UILabel!
    @IBOutlet weak var replyCountLabel: UILabel!
    @IBOutlet weak var replyPicImageView: UIImageView!
    
    @IBOutlet weak var postImageView: UIImageView!
    
    @IBOutlet weak var recentReplyLabel: UILabel!
    @IBOutlet weak var userReplyPicImageView: UIImageView!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.postContentTextView.textContainerInset = UIEdgeInsets.zero
        self.postContentTextView.textContainer.lineFragmentPadding = 0
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
}
