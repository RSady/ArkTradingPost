//
//  PostViewController.swift
//  ArkTradingPost
//
//  Created by Ryan Sady on 3/6/19.
//  Copyright © 2019 Ryan Sady. All rights reserved.
//

import UIKit
import TBEmptyDataSet
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth
import CoreData

class PostViewController: UIViewController {

    @IBOutlet weak var postTitleLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var postBodyLabel: UILabel!
    @IBOutlet weak var postOriginatorLabel: UILabel!
    @IBOutlet weak var dateTimeLabel: UILabel!
    @IBOutlet weak var commentCountLabel: UILabel!
    @IBOutlet weak var replyButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var imageCollectionView: UICollectionView!
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var replyViewHeight: NSLayoutConstraint!
    
    let replyCellHeight: CGFloat = 130
    var cameFromSearch: Bool?
    var cameFromNotification: Bool = false
    var currentPost: Post?
    var replies = [Reply]()
    let dateFormatter = DateFormatter()
    var commentCount = Int()
    let activityIndicator = SzActivityIndicator()
    let storage = Storage.storage()
    var selectedIndex: IndexPath?
    var updatePostDelegate: UpdatePostDelegate?
    var selectedImageView: UIImageView?
    lazy var dimView: UIView = {
        let view = UIView(frame: self.view.bounds)
        view.backgroundColor = UIColor(white: 0.25, alpha: 0.7)
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let post = currentPost {
            checkPostStatus(for: post)
        }
        
        pageControl.numberOfPages = 1
        setupCollectionView()
        tableView.addObserver(self, forKeyPath: "contentSize", options: NSKeyValueObservingOptions.new, context: nil)
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "post_options_icon") ?? UIImage(), style: .plain, target: self, action: #selector(postOptionsAction))
        styleView()
        getReplyData()
        if let comments = currentPost?.commentCount {
            commentCount = comments
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        tableView.layer.removeAllAnimations()
        replyViewHeight.constant = tableView.contentSize.height
        UIView.animate(withDuration: 0.5) {
            self.updateViewConstraints()
            self.loadViewIfNeeded()
        }
    }
    
    fileprivate func styleView() {
        styleButton(button: replyButton, titleColor: .white, fillColor: .clear, borderColor: primaryColor)
        
        if let post = currentPost {
            populateData(from: post)
        }
    }
    
    fileprivate func checkPostStatus(for post: Post) {
        if let postStatus = post.status {
            switch postStatus {
            case .closed, .suspended:
                let alertView = UIAlertController(title: "Yikes", message: "This post has been closed or is suspended.", preferredStyle: .alert)
                alertView.addAction(UIAlertAction(title: "Close", style: .default, handler: { (_) in
                    self.navigationController?.popViewController(animated: true)
                }))
                present(alertView, animated: true, completion: nil)
            default: break
            }
        }
    }
    
    fileprivate func setupCollectionView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.emptyDataSetDelegate = self
        tableView.emptyDataSetDataSource = self
        tableView.layer.cornerRadius = 10
        tableView.layer.masksToBounds = true
        tableView.clipsToBounds = true
        imageCollectionView.delegate = self
        imageCollectionView.dataSource = self
    }
    
    fileprivate func populateData(from post: Post) {
        postTitleLabel.text = post.title
        priceLabel.text = post.price
        postBodyLabel.text = post.body
        postOriginatorLabel.text = post.username
        if post.commentCount == 1 {
            commentCountLabel.text = "\(post.commentCount ?? 0) Reply"
        } else {
            commentCountLabel.text = "\(post.commentCount ?? 0) Replies"
        }
        
        dateFormatter.dateFormat = "E, MMM d yyyy h:mm a"
        if let date = post.created {
            dateTimeLabel.text = dateFormatter.string(from: date)
        } else {
            dateTimeLabel.text = nil
        }
        
        if let images = post.images {
            if images.count == 0 {
                pageControl.numberOfPages = 1
                currentPost?.images?.append(UIImage(named: "no_image.png") ?? UIImage())
                
                DispatchQueue.main.async {
                    self.imageCollectionView.reloadData()
                }
            } else {
                pageControl.numberOfPages = images.count
            }
        }
        
    }
    
    @objc fileprivate func postOptionsAction() {
        showOptionsPopover(for: currentPost)
    }
    
    fileprivate func getReplyData() {
        guard let post = currentPost, let postId = post.id else {
            showError(message: "No Post Data Found.")
            return
        }
        activityIndicator.play(inView: self)
        getPostImages(postId: postId)
        APIClient.Posts.getReplies(fromPost: post) { (error, data) in
            if let error = error {
                self.activityIndicator.stop(inView: self)
                self.showError(message: error.localizedDescription)
                return
            }
            
            if let replyData = data {
                self.replies = replyData.sorted { $0.created?.compare($1.created!) == .orderedDescending  }
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    self.activityIndicator.stop(inView: self)
                }
            }
            self.activityIndicator.stop(inView: self)
            
        }
    }
    
    fileprivate func getPostImages(postId: String) {
        guard let imageCount = currentPost?.imageCount else { return }
        if imageCount == 0 { return }
        
        var i: Int = {
            if cameFromNotification {
                return 1
            } else {
                return 2
            }
        }()
        
        guard let placeholderImage = UIImage(named: "no_image.png") else { return }
        let postImages = self.currentPost?.images?.filter({ $0 != placeholderImage })
        self.currentPost?.images = postImages
        while i < (imageCount + 1) {
            let folderRef = storage.reference(withPath: postId).child("\(i).png")
            folderRef.getData(maxSize: 5 * 2024 * 2024, completion: { (data, error) in
                if let imgData = data {
                    if let newImage = UIImage(data: imgData) {
                        self.currentPost?.images?.append(newImage)
                        UIView.animate(withDuration: 0.5, animations: {
                            self.pageControl.numberOfPages = i - 1
                        }, completion: { (_) in
                            DispatchQueue.main.async {
                                self.imageCollectionView.reloadData()
                            }
                        })
                        
                    }
                }
            })
            i += 1
        }
    }

    @IBAction func replyAction() {
        showReplyPopover(for: currentPost)
    }

    fileprivate func showOptionsPopover(for post: Post?) {
        guard let userId = Auth.auth().currentUser?.uid, let postCreator = post?.userId else { return }
        let popOverContent = storyboard?.instantiateViewController(withIdentifier: "postOptions") as? PostOptionsViewController
        let nav = UINavigationController(rootViewController: popOverContent!)
        nav.modalPresentationStyle = .popover
        let popover = nav.popoverPresentationController
        nav.isNavigationBarHidden = true
        popover?.delegate = self
        popover?.sourceView = view
        popOverContent?.deletePostDelegate = self
        popOverContent?.currentPost = post
        popOverContent?.userIsPostCreator = userId.elementsEqual(postCreator)
        //popOverContent?.preferredContentSize = CGSize(width: UIScreen.main.bounds.width / 1 - 40, height: 325)
        popover?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        popover?.permittedArrowDirections = .init(rawValue: 0)
        
        self.present(nav, animated: true, completion: nil)
        
    }
    
    fileprivate func showReplyPopover(for post: Post?) {
        let popOverContent = storyboard?.instantiateViewController(withIdentifier: "postReply") as? ReplyPostViewController
        let nav = UINavigationController(rootViewController: popOverContent!)
        nav.modalPresentationStyle = .popover
        let popover = nav.popoverPresentationController
        nav.isNavigationBarHidden = true
        popover?.delegate = self
        popover?.sourceView = view
        popOverContent?.replyDelegate = self
        popOverContent?.currentPost = post
        popOverContent?.preferredContentSize = CGSize(width: UIScreen.main.bounds.width / 1 - 40, height: UIScreen.main.bounds.height / 1.75)
        popover?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        popover?.permittedArrowDirections = .init(rawValue: 0)
        
        self.present(nav, animated: true, completion: nil)
    }
    
    fileprivate func showImageZoomScreen(for image: UIImage) {
        let popOverContent = storyboard?.instantiateViewController(withIdentifier: "viewImage") as? ViewImageViewController
        let nav = UINavigationController(rootViewController: popOverContent!)
        nav.modalPresentationStyle = .popover
        let popover = nav.popoverPresentationController
        nav.isNavigationBarHidden = true
        popover?.delegate = self
        popover?.sourceView = view
        popOverContent?.image = image
        popOverContent?.preferredContentSize = CGSize(width: UIScreen.main.bounds.width - 40, height: UIScreen.main.bounds.height - 80)
        popover?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        popover?.permittedArrowDirections = .init(rawValue: 0)
        self.present(nav, animated: true, completion: nil)
    }
}

extension PostViewController: UIScrollViewDelegate {

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let visibleRect = CGRect(origin: self.imageCollectionView.contentOffset, size: self.imageCollectionView.bounds.size)
        let visiblePoint = CGPoint(x: visibleRect.midX, y: visibleRect.midY)
        if let visibleIndexPath = self.imageCollectionView.indexPathForItem(at: visiblePoint) {
            self.pageControl.currentPage = visibleIndexPath.row
        }
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return selectedImageView
    }
    
    
}

extension PostViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return replies.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "replyCell", for: indexPath) as? ReplyTableViewCell else { return UITableViewCell().self }
        cell.reply = replies[indexPath.row]
        replyViewHeight.constant = tableView.contentSize.height
        tableView.sizeToFit()
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}

extension PostViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView.tag == 1 { //Images
            return currentPost?.images?.count ?? 1
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView.tag == 1 { //Images
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "imageCell", for: indexPath) as? ImageCollectionViewCell else { return UICollectionViewCell() }
            if let images = currentPost?.images {
                cell.image = images[indexPath.row]
            }
            return cell
        }
        return UICollectionViewCell()
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView.tag == 1 { //Images
            if let cell = collectionView.cellForItem(at: indexPath) as? ImageCollectionViewCell {
                showImageZoomScreen(for: cell.image)
            }
        
        }
    }

}

extension PostViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.size.width - 10, height: collectionView.frame.size.height)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
    }
}

extension PostViewController: TBEmptyDataSetDelegate, TBEmptyDataSetDataSource {
    func titleForEmptyDataSet(in scrollView: UIScrollView) -> NSAttributedString? {
        return NSAttributedString(string: "No Replies")
    }
    
    func descriptionForEmptyDataSet(in scrollView: UIScrollView) -> NSAttributedString? {
        return NSAttributedString(string: "Be the first to leave a reply!")
    }
}

extension PostViewController: ReplyDelegate {
    func insertReply(reply: Reply) {
        replies.append(reply)
        replies = replies.sorted { $0.created?.compare($1.created!) == .orderedDescending  }
        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.commentCount += 1
            if self.commentCount == 1 {
                self.commentCountLabel.text = "\(self.commentCount) Reply"
            } else {
                self.commentCountLabel.text = "\(self.commentCount) Replies"
            }
            
        }
    }
}

extension PostViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
    
    func prepareForPopoverPresentation(_ popoverPresentationController: UIPopoverPresentationController) {
        view.addSubview(dimView)
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut], animations: {
            self.dimView.alpha = 1
        }, completion: nil)
        
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        UIView.animate(withDuration: 0.5, delay: 0, options: [.curveEaseInOut], animations: {
            self.dimView.alpha = 0
        }, completion: { (_) in
            self.dimView.removeFromSuperview()
        })
    }
    
}

extension PostViewController: ReportPostDelegate {
    func reportedPost(successful: Bool) {
        guard let showingReportButton = cameFromSearch else { return }
        if successful && showingReportButton {
            navigationItem.rightBarButtonItem = nil
        }
    }
}

extension PostViewController: DeletePostDelegate { //Closes Post: Does NOT Delete it!
    func deletePost(post: Post?, indexPath: IndexPath?) {
        guard let postToDelete = post else { print("No postToDelete"); return }
        activityIndicator.play(inView: self)
        APIClient.Posts.closePost(post: postToDelete) { (error) in
            if let error = error {
                self.activityIndicator.stop(inView: self)
                self.showError(message: error.localizedDescription)
                return
            }
            APIClient.Notifications.deleteNotification(for: postToDelete, completion: { (error) in
                if let error = error {
                    self.activityIndicator.stop(inView: self)
                    self.showError(message: error.localizedDescription)
                }
            })
                
            DispatchQueue.main.async {
                self.activityIndicator.stop(inView: self)
                self.updatePostDelegate?.removePost(atIndexPath: self.selectedIndex)
                self.navigationController?.popViewController(animated: true)
            }
        }
    }
}

