//
//  API_Client.swift
//  ArkTradingPost
//
//  Created by Ryan Sady on 3/2/19.
//  Copyright © 2019 Ryan Sady. All rights reserved.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseMessaging
import FirebaseStorage
import CoreData

class APIClient {
    
    private static let database = Firestore.firestore()
    private static let auth = Auth.auth()
    private static let managedContext = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    private static let userDefaults = UserDefaults.standard
    private static let storage = Storage.storage()
    private static let storageRef = storage.reference()
    
    ///Anything related to logging in a user
    enum Login {
        ///Signs in a user based on username and password
        static func signIn(with email: String, password: String, completion: @escaping (_ error: Error?, _ data: AppUser?) -> Void) {
            auth.signIn(withEmail: email, password: password) { (user, error) in
                if let error = error { completion(error, nil); return }
                
                if let userData = user?.user {
                    if !(userData.isEmailVerified) {
                        try? auth.signOut()
                        completion(APIErrors.unverifiedEmail, nil)
                        return
                    }
                    
                    database.collection("users").document(userData.uid).getDocument(completion: { (documentSnapshot, error) in
                        if let error = error { completion(error, nil); return }
                        
                        if let document = documentSnapshot, document.exists {
                            guard let data = document.data() else {
                                completion(APIErrors.noData, nil)
                                return
                            }
                            
                            if let displayName = data["display_name"] as? String,
                                let email = data["email"] as? String,
                                let enabled = data["enabled"] as? Bool,
                                let platformStr = data["platform"] as? String,
                                let serverTypeStr = data["server_type"] as? String,
                                let userType = data["user_type"] as? String {
                                
                                var serverType: ServerType?
                                var platform: Platform?
                                
                                for type in ServerType.allCases {
                                    if type.rawValue.lowercased() == serverTypeStr.lowercased() {
                                        serverType = type
                                    }
                                }
                                
                                for platfrm in Platform.allCases {
                                    if platfrm.rawValue.lowercased() == platformStr.lowercased() {
                                        platform = platfrm
                                    }
                                }
                                
                                let appUser = AppUser(id: document.documentID, displayName: displayName,
                                                      email: email, password: nil, platform: platform,
                                                      serverType: serverType, type: userType, enabled: enabled)
                                
                                completion(nil, appUser)
                            } else {
                                completion(APIErrors.parseError, nil)
                            }
                        } else {
                            print("No Document Data")
                            completion(APIErrors.noData, nil)
                        }
                    })
                }
            }
        }
        
        ///Auto signin function if user is currently signed into Firebase
        static func autoSignin(completion: @escaping (_ error: Error?, _ data: AppUser?) -> Void) {
            guard let user = auth.currentUser else {
                completion(APIErrors.noUser, nil)
                return
            }
            database.collection("users").document(user.uid).getDocument { (documentSnapshot, error) in
                if let error = error {
                    completion(error, nil)
                    return
                }
                
                if let document = documentSnapshot, document.exists {
                    guard let data = document.data() else {
                        completion(APIErrors.noData, nil)
                        return
                    }
                    if let displayName = data["display_name"] as? String,
                        let email = data["email"] as? String,
                        let enabled = data["enabled"] as? Bool,
                        let platformStr = data["platform"] as? String,
                        let serverTypeStr = data["server_type"] as? String,
                        let userType = data["user_type"] as? String {
                        
                        var serverType: ServerType?
                        var platform: Platform?
                        
                        for type in ServerType.allCases {
                            if type.rawValue.lowercased() == serverTypeStr.lowercased() {
                                serverType = type
                            }
                        }
                        
                        for platfrm in Platform.allCases {
                            if platfrm.rawValue.lowercased() == platformStr.lowercased() {
                                platform = platfrm
                            }
                        }
                        
                        let appUser = AppUser(id: document.documentID, displayName: displayName,
                                              email: email, password: nil, platform: platform,
                                              serverType: serverType, type: userType, enabled: enabled)
                        
                        completion(nil, appUser)
                    } else {
                        completion(APIErrors.parseError, nil)
                    }
                } else {
                    print("No Document Data")
                    completion(APIErrors.noData, nil)
                }
            }
        }
        
        ///Creates a new account for Firebase as well as a new user record in the Firestore table
        static func createNewAccount(userData: AppUser, completion: @escaping (_ error: Error?, _ data: AppUser?) -> Void) {
            guard let displayName = userData.displayName,
                let email = userData.email,
                let password = userData.password,
                let platform = userData.platform,
                let serverType = userData.serverType else {
                    return
            }
            //Create User in Auth Table
            auth.createUser(withEmail: email, password: password) { (authResult, error) in
                if let err = error {
                    completion(err, nil)
                    return
                }
                
                if let authData = authResult {
                    let postData: [String: Any] = [ "display_name" : displayName,
                                                       "email" : email,
                                                       "platform" : platform.rawValue,
                                                       "server_type" : serverType.rawValue,
                                                       "date_created" : Int(Date().timeIntervalSince1970),
                                                       "user_type": "regular",
                                                       "enabled" : true,
                                                       "rating" : ""]
                    //Create User in Users Table
                    let createdUser = database.collection("users").document(authData.user.uid)
                    createdUser.setData(postData, completion: { (error) in
                        if let err = error {
                            completion(err, nil)
                            return
                        } else {
                            auth.currentUser?.sendEmailVerification(completion: { (error) in
                                if let error = error {
                                    completion(error, nil)
                                    return
                                } else {
                                    try? auth.signOut()
                                }
                            })
                            
                            //User Created Successfully - Return Data
                            let newUser = AppUser(id: createdUser.documentID, displayName: displayName, email: email, password: nil, platform: platform, serverType: serverType, type: "regular", enabled: true)
                            completion(nil, newUser)
                        }
                    })
                    
                }
            }
        }
    
        ///Resends Verification Email to User
        static func resendVerificationEmail(to email: String, password: String, completion: @escaping (_ error: Error?) -> Void) {
            auth.signIn(withEmail: email, password: password) { (user, error) in
                if let error = error {
                    completion(error)
                    return
                }
            
                if let userData = user?.user {
                    userData.sendEmailVerification(completion: { (error) in
                        if let error = error {
                            completion(error)
                            return
                        } else {
                            completion(nil)
                        }
                    })
                } else {
                    completion(APIErrors.noUser)
                    return
                }
                try? auth.signOut()
            }
            
        }
    }
    
    ///Anything related to posting such as creating a new post or retrieving posts
    enum Posts {

        static func closePost(post: Post, completion: @escaping (_ error: Error?) -> Void) {
            guard let postId = post.id else { completion(APIErrors.noPost); return }
            let postdata = ["status" : PostStatus.closed.rawValue]
            database.collection("posts").document(postId).updateData(postdata) { (error) in
                if let error = error {
                    completion(error)
                    return
                } else {
                    completion(nil)
                }
            }
        }
        
        ///Get all users from post replies
        static func getUsers(from post: Post, completion: @escaping (_ error: Error?, _ data: [Buyer]?) -> Void) {
            var buyers = [Buyer]()
            guard let postId = post.id else { completion(APIErrors.noPost, nil); return }
            database.collection("posts").document(postId).collection("replies").getDocuments { (querySnapshot, error) in
                if let error = error {
                    completion(error, nil)
                    return
                }
                
                if let snapshot = querySnapshot {
                    for document in snapshot.documents {
                        let docData = document.data()
                        let userId = docData["user_id"] as! String
                        database.collection("users").whereField("user_id", isEqualTo: userId).getDocuments(completion: { (snapshot, error) in
                            if let error = error {
                                completion(error, nil); return
                            }
                            
                            if let query = snapshot {
                                for document in query.documents {
                                    let queryData = document.data()
                                    let username = queryData["display_name"] as! String
                                    buyers.append(Buyer(userId: userId, username: username))
                                }
                            }
                        })
                    }
                }
                completion(nil, buyers)
            }
        }
        
        
        ///Delete post from database
        static func deletePost(post: Post, completion: @escaping (_ error: Error?) -> Void) {
            guard let postId = post.id else { completion(APIErrors.noPost); return }
            database.collection("posts").document(postId).delete { (error) in
                if let error = error {
                    completion(error)
                    return
                } else {
                    let fetchRequest = NSFetchRequest<PushNotification>(entityName: "PushNotification")
                    let data = try? managedContext.fetch(fetchRequest)
                    if let pushData = data {
                        for notification in pushData {
                            if notification.postId == postId {
                                managedContext.delete(notification)
                                try? managedContext.save()
                            }
                        }
                    } else { print("No Push CoreData") }
                    
                    guard let imgData = post.images, let imgCount = post.imageCount else { print("No Post Image Data"); completion(APIErrors.noPost); return }
                    
                    if imgCount == 0 {
                        print("No Image Data: Nil Completion")
                        completion(nil)
                        return
                    }
                    
                    for (index, _) in imgData.enumerated() {
                        print("Image \(index) Deleting...")
                        let imageRef = storageRef.child(postId).child("\(index + 1).png")
                        imageRef.delete(completion: { (error) in
                            if let error = error {
                                print("Image Deletion Error: ", error.localizedDescription)
                            }
                            
                            if index == (imgCount - 1) {
                                print("Index == Image Count")
                                completion(nil)
                                return
                            }
                        })
                    }
                    
                }
            }
        }
        
        ///Report a post
        static func reportPost(postId: String, comment: String, user: User?, completion: @escaping (_ error: Error?) -> Void) {
            guard let userId = user?.uid else { completion(APIErrors.noUser); return }
            let postdata: [String: Any] = [ "comments" : comment,
                                            "created"  : Int(Date().timeIntervalSince1970),
                                            "post"     : postId,
                                            "user"     : userId ]
            database.collection("reported_posts").addDocument(data: postdata) { (error) in
                if let error = error {
                    completion(error)
                    return
                } else {
                    completion(nil)
                }
                
            }
        }
        
        ///Gets the post count of the current users
        static func getCurrentPostCount(for user: User, completion: @escaping (_ error: Error?, _ data: Double?) -> Void) {
            database.collection("posts").whereField("user_id", isEqualTo: user.uid).whereField("status", isEqualTo: PostStatus.active.rawValue).getDocuments { (querySnapshot, error) in
                if let error = error {
                    completion(error, nil)
                    return
                }
                if let query = querySnapshot {
                    let postCount = query.documents.count
                    print("Number of active posts: ", postCount)
                    completion(nil, Double(postCount))
                } else {
                    completion(APIErrors.noData, nil)
                }
            }
        }
        
        static func getPost(withId postId: String, completion: @escaping (_ error: Error?, _ data: Post?) -> Void) {
            database.collection("posts").document(postId).getDocument { (documentSnapshot, error) in
                if let error = error {
                    completion(error, nil)
                    return
                }
                //var post: Post?
                if let document = documentSnapshot, document.exists {
                    guard let data = document.data() else {completion(APIErrors.noData, nil); print("No Data from API"); return }
                    if let postTitle = data["title"] as? String,
                        let postBody = data["body"] as? String,
                        let postType = data["post_type"] as? String,
                        let postServerType = data["server_type"] as? String,
                        let postPlatform = data["platform"] as? String,
                        let price = data["price"] as? String,
                        let created = data["created"] as? Int,
                        let userId = data["user_id"] as? String,
                        let fulfilledBy = data["fulfilled_by"] as? String,
                        let postSts = data["status"] as? String,
                        let commentCount = data["comment_count"] as? Int,
                        let imgCount = data["image_count"] as? Int {
                        
                        var serverType: ServerType?
                        var platform: Platform?
                        var postStatus: PostStatus?
                        var typeOfPost: PostType?
                        let dateCreated = Date(timeIntervalSince1970: TimeInterval(created))
                        for type in ServerType.allCases {
                            if type.rawValue.lowercased() == postServerType.lowercased() {
                                serverType = type
                            }
                        }
                        
                        for platfrm in Platform.allCases {
                            if platfrm.rawValue.lowercased() == postPlatform.lowercased() {
                                platform = platfrm
                            }
                        }
                        
                        for status in PostStatus.allCases {
                            if status.rawValue.lowercased() == postSts.lowercased() {
                                postStatus = status
                            }
                        }
                        
                        for type in PostType.allCases {
                            if type.rawValue.lowercased() == postType.lowercased() {
                                typeOfPost = type
                            }
                        }
                        
                        database.collection("users").document(userId).getDocument { (documentSnapshot, error) in
                            if let _ = error {
                                return
                            }
                            if let document = documentSnapshot {
                                let data = document.data()
                                if let username = data?["display_name"] as? String {
                                    let post = Post(id: postId, title: postTitle, body: postBody, postType: typeOfPost, platform: platform, serverType: serverType, price: price, created: dateCreated, userId: userId, username: username, fulfilledBy: fulfilledBy, status: postStatus, commentCount: commentCount, imageCount: imgCount)
                                    completion(nil, post)
                                } else { print("No Username Data"); return }
                            } else { print("No Doc Data"); return }
                        }
                    }
                    //completion(nil, post)
                } else { print("No Document"); completion(APIErrors.noData, nil)}
            }
        }
        
        ///Checks if user already reported the post
        static func getUserReportsFor(post postId: String, completion: @escaping (_ error: Error?, _ data: Int?) -> Void) {
            guard let userId = auth.currentUser?.uid else { completion(APIErrors.noUser, nil); return }
            database.collection("reported_posts").whereField("user", isEqualTo: userId).whereField("post", isEqualTo: postId).getDocuments { (querySnapshot, error) in
                if let error = error {
                    completion(error, nil)
                    return
                }
                if let snapshot = querySnapshot {
                    completion(nil, snapshot.documents.count)
                } else {
                    completion(APIErrors.parseError, nil)
                
                }
            }
        }
        
        ///Gets all posts in the database based on the filter provided
        static func getPosts(filters filter: Filter, completion: @escaping (_ error: Error?, _ data: [Post]?) -> Void) {
            var posts = [Post]()
            database.collection("posts").whereField("platform", isEqualTo: filter.platform as Any)
                                        .whereField("server_type", isEqualTo: filter.serverType as Any)
                                        .whereField("post_type", isEqualTo: filter.postType as Any)
                                        .whereField("status", isEqualTo: "active")
                .getDocuments { (querySnapshot, error) in
                    
                    if let error = error {
                        completion(error, nil)
                        return
                    }
                    
                    if let snapshot = querySnapshot {
                        if snapshot.documents.count == 0 {
                            completion(nil, [])
                            return
                        }
                        for document in snapshot.documents {
                            
                            let data = document.data()
                            let postId = document.documentID
                            if let postTitle = data["title"] as? String,
                                let postBody = data["body"] as? String,
                                let postType = data["post_type"] as? String,
                                let postServerType = data["server_type"] as? String,
                                let postPlatform = data["platform"] as? String,
                                let price = data["price"] as? String,
                                let created = data["created"] as? Int,
                                let userId = data["user_id"] as? String,
                                let fulfilledBy = data["fulfilled_by"] as? String,
                                let postSts = data["status"] as? String,
                                let imageCount = data["image_count"] as? Int,
                                let commentCount = data["comment_count"] as? Int {
                                
                                var serverType: ServerType?
                                var platform: Platform?
                                var postStatus: PostStatus?
                                var typeOfPost: PostType?
                                let dateCreated = Date(timeIntervalSince1970: TimeInterval(created))
                                for type in ServerType.allCases {
                                    if type.rawValue.lowercased() == postServerType.lowercased() {
                                        serverType = type
                                    }
                                }
                                
                                for platfrm in Platform.allCases {
                                    if platfrm.rawValue.lowercased() == postPlatform.lowercased() {
                                        platform = platfrm
                                    }
                                }
                                
                                for status in PostStatus.allCases {
                                    if status.rawValue.lowercased() == postSts.lowercased() {
                                        postStatus = status
                                    }
                                }
                                
                                for type in PostType.allCases {
                                    if type.rawValue.lowercased() == postType.lowercased() {
                                        typeOfPost = type
                                    }
                                }
                                
                                database.collection("users").document(userId).getDocument { (documentSnapshot, error) in
                                    
                                    if let error = error {
                                        completion(error, nil)
                                        return
                                    }
                                    var images = [UIImage]()

                                    if let document = documentSnapshot {
                                        let data = document.data()
                                        if let username = data?["display_name"] as? String {
                                            
                                            let folderRef = storage.reference(withPath: postId).child("1.png")
                                            folderRef.getData(maxSize: 5 * 1024 * 1024, completion: { (data, error) in
                                                if let imgData = data {
                                                    if let newImage = UIImage(data: imgData) {
                                                        images.append(newImage)
                                                    }
                                                }
                                                
                                                let newPost = Post(id: postId, title: postTitle, body: postBody, postType: typeOfPost, platform: platform, serverType: serverType, price: price, created: dateCreated, userId: userId, username: username, fulfilledBy: fulfilledBy, status: postStatus, commentCount: commentCount, images: images, imageCount: imageCount, searchText: "\(postTitle) \(postBody) \(price) \(username)")
                                                print("Post: ", postId, "Images: ", images.count)
                                                posts.append(newPost)
                                                
                                                if posts.count == snapshot.documents.count {
                                                    print("Image Completion")
                                                    completion(nil, posts)
                                                }
                                            })

                                        } else { print("No Username Data") }
                                    } else { print("No Doc Data") }
                                }
                            } else { print("Parsing Error") }
                        }
                    } else {
                        completion(APIErrors.parseError, nil)
                    }
            }
        }
        
        ///Gets all posts from the currently signed in user
        static func getUserPosts(user: User, completion: @escaping (_ error: Error?, _ data: [Post]?) -> Void) {
            var posts = [Post]()
            
            database.collection("posts").whereField("user_id", isEqualTo: user.uid).whereField("status", isEqualTo: "active").getDocuments { (snapshot, error) in
                if let error = error {
                    completion(error, nil)
                    return
                }
                
                if let snapshot = snapshot {
                    print("Users Posts Count: ", snapshot.documents.count)
                    if snapshot.documents.count == 0 {
                        completion(nil, nil)
                    }
                    for query in snapshot.documents {
                        let data = query.data()
                        let postId = query.documentID
                        
                        if let postTitle = data["title"] as? String,
                            let postBody = data["body"] as? String,
                            let postType = data["post_type"] as? String,
                            let postServerType = data["server_type"] as? String,
                            let postPlatform = data["platform"] as? String,
                            let price = data["price"] as? String,
                            let created = data["created"] as? Int,
                            let userId = data["user_id"] as? String,
                            let fulfilledBy = data["fulfilled_by"] as? String,
                            let postSts = data["status"] as? String,
                            let imageCount = data["image_count"] as? Int,
                            let commentCount = data["comment_count"] as? Int {
                            
                            var serverType: ServerType?
                            var platform: Platform?
                            var postStatus: PostStatus?
                            var typeOfPost: PostType?
                            let dateCreated = Date(timeIntervalSince1970: TimeInterval(created))
                            for type in ServerType.allCases {
                                if type.rawValue.lowercased() == postServerType.lowercased() {
                                    serverType = type
                                }
                            }
                            
                            for platfrm in Platform.allCases {
                                if platfrm.rawValue.lowercased() == postPlatform.lowercased() {
                                    platform = platfrm
                                }
                            }
                            
                            for status in PostStatus.allCases {
                                if status.rawValue.lowercased() == postSts.lowercased() {
                                    postStatus = status
                                }
                            }
                            
                            for type in PostType.allCases {
                                if type.rawValue.lowercased() == postType.lowercased() {
                                    typeOfPost = type
                                }
                            }
                            let username = UserDefaults.standard.value(forKey: "username") as? String
                            var images = [UIImage]()
                            let folderRef = storage.reference(withPath: postId).child("1.png")
                            folderRef.getData(maxSize: 5 * 1024 * 1024, completion: { (data, error) in
                                if let imgData = data {
                                    if let newImage = UIImage(data: imgData) {
                                        images.append(newImage)
                                    }
                                }
                                
                                let newPost = Post(id: postId, title: postTitle, body: postBody, postType: typeOfPost, platform: platform, serverType: serverType, price: price, created: dateCreated, userId: userId, username: username, fulfilledBy: fulfilledBy, status: postStatus, commentCount: commentCount, images: images, imageCount: imageCount, searchText: "\(postTitle) \(postBody) \(price) \(username ?? "")")
                                
                                posts.append(newPost)
                                
                                
                                if posts.count == snapshot.documents.count {
                                    print("Image Completion")
                                    completion(nil, posts)
                                }
                            })
                            
                        } else { print("Parsing Error"); completion(APIErrors.parseError, nil) }
                    }
                } else {
                    completion(APIErrors.parseError, nil)
                }
            }
            
        }
    
        ///Creates a new post in Firestore
        static func createNewPost(forUser user: User, post: Post, completion: @escaping (_ error: Error?) -> Void) {
            let postData: [String: Any] = [ "title": post.title ?? "",
                                            "body" : post.body ?? "",
                                            "post_type" : post.postType?.rawValue ?? "",
                                            "server_type" : post.serverType?.rawValue ?? "",
                                            "platform" : post.platform?.rawValue ?? "",
                                            "price" : post.price ?? "",
                                            "created" : Int(post.created?.timeIntervalSince1970 ?? 0),
                                            "user_id" : user.uid,
                                            "fulfilled_by" : "",
                                            "status" : PostStatus.active.rawValue,
                                            "comment_count" : 0,
                                            "image_count" : post.images?.count ?? 0,
                                            "approved" : false]
            var imageData = [Data]()
            guard let images = post.images else {
                completion(APIErrors.noData) //TODO: API Error for Images
                return
            }
            for image in images {
                if let pngData = image.jpegData(compressionQuality: 1.0), let imgData = resizeImage(imageData: pngData, maxResolution: 1024, compression: 1.0) {
                    imageData.append(imgData)
                }
                
                //imageData.append(image.resizeToApprox(sizeInMB: 1.0))
            }
            
            var postRef: DocumentReference? = nil
            postRef = database.collection("posts").addDocument(data: postData) { (error) in
                if let error = error {
                    completion(error)
                } else {
                    if let postId = postRef?.documentID {
                        print("Post ID: ", postId)
                        for (index, pngData) in imageData.enumerated() {
                            let imageNumber = index
                            let storageReference = storage.reference().child(postId).child("\(imageNumber + 1).png")
                            let uploadTask = storageReference.putData(pngData, metadata: nil, completion: { (metadata, error) in
                                if let error = error {
                                    completion(error)
                                    return
                                }
                            })
                            observeUploadTaskFailureCases(uploadTask: uploadTask)
                        }
                        completion(nil)
                    } else { print("No Post ID") }
                    //completion(nil)
                }
                
            }
        }
        
        fileprivate static func observeUploadTaskFailureCases(uploadTask: StorageUploadTask){
            uploadTask.observe(.failure) { snapshot in
                if let error = snapshot.error as NSError? {
                    switch (StorageErrorCode(rawValue: error.code)!) {
                    case .objectNotFound:
                        print("File doesn't exist")
                        break
                    case .unauthorized:
                        print("User doesn't have permission to access file")
                        break
                    case .cancelled:
                        print("User canceled the upload")
                        break
                    case .unknown:
                        print("Unknown error occurred, inspect the server response")
                        break
                    default:
                        print("A separate error occurred, This is a good place to retry the upload.")
                        break
                    }
                }
            }
        }
        
        fileprivate static func observeDownloadTaskFailureCases(downloadTask: StorageDownloadTask) {
            downloadTask.observe(.failure) { snapshot in
                if let error = snapshot.error as NSError? {
                    switch (StorageErrorCode(rawValue: error.code)!) {
                    case .objectNotFound:
                        print("File doesn't exist")
                        break
                    case .unauthorized:
                        print("User doesn't have permission to access file")
                        break
                    case .cancelled:
                        print("User canceled the download")
                        break
                    case .unknown:
                        print("Unknown error occurred, inspect the server response")
                        break
                    default:
                        print("A separate error occurred, This is a good place to retry the upload.")
                        break
                    }
                }
            }
        }
    
        fileprivate static func getUserame(for post: Post, completion: @escaping (_ error: Error?, _ data: String?) -> Void) {
            guard let userId = post.userId else { completion(APIErrors.noUser, nil); return }
            database.collection("users").document(userId).getDocument { (documentSnapshot, error) in
                if let error = error {
                    completion(error, nil)
                    return
                }
                if let document = documentSnapshot {
                    let data = document.data()
                    if let username = data?["display_name"] as? String {
                        print(username)
                        completion(nil, username)
                        return
                    }
                } else { print("No Doc Data") }
            }
        }
        
        ///Gets all replies from the provided post
        static func getReplies(fromPost post: Post, completion: @escaping (_ error: Error?, _ data: [Reply]?) -> Void) {
            guard let postId = post.id else { completion(APIErrors.noPost, nil); return }
            //guard let userId = post.userId else { completion(APIErrors.noUser, nil); return }
            database.collection("posts").document(postId).collection("replies").getDocuments { (querySnapshot, error) in
                if let error = error { completion(error, nil); return }
                var replies = [Reply]()
                if let snapshot = querySnapshot?.documents {
                    for document in snapshot {
                        let data = document.data()
                        if let postId = post.id,
                            let body = data["body"] as? String,
                            let userId = data["user_id"] as? String,
                            let created = data["created"] as? Int {
                            
                            database.collection("users").document(userId).getDocument { (documentSnapshot, error) in
                                if let error = error {
                                    completion(error, nil)
                                    return
                                }
                                if let document = documentSnapshot, document.exists {
                                    let data = document.data()
                                    //print("Reply User ID: ", document.documentID)
                                    if let username = data?["display_name"] as? String {
                                        //print(username)
                                        let newReply = Reply(id: document.documentID, postId: postId, userId: userId, username: username, body: body, created: Date(timeIntervalSince1970: TimeInterval(created)))
                                        replies.append(newReply)
                                    } else { print("No Username Data")}
                                    completion(nil, replies)
                                } else { print("No Doc Data"); completion(nil, nil) }
                            }
                        }
                    }
                    
                }
                completion(nil, nil)
            }
        }
        
        ///Posts a reply to a post
        static func postReply(toPost post: Post, reply: Reply, user: User, completion: @escaping (_ error: Error?, _ reply: Reply?) -> Void) {
            guard let postId = post.id else { completion(APIErrors.noPost, nil); return }
            let replyData: [String: Any] = ["user_id" : user.uid,
                                            "body"    : reply.body ?? "",
                                            "created" : Int(Date().timeIntervalSince1970)]
            var replyRef: DocumentReference? = nil
            replyRef = database.collection("posts").document(postId).collection("replies").addDocument(data: replyData) { (error) in
                if let error = error {
                    completion(error, nil)
                }
                
                let newReply = Reply(id: replyRef?.documentID, postId: postId, userId: user.uid, body: reply.body, created: Date())
                completion(nil, newReply)
            }
        }
    }

    ///User related functions such as updating credentials, saving data, or signing out.
    enum Users {
        
        ///Re-Authenticate User in Auth() to update credentials
        static func reauthenticate(email: String, password: String, completion: @escaping (_ error: Error?, _ data: User?) -> Void) {
            guard let user = auth.currentUser else { completion(APIErrors.noUser, nil); return }
            let email = EmailAuthProvider.credential(withEmail: email, password: password)
            user.reauthenticateAndRetrieveData(with: email) { (results, error) in
                if let error = error {
                    completion(error, nil); return
                }
                
                if let userData = results {
                    completion(nil, userData.user)
                }
            }
        }
        
        ///Updates user password in Auth() table
        static func updatePassword(password: String, completion: @escaping(_ error: Error?) -> Void) {
            guard let _ = auth.currentUser else { completion(APIErrors.noUser); return }
            auth.currentUser?.updatePassword(to: password, completion: { (error) in
                if let error = error {
                    completion(error)
                } else {
                    completion(nil)
                }
            })
            
        }
        
        ///Update and save Users data in Firestore and Auth tables
        static func updateUsersData(for user: AppUser, completion: @escaping(_ error: Error?) -> Void) {
            guard let _ = auth.currentUser else { completion(APIErrors.noUser); return }
            guard let userId = user.id else { completion(APIErrors.noUser); return }
            guard let emailAddress = user.email else { completion(APIErrors.noUser); return }
            let updatedData: [String: Any] = ["display_name" : user.displayName ?? "",
                                              "email"        : user.email ?? "",
                                              "platform"     : user.platform?.rawValue ?? "",
                                              "server_type"  : user.serverType?.rawValue ?? ""]
            
            auth.currentUser?.updateEmail(to: emailAddress, completion: { (error) in
                if let error = error {
                    completion(error)
                    return
                }
            })
            
            database.collection("users").document(userId).updateData(updatedData) { (error) in
                if let error = error {
                    completion(error)
                    return
                }
            }
            
            completion(nil)
        }
        
        ///Saves Users data locally
        static func saveUserDataLocally(for user: AppUser, completion: @escaping(_ error: Error?) -> Void) {
            userDefaults.set(user.displayName, forKey: "username")
            userDefaults.set(user.id, forKey: "userId")
            userDefaults.set(user.email, forKey: "emailAddress")
            userDefaults.set(user.enabled, forKey: "enabled")
            userDefaults.set(user.platform?.rawValue, forKey: "platform")
            userDefaults.set(user.serverType?.rawValue, forKey: "serverType")
            userDefaults.set(user.type, forKey: "type")
            print("***UserDefaults set from 'saveUserDataLocally'***")
            completion(nil)
        }
        
        ///Loads all local user data
        static func loadLocalUserData(completion: @escaping (_ error: Error?, _ user: AppUser?) -> Void) {
            if let userId = userDefaults.value(forKey: "userId") as? String,
                let displayName = userDefaults.value(forKey: "username") as? String,
                let emailAddress = userDefaults.value(forKey: "emailAddress") as? String,
                let enabled = userDefaults.value(forKey: "enabled") as? Bool,
                let platformStr = userDefaults.value(forKey: "platform") as? String,
                let serverStr = userDefaults.value(forKey: "serverType") as? String,
                let type = userDefaults.value(forKey: "type") as? String {
                
                var platform: Platform?
                var server: ServerType?
                
                for pltfrm in Platform.allCases where platformStr.lowercased().elementsEqual(pltfrm.rawValue.lowercased()){
                    platform = pltfrm
                }
                
                for svr in ServerType.allCases where serverStr.lowercased().elementsEqual(svr.rawValue.lowercased()) {
                    server = svr
                }
                
                let returnedData = AppUser(id: userId, displayName: displayName, email: emailAddress, password: nil, platform: platform, serverType: server, type: type, enabled: enabled)
                completion(nil, returnedData)
            } else {
                print("***Error reading UserDefaults in 'localLocalUserData' API call***")
                completion(APIErrors.userDataError, nil)
            }
        }
        
        ///Updates the current users password.  Re-authentication is required.
        static func changePassword(to password: String, completion: @escaping (_ error: Error?) -> Void) {
            guard let currentUser = auth.currentUser else { completion(APIErrors.noUser); return }
            
            currentUser.updatePassword(to: password) { (error) in
                if let error = error {
                    print("Update Password Error: ", error)
                    completion(error)
                    return
                } else {
                    completion(nil)
                }
            }
        }
        
        ///Resets the password for the provided user associated with the provided email address.
        static func sendPasswordReset(to email: String, completion: @escaping (_ error: Error?) -> Void) {
            auth.sendPasswordReset(withEmail: email) { (error) in
                if let error = error {
                    completion(error)
                } else {
                    completion(nil)
                }
            }
        }
    
        ///Signs the current user out if they are currently signed in
        static func signOut(completion: @escaping (_ error: Error?) -> Void) {
            guard let userId = auth.currentUser?.uid else { completion(APIErrors.noUser); return }
            guard let deviceId = UIDevice.current.identifierForVendor?.uuidString else { completion(APIErrors.userDataError); return }
            
            userDefaults.removeObject(forKey: "userId")
            userDefaults.removeObject(forKey: "username")
            userDefaults.removeObject(forKey: "emailAddress")
            userDefaults.removeObject(forKey: "enabled")
            userDefaults.removeObject(forKey: "platform")
            userDefaults.removeObject(forKey: "serverType")
            userDefaults.removeObject(forKey: "type")
            print("User Defaults Cleared")
            
            database.collection("users").document(userId).collection("fcm_tokens").document(deviceId).delete { (error) in
                if let error = error {
                    completion(error)
                    return
                }
                print("signed out")
                do {
                    try auth.signOut()
                    completion(nil)
                } catch {
                    completion(error)
                }

            }
            
            
        }
        
        ///Submit app feedback to Firestore.
        static func submitFeedback(feedback: Feedback, completion: @escaping (_ error: Error?) -> Void) {
            guard let userId = UserDefaults.standard.value(forKey: "userId") as? String else { completion(APIErrors.noUser); return }
            let feedback: [String: Any] = ["user_id"      : userId,
                                           "display_name" : feedback.username ?? "" ,
                                           "email"        : feedback.email ?? "",
                                           "feeback"      : feedback.body,
                                           "timestamp"         : Int(Date().timeIntervalSince1970)]
            database.collection("feedback").addDocument(data: feedback) { (error) in
                if let error = error {
                    completion(error)
                    return
                } else {
                    completion(nil)
                }
            }
        }
    
        ///Updates the FCM token for the signed in user.
        static func updateFcmToken(for user: User, token: String, completion: @escaping (_ error: Error?) -> Void) {
            guard let deviceId = UIDevice.current.identifierForVendor?.uuidString else { completion(APIErrors.userDataError); return }
            let docData: [String: Any] = ["fcm_token" : token,
                           "last_updated" : Int(Date().timeIntervalSince1970)]
            let tokenRecord = database.collection("users").document(user.uid).collection("fcm_tokens").document(deviceId)
            tokenRecord.setData(docData) { (error) in
                if let error = error {
                    completion(error)
                } else {
                    print("FCM Token Updated")
                    completion(nil)
                }
            }
        }
 
        ///Creates rating for user
        static func addRating(for user: User?, post: Post, completion: @escaping (_ error: Error?) -> Void) {
            guard let raterId = user?.uid, let postId = post.id, let userId = post.userId else { completion(APIErrors.noData); return }
            let postdata: [String: Any] = [ "created"    : Int(Date().timeIntervalSince1970),
                                            "post_id"    : postId,
                                            "rated_by"   : raterId,
                                            "successful" : true,
                                            "user_id"    : userId ]
            database.collection("ratings").addDocument(data: postdata) { (error) in
                if let error = error {
                    completion(error)
                    return
                } else {
                    completion(nil)
                }
                
            }
        }
    
    
    }

    ///Notificaiton related methods such as saving notification data.
    enum Notifications {
        
        ///Save Push Notification to CoreData
        static func saveNotification(notification: NotificationHolder, completion: @escaping (_ error: Error?) -> Void) {
            if let newNotification = NSEntityDescription.insertNewObject(forEntityName: "PushNotification", into: managedContext) as? PushNotification {
                newNotification.body = notification.body
                newNotification.postId = notification.postId
                newNotification.title = notification.title
                newNotification.type = notification.type
                newNotification.date = notification.date
                do {
                    try managedContext.save()
                    print("Push Notification Saved")
                    completion(nil)
                } catch {
                    completion(error)
                }
            }
        }
        
        static func deleteNotification(for post: Post, completion: @escaping (_ error: Error?) -> Void) {
            guard let postId = post.id else { completion(APIErrors.noPost); return }
            let fetchRequest = NSFetchRequest<PushNotification>(entityName: "PushNotification")
            do {
                let notifications = try managedContext.fetch(fetchRequest)
                for notification in notifications {
                    guard let notificationId = notification.postId else { completion(APIErrors.noPost); return }
                    if notificationId.elementsEqual(postId) {
                        managedContext.delete(notification)
                        try? managedContext.save()
                        completion(nil)
                    }
                }
            } catch {
                completion(error)
            }
        }
        
    }

}
