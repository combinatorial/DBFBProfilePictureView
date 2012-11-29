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

#import "DBFBProfilePictureView.h"

#import "FBSDKVersion.h"  //for FB_IOS_SDK_MIGRATION_BUNDLE

#import <AFNetworking/AFNetworking.h>

@interface DBFBProfilePictureView()

@property (readonly, nonatomic) NSString *imageQueryParamString;
@property (strong, nonatomic) NSString *previousImageQueryParamString;
@property (strong, nonatomic) UIImageView *imageView;

@property (strong) AFImageRequestOperation* imageRequestOperation;

@end

@implementation DBFBProfilePictureView

#pragma mark - Lifecycle

- (id)init {
    self = [super init];
    if (self) {
        [self initialize];
    }
    
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self initialize];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self initialize];
    }
    return self;
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:@"profileID"];
    [self removeObserver:self forKeyPath:@"pictureCropping"];
}

#pragma mark -

- (NSString *)imageQueryParamString  {
    
    static CGFloat screenScaleFactor = 0.0;
    if (screenScaleFactor == 0.0) {
        screenScaleFactor = [[UIScreen mainScreen] scale];
    }
    
    // Retina display doesn't increase the bounds that iOS returns.  The larger size to fetch needs
    // to be calculated using the scale factor accessed above.
    int width = (int)(self.bounds.size.width * screenScaleFactor);
    
    if (self.pictureCropping == FBProfilePictureCroppingSquare) {
        
        if(width == 0) {
            return @"";
        }
        
        return [NSString stringWithFormat:@"width=%d&height=%d&migration_bundle=%@",
                width,
                width,
                FB_IOS_SDK_MIGRATION_BUNDLE];
    }
    
    // For non-square images, we choose between three variants knowing that the small profile picture is
    // 50 pixels wide, normal is 100, and large is about 200.
    if (width <= 50) {
        return @"type=small";
    } else if (width <= 100) {
        return @"type=normal";
    } else {
        return @"type=large";
    }
}

- (void)initialize {
    // the base class can cause virtual recursion, so
    // to handle this we make initialize idempotent
    if (self.imageView) {
        return;
    }
    
    UIImageView* imageView = [[UIImageView alloc] initWithFrame:self.bounds];
    imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.imageView = imageView;
    
    self.autoresizesSubviews = YES;
    self.clipsToBounds = YES;
    
    [self addSubview:self.imageView];
    
    [self addObserver:self forKeyPath:@"profileID" options:NSKeyValueObservingOptionNew context:nil];
    [self addObserver:self forKeyPath:@"pictureCropping" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if([keyPath isEqualToString:@"profileID"] || [keyPath isEqualToString:@"pictureCropping"]) {
        [self refreshImage:YES];
    }
}

+ (NSOperationQueue *)sharedProfileImageRequestOperationQueue {
    
    static NSOperationQueue *_profileImageRequestOperationQueue = nil;
    
    static dispatch_once_t done;
    dispatch_once(&done, ^{
        _profileImageRequestOperationQueue = [[NSOperationQueue alloc] init];
        [_profileImageRequestOperationQueue setMaxConcurrentOperationCount:2];
    });
    
    return _profileImageRequestOperationQueue;
}

- (void)refreshImage:(BOOL)forceRefresh  {
    NSString *newImageQueryParamString = self.imageQueryParamString;
    
    // If not forcing refresh, check to see if the previous size we used would be the same
    // as what we'd request now, as this method could be called often on control bounds animation,
    // and we only want to fetch when needed.
    if (!forceRefresh && [self.previousImageQueryParamString isEqualToString:newImageQueryParamString]) {
        
        // But we still may need to adjust the contentMode.
        [self ensureImageViewContentMode];
        return;
    }
    
    if (self.profileID && newImageQueryParamString.length > 0) {
        
        NSString *template = @"%@/%@/picture?%@";
        NSString *urlString = [NSString stringWithFormat:template,
                               FBGraphBasePath,
                               self.profileID,
                               newImageQueryParamString];
        NSURL *url = [NSURL URLWithString:urlString];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];
        [request setHTTPShouldHandleCookies:NO];
        [request setHTTPShouldUsePipelining:YES];
        
        [self.imageRequestOperation cancel];
        self.imageRequestOperation = nil;
        
        AFImageRequestOperation* requestOperation = [AFImageRequestOperation imageRequestOperationWithRequest:request
                                                                                         imageProcessingBlock:nil
                                                                                                      success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image){
                                                                                                          self.imageRequestOperation = nil;
                                                                                                          self.imageView.image = image;
                                                                                                          [self ensureImageViewContentMode];
                                                                                                          if(self.completionHandler != nil) {
                                                                                                              self.completionHandler(self, nil);
                                                                                                          }
                                                                                                      }
                                                                                                      failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError* error){
                                                                                                          self.imageRequestOperation = nil;
                                                                                                          if(self.completionHandler != nil) {
                                                                                                              self.completionHandler(self, error);
                                                                                                          }
                                                                                                      }];
        
        self.imageRequestOperation = requestOperation;
        
        
        if(self.startHandler != nil) {
            self.startHandler(self);
        }
        
        [[[self class] sharedProfileImageRequestOperationQueue] addOperation:self.imageRequestOperation];
        

    } else if(self.showEmptyImage) {
        BOOL isSquare = (self.pictureCropping == FBProfilePictureCroppingSquare);
        
        NSString *blankImageName = [NSString stringWithFormat:@"FacebookSDKResources.bundle/FBProfilePictureView/images/fb_blank_profile_%@.png",
                                    isSquare ? @"square" : @"portrait"];
        
        self.imageView.image = [UIImage imageNamed:blankImageName];
        [self ensureImageViewContentMode];
    }
    
    self.previousImageQueryParamString = newImageQueryParamString;
}

- (void)ensureImageViewContentMode {
    // Set the image's contentMode such that if the image is larger than the control, we scale it down, preserving aspect
    // ratio.  Otherwise, we center it.  This ensures that we never scale up, and pixellate, the image.
    CGSize viewSize = self.bounds.size;
    CGSize imageSize = self.imageView.image.size;
    UIViewContentMode contentMode;
    
    // If both of the view dimensions are larger than the image, we'll center the image to prevent scaling up.
    // Note that unlike in choosing the image size, we *don't* use any Retina-display scaling factor to choose centering
    // vs. filling.  If we were to do so, we'd get profile pics shrinking to fill the the view on non-Retina, but getting
    // centered and clipped on Retina.
    if (viewSize.width > imageSize.width && viewSize.height > imageSize.height) {
        contentMode = UIViewContentModeCenter;
    } else {
        contentMode = UIViewContentModeScaleAspectFit;
    }
    
    self.imageView.contentMode = contentMode;
}

// Lets us catch resizes of the control, or any outer layout, allowing us to potentially
// choose a different image.
- (void)layoutSubviews {
    [self refreshImage:NO];
    [super layoutSubviews];
}


@end
