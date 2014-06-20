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
 Exposes the internal imageView for inspection of its contents
 */
@property (nonatomic, readonly) UIImageView* imageView;

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

/**
 *  Use this method to change the default caching behaviour of DBFBProfilePictureView
 *  By default, DBFBProfilePictureView caches only the currently visible images
 *  By calling this class method with maxImagesCachedBeyondLifetime>0, you will 
 *  enable caching of images beyond the lifetime of the view displaying them
 *  Calling with maxImagesCachedBeyondLifetime == 0 reverts to the default behavior
 */
+ (void)setMaxImagesCachedBeyondLifetime:(NSInteger)maxImagesCachedBeyondLifetime;

/**
 * Access the maximum cache size
 */
+ (NSInteger)maxImagesCachedBeyondLifetime;

/**
 * Enable disk cache.
 * If cache is enabled DBFBProfilePictureView will try to find localy
 * downloaded copy of image. If image doesn't exists it will download
 * it and save localy. You can manipulate cache life time with 'lifetime'
 * parameter.
 */
+ (void)enableDiskCache:(BOOL)enable lifetime:(NSTimeInterval)lifetime;

@end
