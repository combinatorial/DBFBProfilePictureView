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

#import <AFNetworking/AFNetworking.h>
#include <CommonCrypto/CommonDigest.h>

@interface DBFBProfilePictureRequestPrivate : NSObject

//#define USE_AFNETWORKING_2
#ifdef USE_AFNETWORKING_2
@property (strong,nonatomic) AFHTTPRequestOperation* requestOperation;
#else
@property (strong,nonatomic) AFImageRequestOperation* requestOperation;
#endif
@property (strong,nonatomic) NSMutableSet* requestorsToUpdate;

@end

@implementation DBFBProfilePictureRequestPrivate

- (id)initWithProfilePictureView:(DBFBProfilePictureView*)view
{
    self = [super init];
    if(self) {
        _requestorsToUpdate = [NSMutableSet setWithObject:view];
    }
    return self;
}

@end

@interface DBFBProfilePictureCachePrivate : NSObject

@property (nonatomic, readonly) UIImage* imageObject;
@property (nonatomic, strong) NSDate *lastUsed;

@end

@implementation DBFBProfilePictureCachePrivate
{
    __strong UIImage *_strongImage;
    __weak UIImage *_weakImage;
}

- (id)initWithImage:(UIImage*)image weakCaching:(BOOL)weak
{
    self = [super init];
    if(self) {
        if (weak) {
            _weakImage = image;
        } else {
            _strongImage = image;
        }
        _lastUsed = [NSDate date];
    }
    return self;
}

- (UIImage *)imageObject
{
    if (_weakImage != nil) {
        return _weakImage;
    } else {
        return _strongImage;
    }
}

@end

@interface DBFBProfilePictureView()

@property (readonly, nonatomic) NSDictionary *imageQueryParam;
@property (strong, nonatomic) NSDictionary *previousImageQueryParam;
@property (strong, nonatomic) UIImageView *imageView;
@property (strong, nonatomic) NSURL *url;

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
    [self removeObserver:self forKeyPath:@"showEmptyImage"];
    [self removeObserver:self forKeyPath:@"emptyImage"];
}

#pragma mark -

- (NSDictionary *)imageQueryParam {
    static CGFloat screenScaleFactor = 0.0;
    if (screenScaleFactor == 0.0) {
        screenScaleFactor = [[UIScreen mainScreen] scale];
    }
    
    // Retina display doesn't increase the bounds that iOS returns.  The larger size to fetch needs
    // to be calculated using the scale factor accessed above.
    int width = (int)(self.bounds.size.width * screenScaleFactor);
    
    if (self.pictureCropping == FBProfilePictureCroppingSquare) {
        
        if(width == 0) {
            return nil;
        }
        
        return @{
                     @"width" :  [NSString stringWithFormat:@"%d",width],
                     @"height" : [NSString stringWithFormat:@"%d",width],
                 };
    }
    
    // For non-square images, we choose between three variants knowing that the small profile picture is
    // 50 pixels wide, normal is 100, and large is about 200.
    if (width <= 50) {
        return @{@"type":@"small"};
    } else if (width <= 100) {
        return @{@"type":@"normal"};
    } else {
        return @{@"type":@"large"};
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
    [self addObserver:self forKeyPath:@"showEmptyImage" options:NSKeyValueObservingOptionNew context:nil];
    [self addObserver:self forKeyPath:@"emptyImage" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if([keyPath isEqualToString:@"profileID"] || [keyPath isEqualToString:@"pictureCropping"] || [keyPath isEqualToString:@"showEmptyImage"] || [keyPath isEqualToString:@"emptyImage"]) {
        [self refreshImage:YES];
    }
}

+ (NSOperationQueue *)sharedProfileImageRequestOperationQueue
{
    static NSOperationQueue *_profileImageRequestOperationQueue = nil;
    
    static dispatch_once_t done;
    dispatch_once(&done, ^{
        _profileImageRequestOperationQueue = [[NSOperationQueue alloc] init];
        [_profileImageRequestOperationQueue setMaxConcurrentOperationCount:2];
    });
    
    return _profileImageRequestOperationQueue;
}

+ (NSMutableDictionary *)sharedCacheDictionary
{
    static NSMutableDictionary *_sharedCacheDictionary = nil;
    
    static dispatch_once_t done;
    dispatch_once(&done, ^{
        _sharedCacheDictionary = [[NSMutableDictionary alloc] init];
    });
    
    return _sharedCacheDictionary;
}

static NSInteger _maxImagesCachedBeyondLifetime = 0;
static NSTimeInterval _diskCacheLifetime = 0;
static BOOL _diskCacheEnabled = NO;

+ (void)enableDiskCache:(BOOL)enable lifetime:(NSTimeInterval)lifetime
{
    _diskCacheEnabled = enable;
    _diskCacheLifetime = lifetime;
}

+ (BOOL)shouldCacheImageBeyondLifetime
{
    return _maxImagesCachedBeyondLifetime > 0;
}

+ (NSInteger)maxImagesCachedBeyondLifetime
{
    return _maxImagesCachedBeyondLifetime;
}

+ (void)setMaxImagesCachedBeyondLifetime:(NSInteger)maxImagesCachedBeyondLifetime
{
    NSAssert(maxImagesCachedBeyondLifetime >= 0, @"Error: maxImagesCachedBeyondLifetime must be zero or greater");
    if (maxImagesCachedBeyondLifetime != _maxImagesCachedBeyondLifetime) {
        if (_maxImagesCachedBeyondLifetime == 0 || maxImagesCachedBeyondLifetime == 0) {
            // clear the cache if we have changed from weak to strong caching
            NSMutableDictionary *cache = [self.class sharedCacheDictionary];
            @synchronized(cache) {
                [cache removeAllObjects];
            }
        }
        _maxImagesCachedBeyondLifetime = maxImagesCachedBeyondLifetime;
    }
}

static BOOL cleanupScheduled = NO;

- (void)cleanCache
{
    BOOL needCleanup = NO;
    
    NSMutableDictionary *cache = [self.class sharedCacheDictionary];
    
    @synchronized(cache) {
        if(!cleanupScheduled) {
            needCleanup = YES;
            cleanupScheduled = YES;
        }
    }

    if(needCleanup) {
        //clean up the cache some time later (30 seconds), it only depends on class methods
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30ull * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            
            @synchronized(cache) {

                cleanupScheduled = NO;
                BOOL cacheBeyondLifetime = [[self class] shouldCacheImageBeyondLifetime];
                
                if (!cacheBeyondLifetime) {
                    for (NSString *key in cache.allKeys) {
                        DBFBProfilePictureCachePrivate *cachedItem = cache[key];
                        if(cachedItem.imageObject == nil) {
                            [cache removeObjectForKey:key];
                        }
                    }
                } else {
                    
                    NSInteger maxImagesCached = [[self class] maxImagesCachedBeyondLifetime];
                    //go through cache and delete oldest items if we have too many of them
                    if (cache.count > maxImagesCached) {
                        //sort cache key by oldest items first
                        NSArray *sortedKeys = [cache keysSortedByValueUsingComparator:^NSComparisonResult(DBFBProfilePictureCachePrivate *obj1, DBFBProfilePictureCachePrivate *obj2) {
                            return [obj1.lastUsed compare:obj2.lastUsed];
                        }];
                        
                        NSMutableArray *sortedKeysTruncated = sortedKeys.mutableCopy;
                        [sortedKeysTruncated removeObjectsInRange:NSMakeRange(cache.count - maxImagesCached, maxImagesCached)];
                        [cache removeObjectsForKeys:sortedKeysTruncated];
                    }
                }

                NSFileManager *fileManager = [NSFileManager defaultManager];
                NSArray *contents = [fileManager contentsOfDirectoryAtURL:[NSURL fileURLWithPath:[self diskCacheRoot]]
                                               includingPropertiesForKeys:@[]
                                                                  options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                    error:nil];
                NSDate *today = [NSDate date];
                for (NSURL *fileURL in contents) {
                    NSDate *expirationDate = nil;
                    NSDictionary *attributes = [fileManager attributesOfItemAtPath:[fileURL path] error:nil];
                    expirationDate = [attributes[NSFileCreationDate] dateByAddingTimeInterval:_diskCacheLifetime];

                    if ([expirationDate compare:today] == NSOrderedAscending) {
                        [fileManager removeItemAtURL:fileURL error:nil];
                    }
                }

            }
        });
    }
}

- (void)cacheImage:(UIImage*)image forURL:(NSURL*)url
{
    [self cleanCache];
    
    BOOL cacheBeyondLifetime = [[self class] shouldCacheImageBeyondLifetime];
    DBFBProfilePictureCachePrivate *cachedItem = [[DBFBProfilePictureCachePrivate alloc] initWithImage:image weakCaching:!cacheBeyondLifetime];

    NSMutableDictionary *cache = [self.class sharedCacheDictionary];
    @synchronized(cache) {
        [cache setObject:cachedItem forKey:url];
        if (_diskCacheEnabled) {
            [UIImagePNGRepresentation(image) writeToFile:[self filePathForCachedImage:url] atomically:YES];
        }
    }
}

- (NSString *)diskCacheRoot
{
    NSString *cacheDir = @"DBFBProfilePictureViewCache";
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    return [documentsPath stringByAppendingPathComponent:cacheDir];
}

- (NSString *)getMD5FromString:(NSString *)source
{
	const char *src = [source UTF8String];
	unsigned char result[CC_MD5_DIGEST_LENGTH];
	CC_MD5(src, strlen(src), result);
    NSString *ret = [NSString stringWithFormat:@"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
					 result[0], result[1], result[2], result[3],
					 result[4], result[5], result[6], result[7],
					 result[8], result[9], result[10], result[11],
					 result[12], result[13], result[14], result[15]
					 ];
    return [ret lowercaseString];
}

- (NSString *)filePathForCachedImage:(NSURL *)url
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *imagesPath = [self diskCacheRoot];

    if (![fileManager fileExistsAtPath:imagesPath]) {
        [fileManager createDirectoryAtPath:imagesPath withIntermediateDirectories:YES attributes:nil error:nil];
    }

    return [NSString stringWithFormat:@"%@/%@.png", imagesPath,[self getMD5FromString:[url absoluteString]]];
}

- (BOOL)localyCachedImageExists:(NSURL *)url
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filePath = [self filePathForCachedImage:url];
    return [fileManager fileExistsAtPath:filePath];
}
- (UIImage*)cachedImageForURL:(NSURL*)url
{
    [self cleanCache];

    if (_diskCacheEnabled && [self localyCachedImageExists:url]) {
        NSData *restoredData = [NSData dataWithContentsOfFile:[self filePathForCachedImage:url]];
        if (restoredData != nil) {
            return [UIImage imageWithData:restoredData];
        }
    }

    NSMutableDictionary *cache = [self.class sharedCacheDictionary];

    @synchronized(cache) {
        UIImage* cachedImage = nil;
        DBFBProfilePictureCachePrivate* cachedItem = [cache objectForKey:url];
        if(cachedItem != nil) {
            cachedItem.lastUsed = [NSDate date];
            cachedImage = cachedItem.imageObject;
            if(cachedImage == nil) {
                [cache removeObjectForKey:url];
            }
        }
        
        return cachedImage;
    }
}

+ (NSMutableDictionary *)sharedImageRequestDictionary
{
    static NSMutableDictionary *_sharedImageRequestDictionary = nil;
    
    static dispatch_once_t done;
    dispatch_once(&done, ^{
        _sharedImageRequestDictionary = [[NSMutableDictionary alloc] init];
    });
    
    return _sharedImageRequestDictionary;
}

- (void)imageDownloadComplete:(UIImage*)image forURL:(NSURL*)url
{    
    NSMutableDictionary* requestsInProgress = [[self class] sharedImageRequestDictionary];
    DBFBProfilePictureRequestPrivate *pictureRequest = nil;
    @synchronized(requestsInProgress) {
        pictureRequest = [requestsInProgress objectForKey:url];
        [requestsInProgress removeObjectForKey:url];
    }
    [self cacheImage:image forURL:url];
    for(DBFBProfilePictureView* pictureView in pictureRequest.requestorsToUpdate) {
        pictureView.imageView.image = image;
        [pictureView ensureImageViewContentMode];
        if(pictureView.completionHandler != nil) {
            pictureView.completionHandler(pictureView, nil);
        }
    }
}

- (void)removeFromRequestorsList
{
    if (self.url) {
        NSMutableDictionary* requestsInProgress = [[self class] sharedImageRequestDictionary];
        DBFBProfilePictureRequestPrivate *pictureRequest = nil;
        @synchronized(requestsInProgress) {
            pictureRequest = [requestsInProgress objectForKey:self.url];
            [pictureRequest.requestorsToUpdate removeObject:self];
            if (pictureRequest.requestorsToUpdate.count == 0) {
                [requestsInProgress removeObjectForKey:self.url];
                [pictureRequest.requestOperation cancel];
            }
        }
        self.url = nil;
    }
}

- (void)imageDownloadFailedForURL:(NSURL*)url withError:(NSError*)error
{
    NSMutableDictionary* requestsInProgress = [[self class] sharedImageRequestDictionary];
    DBFBProfilePictureRequestPrivate *pictureRequest = nil;
    @synchronized(requestsInProgress) {
        pictureRequest = [requestsInProgress objectForKey:url];
        [requestsInProgress removeObjectForKey:url];
    }
    
    for(DBFBProfilePictureView* pictureView in pictureRequest.requestorsToUpdate) {
        if(pictureView.completionHandler != nil) {
            pictureView.completionHandler(self, error);
        }
    }
}

- (void)requestImageDownload:(NSURL*)url
{
    self.url = url;
    NSMutableDictionary* requestsInProgress = [[self class] sharedImageRequestDictionary];
    DBFBProfilePictureRequestPrivate *pictureRequest = nil;
    @synchronized(requestsInProgress) {
        
        pictureRequest = [requestsInProgress objectForKey:url];
        
        if(pictureRequest != nil) {
            [pictureRequest.requestorsToUpdate addObject:self];
            pictureRequest = nil;
        } else {
            pictureRequest = [[DBFBProfilePictureRequestPrivate alloc] initWithProfilePictureView:self];
            [requestsInProgress setObject:pictureRequest forKey:url];
        }
    }
    
    if(pictureRequest) {

        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];
        [request setHTTPShouldHandleCookies:NO];
        [request setHTTPShouldUsePipelining:YES];
 
#ifdef USE_AFNETWORKING_2
        AFHTTPRequestOperation* requestOperation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
        requestOperation.responseSerializer = [AFImageResponseSerializer serializer];
        [requestOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
            [self imageDownloadComplete:responseObject forURL:url];
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            [self imageDownloadFailedForURL:url withError:error];
        }];
#else
        
        AFImageRequestOperation* requestOperation = [AFImageRequestOperation imageRequestOperationWithRequest:request
                                                                                         imageProcessingBlock:nil
                                                                                                      success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image){
                                                                                                          [self imageDownloadComplete:image forURL:url];
                                                                                                      }
                                                                                                      failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError* error){
                                                                                                          [self imageDownloadFailedForURL:url withError:error];
                                                                                                      }];
#endif
        
        [[[self class] sharedProfileImageRequestOperationQueue] addOperation:requestOperation];
        pictureRequest.requestOperation = requestOperation;
    }
    
    if(self.startHandler != nil) {
        self.startHandler(self);
    }
}

- (void)refreshImage:(BOOL)forceRefresh
{
    NSDictionary *newImageQueryParam = self.imageQueryParam;
    
    // If not forcing refresh, check to see if the previous size we used would be the same
    // as what we'd request now, as this method could be called often on control bounds animation,
    // and we only want to fetch when needed.
    if (!forceRefresh && [self.previousImageQueryParam isEqualToDictionary:newImageQueryParam]) {
        
        // But we still may need to adjust the contentMode.
        [self ensureImageViewContentMode];
        return;
    }
    
    self.imageView.image = nil;
    BOOL showEmptyImage = self.showEmptyImage;
    
    if (self.profileID && newImageQueryParam) {
        
        [self removeFromRequestorsList];
        
        // Create the request to let the Facebook SDK handle the URL
        NSString *graphPath = [NSString stringWithFormat:@"%@/picture",self.profileID];
        FBRequest *fbRequest = [[FBRequest alloc] initWithSession:nil graphPath:graphPath parameters:newImageQueryParam HTTPMethod:nil];
        FBRequestConnection *requestConnection = [[FBRequestConnection alloc] init];
        [requestConnection addRequest:fbRequest completionHandler:nil];
        
        
        // Get the url
        NSURL *url = requestConnection.urlRequest.URL;
        
        
        UIImage* cachedImage = [self cachedImageForURL:url];
        
        if(cachedImage != nil) {
            showEmptyImage = NO;
            self.imageView.image = cachedImage;
            [self ensureImageViewContentMode];
            if(self.completionHandler != nil) {
                self.completionHandler(self, nil);
            }
        } else {
        
            [self requestImageDownload:url];
        }

    }
    
    if(showEmptyImage) {
        if (self.emptyImage == nil) {
         
            BOOL isSquare = (self.pictureCropping == FBProfilePictureCroppingSquare);
            
            NSString *blankImageName = [NSString stringWithFormat:@"FacebookSDKResources.bundle/FBProfilePictureView/images/fb_blank_profile_%@.png",
                                        isSquare ? @"square" : @"portrait"];
            _emptyImage = [UIImage imageNamed:blankImageName];
        }
        
        self.imageView.image = self.emptyImage;
        [self ensureImageViewContentMode];
    }
    
    self.previousImageQueryParam = newImageQueryParam;
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
