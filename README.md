
## RGImageGallery
RGImageGallery is a viewController which could display image or video like slide show

- Transition animate and interaction gesture like system "Photos" app
- Customizable toolbar and displayView

[RGImagePicker](https://github.com/RengeRenge/RGImagePicker) use RGImageGallery to display image, the following screenshots are from RGImagePicker

![1](https://user-images.githubusercontent.com/14158970/64589139-f2b63400-d3d6-11e9-9f8b-39c8efb510a4.gif)
![2](https://user-images.githubusercontent.com/14158970/64589143-f34eca80-d3d6-11e9-89ad-b731b70dd566.gif)
![3](https://user-images.githubusercontent.com/14158970/64589144-f34eca80-d3d6-11e9-9a5d-9f00c6907aee.gif)


## Installation
To add it to your app, copy the two classes `RGImageGallery.h/.m` into your Xcode project or add via [CocoaPods](http://cocoapods.org) by adding this to your Podfile:

```ruby
pod 'RGImageGallery'
```

## Usage

### Init with datasource. DataSource provide image data.
- Number
- Thumbnail
- Large image

```objective-c
RGImageGallery *imageGallery = [[RGImageGallery alloc] initWithPlaceHolder:self.loadFailedImage andDataSource:self];
```

### Called When DataSource Changed
```
- (void)updatePages:(NSIndexSet *_Nullable)pages;
- (void)insertPages:(NSIndexSet *_Nullable)pages;
- (void)deletePages:(NSIndexSet *_Nullable)pages;
```

### RGImageGalleryPushTransitionDelegate
- Provide Push View For Push or Pop Transition
- Handle Will Push Event
- Handle Will Pop Event

```objective-c
// Set push transition style
imageGallery.pushTransitionDelegate = self;
imageGallery.pushFromView = YES;
```


### RGImageGalleryAdditionUIConfig

- Custom Toolbar
- Custom Video Play Button
- Custom View Which is Front Display Image View


### RGImageGalleryDelegate
- Handle Play Video Event
- Handle Stop Video Event
- Handle Image Slide Event

### Push

- Tap wtih Push

```objective-c
[imageGallery showImageGalleryAtIndex:indexPath.row fatherViewController:self];
```

- PinchGesture with Push
 
Pinch gesture should add into your view, and control progress by yourself. Here is a example.

```objective-c
- (void)pin:(UIPinchGestureRecognizer *)gesture {
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:{
            NSIndexPath *path = nil;
            NSUInteger touchCount = gesture.numberOfTouches;
            if (touchCount == 2) {
                CGPoint p1 = [gesture locationOfTouch:0 inView:self.collectionView];
                CGPoint p2 = [gesture locationOfTouch:1 inView:self.collectionView];
                CGPoint center = CGPointMake((p1.x+p2.x)/2,(p1.y+p2.y)/2);
                path = [self.collectionView indexPathForItemAtPoint:center];
            }
            
            if (!path) {
                return;
            }
            
            RGImageGallery *imageGallery = [[RGImageGallery alloc] initWithPlaceHolder:self.loadFailedImage andDataSource:self];
            imageGallery.pushTransitionDelegate = self;
            imageGallery.pushFromView = YES;
            
            // record originSize
            self.rg_originSize = [self.collectionView cellForItemAtIndexPath:path].frame.size;
            
            // began interaction push
            [imageGallery beganInteractionPushAtIndex:path.row fatherViewController:self];
            
            self.imageGallery = imageGallery;
            self.interactionAnimate = YES;
            
            // do animate for interaction
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.1 delay:0 options:0 animations:^{
                    NSUInteger touchCount = gesture.numberOfTouches;
                    if (touchCount == 2) {
                        CGPoint p1 = [gesture locationOfTouch:0 inView:self.collectionView];
                        CGPoint p2 = [gesture locationOfTouch:1 inView:self.collectionView];
                        CGSize size = CGSizeMake(fabs(p1.x - p2.x), fabs(p1.y - p2.y));
                        CGPoint center = CGPointMake((p1.x + p2.x) / 2,(p1.y + p2.y) / 2);
                        center = [self.collectionView convertPoint:center toView:self.view];
                        
                        // update interaction view center
                        [imageGallery updateInteractionPushCenter:center];
                        // update interaction view size
                        [imageGallery updateInteractionPushSize:size];
                    }
                } completion:^(BOOL finished) {
                    self.interactionAnimate = NO;
                    
                    // reset data and began gesture
                    gesture.scale = 1;
                    [self pin:gesture];
                }];
            });
            break;
        }
        case UIGestureRecognizerStateChanged:{
            // is animating, ignore change
            if (self.interactionAnimate) {
                return;
            }
            NSUInteger touchCount = gesture.numberOfTouches;
            if (touchCount == 2) {
                CGPoint p1 = [gesture locationOfTouch:0 inView:self.collectionView];
                CGPoint p2 = [gesture locationOfTouch:1 inView:self.collectionView];
                CGSize size = CGSizeMake(fabs(p1.x - p2.x), fabs(p1.y - p2.y));
                CGPoint center = CGPointMake((p1.x + p2.x) / 2,(p1.y + p2.y) / 2);
                center = [self.collectionView convertPoint:center toView:self.view];
                [self.imageGallery updateInteractionPushCenter:center];
                [self.imageGallery updateInteractionPushSize:size];
                
                UIView *view = [self.imageGallery interactionPushView];
                CGFloat progress = (view.frame.size.width - gesture.view.rg_originSize.width) / self.view.frame.size.width;
                [self.imageGallery updateInteractionPushProgress:progress];
            }
            break;
        }
        case UIGestureRecognizerStatePossible:
        case UIGestureRecognizerStateEnded:{
            if (self.interactionAnimate) {
                return;
            }
            UIView *view = [self.imageGallery interactionPushView];
            CGFloat progress = [self.imageGallery interactionPushProgress];
            if (!progress) {
                progress = (view.frame.size.width - gesture.view.rg_originSize.width) / self.view.frame.size.width;
            }
            // finish interaction push, if gesture.scale >= 1, we think push result is succeed
            [self.imageGallery finishInteractionPush:gesture.scale >= 1 progress:progress];
            break;
        }
        case UIGestureRecognizerStateFailed:
        case UIGestureRecognizerStateCancelled:
        default:{
            // push failed
            [self.imageGallery finishInteractionPush:NO progress:[self.imageGallery interactionPushProgress]];
            break;
        }
    }
}
```
