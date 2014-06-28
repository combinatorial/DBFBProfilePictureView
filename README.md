## DBFBProfilePictureView - an improved view for facebook profile pictures

There were a number of things I wanted to fix with the Facebook provided FBProfilePictureView:

* Caching of the downloaded profile images, so the network did not get hit for every instance of the view
* Start and completion handlers to allow control of the presentation of the view (e.g. fade-in or show a UIActivityIndicatorView)
* Be notified when the download fails
* Control of when the empty profile image got shown
* Work well when the view is embedded in a UITableCellView

In addition there are a couple of other significant changes:

* The implementation has been converted to ARC
* key/value observing is used to monitor changes to profileID and pictureCropping
* no download request is made for zero size images

## Installation

The simplest way to install DBFBProfilePictureView is to use [CocoaPods](http://cocoapods.org).
The homepage has a quick start guide. Add the following to your Podfile:

		platform :ios, '5.0'
		pod 'DBFBProfilePictureView'
		
This will then automatically handle the dependencies. Also, it is a simple way to get updates.

If you want to take the manual approach then the two files needed are in the sub-directory DBFBProfilePictureView.
To build them you will also need AFNetworking 1.0 or later and the Facebook iOS SDK v3.1.1.
Either your project needs to be built with ARC enabled, or you will need to set the
-fobjc-arc flag as described [here](http://www.codeography.com/2011/10/10/making-arc-and-non-arc-play-nice.html).

## Getting Started

A typical usage of the view might look like this...

Declare the property in a view controller or UITableCellView:

```objc
    @property(strong) DBFBProfilePictureView* facebookPictureView;
```

Import QuartzCore as we will be using CALayer:

```objc
    #import <QuartzCore/QuartzCore.h>
```

Initialize the property in viewDidLoad of your view controller or init of your UITableCellView:

```objc
        self.facebookPictureView = [[DBFBProfilePictureView alloc] initWithFrame:CGRectMake(x,y,width,height)];
        //hide the view when the download starts
        self.facebookPictureView.startHandler = ^(DBFBProfilePictureView* view){
            view.layer.opacity = 0.0f;
        };
        //show the view when the download completes, or show the empty image
        self.facebookPictureView.completionHandler = ^(DBFBProfilePictureView* view, NSError* error){
            if(error) {
                view.showEmptyImage = YES;
                view.profileID = nil;
                NSLog(@"Loading profile picture failed with error: %@", error);
            } 
            [UIView animateWithDuration:0.5f animations:^{
                view.layer.opacity = 1.0f;
            }];
        };
```

Set the profileID when you know it:

```objc
		facebookPictureView.profileID = xxxxx;
```

You can enable in-memory image caching support by calling:

```objc
		[DBFBProfilePictureView setMaxImagesCachedBeyondLifetime:cacheSize];
```

The cache can be disabled again by passing a cache size of 0.

Also you can enable disk caching support by calling:

```objc
        [DBFBProfilePictureView enableDiskCache:YES lifetime:3600];
```

## Version history

1.5.3 - fix bug with long facebook ids and the disk cache (thanks to @fmalekpour)
      - Expose imageView as a readonly property (thanks to @0xc00010ff)

1.5.2 - fix bug with disk cache hash overflowing int (thanks to @ekaralar)

1.5.1 - added support for enabling disk cache (thanks to @ekratskih)

1.5.0 - added support for enabling profile images to be cached (thanks to @cellininicholas & @FlorianDenis)
      - added support for AFNetworking 2. Define USE_AFNETWORKING_2 in DBFBProfilePictureView.m

1.4.2 - fix bug with unregistering an observer (thanks to @FlorianDenis).

1.4.1 - fix infinite recursion when no custom empty profile picture is specified.
      - Remove use of deprecated FBGraphBasePath (thanks to @FlorianDenis).

1.4.0 - allow a custom image to be set to be shown if no profile picture is available

1.3.0 - nil the image when the view is re-used and a download is triggered. (Fixes problem with UICollectionView described in Issue #5)

1.2.0 - Don't call the completion callback when a download is cancelled due to the view being re-used

1.1.0 - Add in-memory caching & sharing of UIImage objects for the same requested URL

1.0.0 - Initial release

## License

Licensed under Apache License, Version 2.0
