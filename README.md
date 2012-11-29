## DBFBProfilePictureView - an improved view for facebook profile pictures

There were a number of things I wanted to fix with the Facebook provided FBProfilePictureView:

* Caching of the downloaded profile images, so the network did not get hit for every instance of the view
* Start and completion handlers to allow control of the presentation of the view (e.g. fade-in or show a UIActivityIndicatorView)
* Control of when the empty profile image got shown

In addition there are a couple of other significant changes:

* The implementation has been converted to arc
* key/value observing is used to monitor changes to profileID and pictureCropping
* no download request is made for zero size images

## Getting Started

A typical usage of the view might look like this...

Declare the property in a view controller or UITableCellView:

```objc
    @property(strong) DBFBProfilePictureView* facebookPictureView;
```

Initialize the property:

```objc
        self.facebookPictureView = [[DBFBProfilePictureView alloc] initWithFrame:CGRectMake(imageInset,(self.bounds.size.height-commentPopoverImageSize())/2, commentPopoverImageSize(), commentPopoverImageSize())];
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

Set the profileID:

```objc
		facebookPictureView.profileID = xxxxx;
```

## License

Licensed under Apache License, Version 2.0
