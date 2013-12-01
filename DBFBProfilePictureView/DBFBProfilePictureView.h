/*
 * Copyright 2012
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <UIKit/UIKit.h>
#import <FacebookSDK/FacebookSDK.h>

@class DBFBProfilePictureView;
typedef void (^DBFBProfilePictureViewStartHandler)(DBFBProfilePictureView *profilePictureView);
typedef void (^DBFBProfilePictureViewHandler)(DBFBProfilePictureView *profilePictureView, NSError *error);

@interface DBFBProfilePictureView : UIView

/**
 The facebook profile id for the user picture that you want to load.
 */
@property (copy) NSString* profileID;

/**
 The cropping type you want for the picture, the enum is defined in the facebook SDK.
 */
@property FBProfilePictureCropping pictureCropping;

/**
 A block that gets called before the download of a profile picture begins.
 */
@property (strong) DBFBProfilePictureViewStartHandler startHandler;

/**
 A block that gets called when the download of a profile picture completes.
 If an error occurs then it is returned here.
 */
@property (strong) DBFBProfilePictureViewHandler completionHandler;

/**
 Set whether the empty profile picture gets shown when the profileID is nil.
 Defaults to NO
 */
@property BOOL showEmptyImage;

/**
 Override the image that gets shown when the profileID is nil. Set it to nil to 
 return to the default empty image.
 */
@property (strong) UIImage *emptyImage;


/*
 Initialisers to make sure the class caches images beyond their lifetime
 Use of these initialisers is ideal if the class is being used in a UITableViewCell
 Pass 0 Max Cached Images to have no maximum
 */
- (id)initAndCacheImagesBeyondTheirLifetimeMaxImagesCached:(NSUInteger)maxCache;
- (id)initWithFrame:(CGRect)frame cacheImagesBeyondTheirLifetimeMaxImagesCached:(NSUInteger)maxCache;

@end
