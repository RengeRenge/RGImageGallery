//
//  ImageGallery.m
//  RGImageGallery
//
//  Created by renge on 16/4/2.
//  Copyright © 2016年 Renge. All rights reserved.
//

#import "RGImageGallery.h"

#define k_RGIMAGE_BUTTON_CLICK_WIDTH  80
#define k_RGIMAGE_BUTTON_CLICK_HEIGHT 80
#define kRGImagePageWidth (kRGImageViewWidth + 20)

#define kRGImageViewWidth    (self.view.bounds.size.width)
#define kRGImageViewHeight   (self.view.bounds.size.height)
#define kRGImageLoadTargetSize     CGSizeMake(kRGImageViewWidth*[UIScreen mainScreen].scale, kRGImageViewHeight*[UIScreen mainScreen].scale)

#define SYSTEM_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define kRGPlayButtonTag 114115

typedef enum : NSUInteger {
    RGIGViewIndexL=0,
    RGIGViewIndexM,
    RGIGViewIndexR,
    RGIGViewIndexCount,
} RGIGViewIndex;

@interface _RGImageBigButton: UIButton

@end

@implementation _RGImageBigButton

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.alpha != 1) {
        return NO;
    }
    CGRect bounds = self.bounds;
    CGFloat widthDelta = k_RGIMAGE_BUTTON_CLICK_WIDTH - bounds.size.width;
    CGFloat heightDelta = k_RGIMAGE_BUTTON_CLICK_HEIGHT - bounds.size.height;
    bounds = CGRectInset(bounds, -0.5 * MAX(0, widthDelta), -0.5 * MAX(0, heightDelta));
    return CGRectContainsPoint(bounds, point);
}

@end

@class IGNavigationControllerDelegate;
@class IGPushAndPopAnimationController;
@class IGInteractionController;

@interface IGNavigationControllerDelegate : NSObject <UINavigationControllerDelegate>

@property (nonatomic, assign) BOOL interactive;
@property (nonatomic, assign) BOOL operateSucceed;
@property (nonatomic, assign) CGFloat leftProgress;
@property (nonatomic, strong) IGPushAndPopAnimationController *animationController;
@property (nonatomic, strong) IGInteractionController *interactionController;

@property (nonatomic, assign) int gestureEnable; // 0 none, 1 pop, -1 zoom

- (IGInteractionController *)interactionControllerWithFromVC:(UIViewController *)fromVC toVC:(UIViewController *)toVC;

@end

@interface IGPushAndPopAnimationController : NSObject <UIViewControllerAnimatedTransitioning>

@property (nonatomic, assign) UINavigationControllerOperation operation;

@property (nonatomic, weak) IGNavigationControllerDelegate *transitionDelegate;

- (instancetype)initWithNavigationControllerOperation:(UINavigationControllerOperation)operation;
- (void)addAnimationForBackgroundColorInPushToVC:(RGImageGallery *)toVC;
- (void)addAnimationForBackgroundColorInPopWithFakeBackground:(UIView *)toView;

@end

@interface IGInteractionController : UIPercentDrivenInteractiveTransition <UIGestureRecognizerDelegate>

@property (nonatomic, assign) CGRect originalFrame;
@property (nonatomic, assign) CGPoint originalCenter;

@property (nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;
@property (nonatomic, strong) UIPinchGestureRecognizer *pinchGestureRecognizer;

@property (nonatomic, assign) UINavigationControllerOperation operation;

@property (nonatomic, weak) UIViewController *toVC;
@property (nonatomic, weak) UIViewController *fromVC;

@property (nonatomic, weak) IGNavigationControllerDelegate *transitionDelegate;

- (void)addPinchGestureOnView:(UIView *)view;

- (void)finishInteractiveTransitionWithSucceed:(BOOL)succeed progress:(CGFloat)progress;

@end

@interface RGImageGalleryView ()

@property (nonatomic, weak) RGImageGallery *imageGallery;

@end

@implementation RGImageGalleryView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.layout) {
        [self bringSubviewToFront:[self viewWithTag:kRGPlayButtonTag]];
        self.layout(self, self.imageGallery);
    }
}

- (void)clearSubviews {
    self.layout = nil;
    [self.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:_RGImageBigButton.class]) {
            return;
        }
        [obj removeFromSuperview];
    }];
    [self.layer.sublayers enumerateObjectsUsingBlock:^(__kindof CALayer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.delegate isKindOfClass:_RGImageBigButton.class]) {
            return;
        }
        [obj removeFromSuperlayer];
    }];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self) {
        return nil;
    }
    return hitView;
}

@end

@interface RGImageGallery() <UIScrollViewDelegate, UIAlertViewDelegate, UIGestureRecognizerDelegate>

@property (strong,nonatomic) NSMutableArray<UIScrollView *>  *scrollViewArr;
@property (strong,nonatomic) NSMutableArray<UIImageView *>  *imageViewArr;
@property (strong,nonatomic) NSMutableArray<RGImageGalleryView *>  *frontViewArr;
@property (strong,nonatomic) UIScrollView    *bgScrollView;

@property (strong, nonatomic) RGImageGalleryView *videoView;
@property (copy,nonatomic) void(^videoCompletion)(void);

@property (assign,nonatomic) NSInteger      oldPage;
@property (assign, nonatomic, readonly) NSInteger lastLoadPage;

@property (nonatomic, strong) IGNavigationControllerDelegate *navigationControllerDelegate;
@property (nonatomic, strong) UILabel        *titleLabel;

@property (nonatomic, assign) CGSize lastSize;

@property (nonatomic, strong) NSMutableArray  *playButtonArr;

@property (nonatomic, strong) UIImage         *placeHolder;
@property (nonatomic, strong) UIImage         *barBackgroundImage;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicatorView;

@property (nonatomic, weak) id  viewControllerF;

@property (nonatomic, assign) BOOL hideTopBar;
@property (nonatomic, assign) BOOL hideToolBar;

- (CGRect)getImageViewFrameWithImage:(UIImage *)image;

@end

@implementation RGImageGallery

@synthesize pushState = _pushState;

- (instancetype)initWithPlaceHolder:(UIImage *)placeHolder andDataSource:(nonnull id<RGImageGalleryDataSource>)dataSource {
    self = [super init];
    if(self){
        self.dataSource = dataSource;
        self.placeHolder = placeHolder;
        self.barBackgroundImage = nil;
        _page = 0;
        _pushState = RGImageGalleryPushStateNoPush;
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    _lastLoadPage = -1;
    if (!self.pushFromView || self.pushState == RGImageGalleryPushStatePushing) {
        [self getCountWithSetContentSize:YES];

        //Load OtherImage
        for (int i=0; i < self.scrollViewArr.count; i++) {
            if (i != RGIGViewIndexM || !self.pushFromView) {
                [self loadThumbnail:self.imageViewArr[i] withScrollView:self.scrollViewArr[i] frontView:self.frontViewArr[i] atPage:_page-RGIGViewIndexM+i];
            }
        }
        [self reloadTitle];
        [self reloadToolBarItem];
        
        //Sequence ScrollViews
        [self setPositionAtPage:_page ignoreIndex:-1];
        
        [self.bgScrollView setDelegate:nil];
        [self.bgScrollView setContentOffset:CGPointMake(_page*kRGImagePageWidth, 0) animated:NO];
        [self getCountWithSetContentSize:YES];
        [self.bgScrollView setDelegate:self];
    }
    if (!self.pushFromView) {
        [self hide:NO toolbarWithAnimateDuration:0];
    }
    [self hide:self.hideTopBar topbarWithAnimateDuration:0 backgroundChange:NO];
}

- (void)viewDidLoad{
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor whiteColor]];
    [self initImageScrollViewArr];
    [self.view addSubview:self.bgScrollView];
    _hideTopBar = NO;
    _hideToolBar = NO;

    self.toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.toolbar];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.view
                                                          attribute:NSLayoutAttributeLeading
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.toolbar
                                                          attribute:NSLayoutAttributeLeading
                                                         multiplier:1
                                                           constant:0]];
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.view
                                                          attribute:NSLayoutAttributeTrailing
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.toolbar
                                                          attribute:NSLayoutAttributeTrailing
                                                         multiplier:1
                                                           constant:0]];
    
    if (@available(iOS 11.0, *)) {;
        [self.toolbar.lastBaselineAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor].active = YES;
    } else {
        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.toolbar
                                                              attribute:NSLayoutAttributeBottom
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:self.view
                                                              attribute:NSLayoutAttributeBottom
                                                             multiplier:1
                                                               constant:0]];
    }
    
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    
    //Load Visiable Image
    [self setMiddleImageViewForPushWithScale:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self __setNavigationBarAndTabBarForImageGallery:YES];
    
    if (self.pushFromView) {
        self.navigationController.delegate = self.navigationControllerDelegate;
        IGInteractionController *controller = [self.navigationControllerDelegate interactionControllerWithFromVC:self toVC:_viewControllerF];
        controller.operation = UINavigationControllerOperationPop;
        [controller addPinchGestureOnView:self.view];
        self.navigationControllerDelegate.interactionController = controller;
    }
    [self hide:!self.hideTopBar topbarWithAnimateDuration:0 backgroundChange:NO];
    [self hide:self.hideTopBar topbarWithAnimateDuration:0 backgroundChange:NO];
    
    if (self.pushState != RGImageGalleryPushStatePushed) {
        _pushState = RGImageGalleryPushStatePushed;
        [self loadLargeImageForCurrentPage];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    UINavigationController *nvg = self.navigationController;
    if (!nvg || ![nvg.viewControllers containsObject:self]) { // pop
        _pushState = RGImageGalleryPushStateNoPush;
        [self __doRelease];
    } else if (!self.presentedViewController && !self.presentingViewController) { // dismiss
        [self __doRelease];
    }
}

- (void)dealloc {
    [self __doRelease];
}

- (void)__doRelease {
    [self clearVideoCompletion];
    [self.frontViewArr enumerateObjectsUsingBlock:^(RGImageGalleryView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj clearSubviews];
    }];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    if (CGSizeEqualToSize(_lastSize, self.view.bounds.size)) {
        return;
    }
    _lastSize = self.view.bounds.size;
    
    [self.bgScrollView setDelegate:nil];
    // Update ContentSize
    [self getCountWithSetContentSize:YES];
    [self setPositionAtPage:_page ignoreIndex:-1];
    
    // Update ImageView Size
    for (RGIGViewIndex i = 0; i < RGIGViewIndexCount && self.pushState != RGImageGalleryPushStatePushing; i++) {
        [self configCurrentPageFrameAndScaleAtIndex:i forceReset:NO];
    }
    [self.bgScrollView setContentOffset:CGPointMake(_page * kRGImagePageWidth, 0) animated:NO];
    [self.bgScrollView setDelegate:self];
    [self reloadTitle];
}


- (BOOL)prefersStatusBarHidden {
    BOOL hide = [super prefersStatusBarHidden];
    if (hide) {
        return YES;
    }
    return self.navigationController.navigationBarHidden;
}

#pragma mark - Getter Setter

- (UIToolbar *)toolbar {
    if (!_toolbar) {
        _toolbar = [[UIToolbar alloc] init];
        _toolbar.barStyle = UIBarStyleDefault;
        _toolbar.alpha = 0.0f;
    }
    return _toolbar;
}

- (UIScrollView *)bgScrollView {
    if (!_bgScrollView) {
        _bgScrollView = [[UIScrollView alloc]initWithFrame:CGRectMake(0, 0, kRGImagePageWidth, kRGImageViewHeight)];
        [_bgScrollView setPagingEnabled:YES];
        [_bgScrollView setDelegate:self];
        [_bgScrollView setBackgroundColor:[UIColor clearColor]];
        [_bgScrollView setShowsHorizontalScrollIndicator:NO];
        _bgScrollView.bounces = YES;
        _bgScrollView.delaysContentTouches = NO;
        _bgScrollView.userInteractionEnabled = YES;
        
        if (@available(iOS 11.0, *)) {
            _bgScrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        }
        
        UITapGestureRecognizer *singleTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideBar:)];
        singleTapGesture.delaysTouchesBegan = YES;
        //        singleTapGesture.cancelsTouchesInView = NO;
        singleTapGesture.delegate = self;
        [singleTapGesture setNumberOfTapsRequired:1];
        [singleTapGesture setNumberOfTouchesRequired:1];
        [_bgScrollView addGestureRecognizer:singleTapGesture];
        
        UITapGestureRecognizer *doubleTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(__zoomForTap:)];
        doubleTapGesture.delaysTouchesBegan = NO;
        doubleTapGesture.delegate = self;
        [doubleTapGesture setNumberOfTapsRequired:2];
        [doubleTapGesture setNumberOfTouchesRequired:1];
        [_bgScrollView addGestureRecognizer:doubleTapGesture];
        
        [singleTapGesture requireGestureRecognizerToFail:doubleTapGesture];
    }
    return _bgScrollView;
}

-(UILabel *)titleLabel {
    if (!_titleLabel) {
        _titleLabel = [[UILabel alloc]init];
        _titleLabel.numberOfLines = 2;
        _titleLabel.font = [UIFont systemFontOfSize:15];
        [_titleLabel setTextAlignment:NSTextAlignmentCenter];
    }
    return _titleLabel;
}

- (void)initImageScrollViewArr {
    self.imageViewArr = [NSMutableArray array];
    self.scrollViewArr = [NSMutableArray array];
    self.frontViewArr = [NSMutableArray array];
    for (RGIGViewIndex i = 0; i < RGIGViewIndexCount; i++) {
        [self.imageViewArr addObject:[self buildImageView]];
        [self.scrollViewArr addObject:[self buildScrollView]];
        UIScrollView *bgView = self.scrollViewArr.lastObject;
        
        RGImageGalleryView *front = [[RGImageGalleryView alloc] initWithFrame:bgView.bounds];
        front.imageGallery = self;
        UIButton *play = [self buildPlayButton];
        [front addSubview:play];
        
        [self.frontViewArr addObject:front];
        
        [bgView addSubview:self.imageViewArr.lastObject];
        [self.bgScrollView addSubview:bgView];
        [self.bgScrollView addSubview:front];
    }
    self.videoView = [RGImageGalleryView new];
    self.videoView.hidden = YES;
}

- (UIImageView *)buildImageView {
    UIImageView *imageView = [[UIImageView alloc] init];
    [imageView setContentMode:UIViewContentModeScaleAspectFill];
    [imageView setClipsToBounds:YES];
    imageView.userInteractionEnabled = YES;
    imageView.backgroundColor = [UIColor clearColor];
    return imageView;
}

- (UIButton *)buildPlayButton {
    _RGImageBigButton *play = [[_RGImageBigButton alloc] init];
    [play addTarget:self action:@selector(onPlayItem:) forControlEvents:UIControlEventTouchUpInside];
    play.tag = kRGPlayButtonTag;
    play.clipsToBounds = YES;
    play.alpha = 0.0f;
    play.enabled = NO;
    play.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin;
    return play;
}

- (UIScrollView *)buildScrollView {
    UIScrollView *imageScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, kRGImageViewWidth, kRGImageViewHeight)];
    [imageScrollView setDelegate:self];
    if (@available(iOS 11.0, *)) {
        imageScrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    imageScrollView.delaysContentTouches = NO;
    imageScrollView.minimumZoomScale = 1;
    return imageScrollView;
}

#pragma mark - Push

- (IGNavigationControllerDelegate *)navigationControllerDelegate {
    if (!_navigationControllerDelegate) {
        _navigationControllerDelegate = [[IGNavigationControllerDelegate alloc] init];
    }
    return _navigationControllerDelegate;
}

- (void)showImageGalleryAtIndex:(NSInteger)index fatherViewController:(UIViewController *)viewController {
    if (self.pushState == RGImageGalleryPushStatePushing) {
        return;
    }
    _page = index;
    _oldPage = index;
    _hideTopBar = NO;
    _hideToolBar = NO;
    _pushState = RGImageGalleryPushStatePushing;
    
    //Load Visiable Image
    [self setMiddleImageViewForPushWithScale:NO];
    
    //Show ImageGallery ViewController
    [self pushSelfByFatherViewController:viewController];
}

- (void)beganInteractionPushAtIndex:(NSInteger)index fatherViewController:(UIViewController *)viewController {
    _page = index;
    _oldPage = index;
    _hideTopBar = NO;
    _hideToolBar = NO;
    _pushState = RGImageGalleryPushStatePushing;
    
    IGInteractionController *interactionController = [self.navigationControllerDelegate interactionControllerWithFromVC:viewController toVC:self];
    interactionController.operation = UINavigationControllerOperationPush;
    self.navigationControllerDelegate.interactive = YES;
    self.navigationControllerDelegate.interactionController = interactionController;
    
    [self pushSelfByFatherViewController:viewController];
}

- (void)updateInteractionPushCenter:(CGPoint)center {
    UIImageView *imageView = self.imageViewArr[RGIGViewIndexM];
    imageView.center = center;
    [self setMiddleImageViewPlayButton];
}

- (void)updateInteractionPushSize:(CGSize)size {
    UIImageView *imageView = self.imageViewArr[RGIGViewIndexM];
    CGPoint center = imageView.center;
    
    CGRect bigFrame = [self getImageViewFrameWithImage:imageView.image];
    CGFloat width = size.height / bigFrame.size.height *  bigFrame.size.width;
    if (width < size.width) {
        CGFloat height = bigFrame.size.height * size.width / bigFrame.size.width;
        size.height = height;
    } else {
        size.width = width;
    }
    
    CGRect frame = imageView.frame;
    frame.size = size;
    imageView.frame = frame;
    
    imageView.center = center;
    [self setMiddleImageViewPlayButton];
}

- (UIImageView *)interactionPushView {
    UIImageView *imageView = self.imageViewArr[RGIGViewIndexM];
    return imageView;
}

- (void)updateInteractionPushProgress:(CGFloat)progress {
    [self.navigationControllerDelegate.interactionController updateInteractiveTransition:progress];
    [self setMiddleImageViewPlayButton];
}

- (CGFloat)interactionPushProgress {
    return self.navigationControllerDelegate.interactionController.percentComplete;
}

- (void)finishInteractionPush:(BOOL)succeed progress:(CGFloat)progress {
    [self.navigationControllerDelegate.interactionController finishInteractiveTransitionWithSucceed:succeed progress:progress];
}

- (void)setMiddleImageViewForPopSetScale:(CGFloat)scale setCenter:(BOOL)setCenter centerX:(CGFloat)x cencentY:(CGFloat)y {
    
    UIImageView *imageView = self.imageViewArr[RGIGViewIndexM];
    
    if (!imageView.image) {
        [imageView setImage:[self getPushImage]];
    }
    
    CGRect originalFrame = [self getImageViewFrameWithImage:imageView.image];
    
    originalFrame.size.height *= scale;
    originalFrame.size.width  *= scale;
    
    if (setCenter) {
        imageView.frame = originalFrame;
        imageView.center = CGPointMake(x, y);
    } else {
        CGPoint center = imageView.center;
        imageView.frame = originalFrame;
        imageView.center = center;
    }
    [self setMiddleImageViewPlayButton];
}

- (void)setMiddleImageViewForPushWithScale:(BOOL)scale {
    if (!self.isViewLoaded) {
        return;
    }
    UIImageView *imageView = self.imageViewArr[RGIGViewIndexM];
    RGImageGalleryView *front = self.frontViewArr[RGIGViewIndexM];
    imageView.image = [self getPushImage];
    
    imageView.frame = scale ? [self getPushViewFrameScaleFit] : [self getPushViewFrame];
    
    if (_delegate && [_delegate respondsToSelector:@selector(imageGallery:isVideoAtIndex:)]) {
        UIButton *play = [front viewWithTag:kRGPlayButtonTag];
        if (_additionUIConfig && [_additionUIConfig respondsToSelector:@selector(imageGallery:isVideoAtIndex:)] && [_additionUIConfig imageGallery:self isVideoAtIndex:_page]) {
            play.enabled = YES;
        } else {
            play.enabled = NO;
        }
        
        if (_additionUIConfig && [_additionUIConfig respondsToSelector:@selector(playButtonImageWithImageGallery:atIndex:)]) {
            UIImage *image = [_additionUIConfig playButtonImageWithImageGallery:self atIndex:_page];
            [play setImage:image forState:UIControlStateNormal];
            [play sizeToFit];
        }
        
        [self setMiddleImageViewPlayButton];
    }
    
    front.layout = nil;
    front.alpha = 0;
    if (_additionUIConfig && [_additionUIConfig respondsToSelector:@selector(imageGallery:configFrontView:atIndex:)]) {
        __weak typeof(self) wSelf = self;
        [_additionUIConfig imageGallery:wSelf configFrontView:front atIndex:_page];
    }
}

- (void)setMiddleImageViewWhenPopFinished {
    if ([self getCountWithSetContentSize:NO] != 0) {
        UIImageView *imageView = self.imageViewArr[RGIGViewIndexM];
        UIScrollView *scrollView = self.scrollViewArr[RGIGViewIndexM];
        RGImageGalleryView *front = self.frontViewArr[RGIGViewIndexM];
        front.alpha = 0;
        CGRect pushFrame = CGRectZero;
        if (_pushTransitionDelegate && [_pushTransitionDelegate respondsToSelector:@selector(imageGallery:thumbViewForTransitionAtIndex:)]) {
            UIView *view = [_pushTransitionDelegate imageGallery:self thumbViewForTransitionAtIndex:_page];
            pushFrame = [view convertRect:view.bounds toView:scrollView];
        }
        imageView.frame = pushFrame;
        [self setMiddleImageViewPlayButton];
        UIButton *play = [front viewWithTag:kRGPlayButtonTag];
        if (play) {
            play.alpha = 0.0f;
        }
    }
}

- (void)setMiddleImageViewWhenPushFinished {
    if ([self getCountWithSetContentSize:NO] != 0) {
        UIImageView *imageView = self.imageViewArr[RGIGViewIndexM];
        UIView *frontView = self.frontViewArr[RGIGViewIndexM];
        UIButton *play = [frontView viewWithTag:kRGPlayButtonTag];
        
        CGRect pushFrame = [self getImageViewFrameWithImage:imageView.image];
        imageView.frame = pushFrame;
        if (play.enabled && !self.isPlayingVideo) {
            play.center = [imageView.superview convertPoint:imageView.center toView:frontView];
            play.alpha = 1.0f;
        }
        play.transform = CGAffineTransformMakeScale(1, 1);
        
        UIScrollView *scrollView = self.scrollViewArr[RGIGViewIndexM];
        [self __configMaximumZoomScaleWithScrollView:scrollView imageViewSize:imageView.frame.size];
    }
}

- (void)setMiddleImageViewWhenPushAnimate {
    if ([self getCountWithSetContentSize:NO] != 0) {
        UIImageView *imageView = self.imageViewArr[RGIGViewIndexM];
        RGImageGalleryView *frontView = self.frontViewArr[RGIGViewIndexM];
        frontView.alpha = 1;
        
        UIButton *play = [frontView viewWithTag:kRGPlayButtonTag];
        
        CGRect oFrame = imageView.frame;
        CGRect pushFrame = [self getImageViewFrameWithImage:imageView.image];
        
        CGFloat pWidth = CGRectGetWidth(pushFrame);
        CGFloat pHeight = CGRectGetHeight(pushFrame);
        
        CGFloat pct = 0.03;
        CGFloat offSetX = pWidth * pct;
        CGFloat offSetY = pHeight * pct;
        CGFloat minOffSet = 8;
        CGFloat maxOffSet = MIN(pWidth*0.1, pHeight*0.1);
        if (minOffSet < maxOffSet) {
            if (offSetX < minOffSet) {
                offSetX = minOffSet;
                pct = offSetX/pWidth;
                offSetY = pct*pHeight;
            }
            if (offSetY < minOffSet) {
                offSetY = minOffSet;
                pct = offSetY/pHeight;
                offSetX = pct*pWidth;
            }
        }
        
        __block BOOL L,R,U,D = NO;
        __block CGRect largePushFrame =
        CGRectInset(pushFrame, -pWidth*pct, -pHeight*pct);;
        
        void(^calOffSet)(CGPoint pP, CGPoint oP) = ^(CGPoint pP, CGPoint oP) {
            if (!L && pP.x < oP.x) { // 向左
                L = YES;
                largePushFrame.origin.x -= offSetX;
            }
            if (!R && pP.x > oP.x) { // 向右
                R = YES;
                largePushFrame.origin.x += offSetX;
            }
            if (!U && pP.y < oP.y) { // 向上
                U = YES;
                largePushFrame.origin.y -= offSetY;
            }
            if (!D && pP.y > oP.y) { // 向下
                D = YES;
                largePushFrame.origin.y += offSetY;
            }
        };
        
        if (oFrame.size.height*oFrame.size.width > pushFrame.size.height * pushFrame.size.width) {
            imageView.frame = pushFrame;
        } else {
            calOffSet(pushFrame.origin, oFrame.origin);
            calOffSet(
                      CGPointMake(CGRectGetMaxX(pushFrame), CGRectGetMaxY(pushFrame)),
                      CGPointMake(CGRectGetMaxX(oFrame), CGRectGetMaxY(oFrame))
                      );
            calOffSet(
                      CGPointMake(CGRectGetMaxX(pushFrame), CGRectGetMinY(pushFrame)),
                      CGPointMake(CGRectGetMaxX(oFrame), CGRectGetMinY(oFrame))
                      );
            calOffSet(
                      CGPointMake(CGRectGetMinX(pushFrame), CGRectGetMaxY(pushFrame)),
                      CGPointMake(CGRectGetMinX(oFrame), CGRectGetMaxY(oFrame))
                      );
            imageView.frame = largePushFrame;
        }
        if (play.enabled) {
            play.center = [imageView.superview convertPoint:imageView.center toView:frontView];
            play.alpha = 1.0f;
        }
        play.transform = CGAffineTransformMakeScale(1, 1);
    }
}

- (void)setMiddleImageViewPlayButton {
    UIImageView *imageView = self.imageViewArr[RGIGViewIndexM];
    UIView *frontView = self.frontViewArr[RGIGViewIndexM];
    UIButton *play = [frontView viewWithTag:kRGPlayButtonTag];
    if (play) {
        play.center = [imageView.superview convertPoint:imageView.center toView:frontView];
        if (play.enabled && !self.isPlayingVideo) {
            play.alpha = imageView.frame.size.width / [self getImageViewFrameWithImage:imageView.image].size.width;
        }
        CGFloat scale = [self getImageViewFrameWithImage:imageView.image].size.width;
        if (scale != 0) {
            scale = imageView.frame.size.width / scale;
        }
        if (scale > 1) {
            scale = 1;
        }
        if (scale < 0.05) {
            scale = 0.05;
        }
        play.transform = CGAffineTransformMakeScale(scale, scale);
    }
}

- (void)pushSelfByFatherViewController:(UIViewController *)viewController {
    _viewControllerF = viewController;
    [_viewControllerF setHidesBottomBarWhenPushed:YES];
    if (self.pushFromView) {
        viewController.navigationController.delegate = self.navigationControllerDelegate;
    }
    [self __setNavigationBarAndTabBarForImageGallery:YES];
    [viewController.navigationController pushViewController:self animated:YES];
}

- (void)showParentViewControllerNavigationBar:(BOOL)show {
    if (((UIViewController *)_viewControllerF).navigationController.navigationBarHidden == show) {
        [((UIViewController *)_viewControllerF).navigationController setNavigationBarHidden:!show animated:NO];
    }
}

- (void)__setNavigationBarAndTabBarForImageGallery:(BOOL)set {
    self.automaticallyAdjustsScrollViewInsets = NO;
    if (![_dataSource respondsToSelector:@selector(configNavigationBarForImageGallery:imageGallery:)]) {
        return;
    }
    [_dataSource configNavigationBarForImageGallery:set imageGallery:self];
}

#pragma mark - Load and Position

- (void)loadInfoWhenPageChanged:(BOOL)loadCurrentImage {
    [self reloadTitle];
    [self reloadToolBarItem];
    if (loadCurrentImage) {
        [self loadLargeImageForCurrentPage];
    }
}

- (NSInteger)getCountWithSetContentSize:(BOOL)setSize {
    NSInteger count = 0;
    if (_dataSource && [_dataSource respondsToSelector:@selector(numOfImagesForImageGallery:)]) {
        count = [_dataSource numOfImagesForImageGallery:self];
        if (setSize) {
            self.bgScrollView.contentSize = CGSizeMake(count*kRGImagePageWidth, 0);
            [self.bgScrollView setFrame:CGRectMake(0, 0, kRGImagePageWidth, kRGImageViewHeight)];
        }
    }
    return count;
}

- (void)setPositionAtPage:(NSInteger)page ignoreIndex:(NSInteger)ignore {
    NSInteger sum = [self getCountWithSetContentSize:NO];
    for (int i=0; i<self.scrollViewArr.count; i++) {
        NSInteger current = page-RGIGViewIndexM+i;
        UIScrollView *view = self.scrollViewArr[i];
        RGImageGalleryView *front = self.frontViewArr[i];
        if (ignore != i) {
            if (current>=0 && current<sum) {
                [view setFrame:CGRectMake(kRGImagePageWidth*current, 0, kRGImageViewWidth, self.bgScrollView.frame.size.height)];
            } else {
                [view setFrame:CGRectMake(kRGImagePageWidth*current, 0, kRGImageViewWidth, self.bgScrollView.frame.size.height)];
            }
            front.frame = view.frame;
        }
    }
}

- (CGRect)getPushViewFrame {
    CGRect rect = CGRectZero;
    if (_pushTransitionDelegate && [_pushTransitionDelegate respondsToSelector:@selector(imageGallery:thumbViewForTransitionAtIndex:)]) {
        UIView *view = [_pushTransitionDelegate imageGallery:self thumbViewForTransitionAtIndex:_page];
        //return view.frame;
        //getRect
        rect = [view convertRect:view.bounds toView:[self.viewControllerF view]];
    }
    return rect;
}

- (CGRect)getPushViewFrameScaleFit {
    
    UIImageView *imageView = self.imageViewArr[RGIGViewIndexM];
    if (!imageView.image) {
        [imageView setImage:[self getPushImage]];
    }
    
    CGRect pushFrame = [self getPushViewFrame];
    CGRect bigFrame = [self getImageViewFrameWithImage:imageView.image];
    CGFloat width = pushFrame.size.height / bigFrame.size.height *  bigFrame.size.width;
    if (width < pushFrame.size.width) {
        CGFloat height = bigFrame.size.height * pushFrame.size.width / bigFrame.size.width;
        pushFrame.origin.y += (pushFrame.size.height - height) / 2.0f;
        pushFrame.size.height = height;
    } else {
        pushFrame.origin.x += (pushFrame.size.width - width) / 2.0f;
        pushFrame.size.width = width;
    }
    return pushFrame;
}

- (UIImage *)getPushImage {
    UIImage *image = nil;
    if (_dataSource && [_dataSource respondsToSelector:@selector(imageGallery:thumbnailAtIndex:targetSize:)]) {
        image = [_dataSource imageGallery:self thumbnailAtIndex:_page targetSize:kRGImageLoadTargetSize];
    }
    if (!image) {
        image = _placeHolder;
    }
    return image;
}

- (CGRect)getImageViewFrameWithImage:(UIImage *)image {
    if (image && image.size.height > 0 && image.size.width > 0) {
        CGFloat imageViewWidth = kRGImageViewWidth;
        CGFloat imageViewHeight = image.size.height/image.size.width*imageViewWidth;
        if (imageViewHeight > kRGImageViewHeight) {
            imageViewHeight = kRGImageViewHeight;
            imageViewWidth = image.size.width/image.size.height*imageViewHeight;
        }
        return CGRectMake(kRGImageViewWidth/2 - imageViewWidth/2, kRGImageViewHeight/2 - imageViewHeight/2, imageViewWidth, imageViewHeight);
    }
    return CGRectZero;
}

- (void)__configMaximumZoomScaleWithScrollView:(UIScrollView *)scrollView imageViewSize:(CGSize)size {
    CGFloat zoomScale = MAX(kRGImageViewHeight/size.height, kRGImageViewWidth/size.width);
    scrollView.maximumZoomScale = zoomScale * 1.5;
}

- (void)loadThumbnail:(UIImageView*)imageView
       withScrollView:(UIScrollView*)scrollView
            frontView:(RGImageGalleryView *)frontView
               atPage:(NSInteger)page {
    
    if (page >= [self getCountWithSetContentSize:NO] || page < 0) {
        imageView.image = nil;
        return;
    }
    UIImage *image;
    image = [_dataSource imageGallery:self thumbnailAtIndex:page targetSize:kRGImageLoadTargetSize];
    
    //if image is nil , then show placeHolder
    if (!image) {
        image = _placeHolder;
    }
    if (image) {
        [imageView setImage:image];
        //set appropriate frame for imageView
        CGRect rect = [self getImageViewFrameWithImage:image];
        [imageView setFrame:rect];
        [self __configMaximumZoomScaleWithScrollView:scrollView imageViewSize:rect.size];
    }
    UIButton *play = [frontView viewWithTag:kRGPlayButtonTag];
    if (play) {
        play.center = [imageView.superview convertPoint:imageView.center toView:frontView];
        play.transform = CGAffineTransformMakeScale(1, 1);
        if (_additionUIConfig && [_additionUIConfig respondsToSelector:@selector(imageGallery:isVideoAtIndex:)]) {
            if ([_additionUIConfig imageGallery:self isVideoAtIndex:page]) {
                play.enabled = YES;
                play.alpha = 1.0f;
            } else {
                play.enabled = NO;
                play.alpha = 0.0f;
            }
            if (_additionUIConfig && [_additionUIConfig respondsToSelector:@selector(playButtonImageWithImageGallery:atIndex:)]) {
                UIImage *image = [_additionUIConfig playButtonImageWithImageGallery:self atIndex:page];
                [play setImage:image forState:UIControlStateNormal];
                [play sizeToFit];
                play.center = [imageView.superview convertPoint:imageView.center toView:frontView];
            }
        }
    }
    
    RGImageGalleryView *temp = frontView;
    if (_additionUIConfig && [_additionUIConfig respondsToSelector:@selector(imageGallery:configFrontView:atIndex:)]) {
        __weak typeof(self) wSelf = self;
        [_additionUIConfig imageGallery:wSelf configFrontView:temp atIndex:page];
    }
}

- (void)configCurrentPageFrameAndScaleAtIndex:(RGIGViewIndex)index forceReset:(BOOL)forceReset {
    UIImageView *imageView = self.imageViewArr[index];
    UIScrollView *scrollView = self.scrollViewArr[index];
    UIView *frontView = self.frontViewArr[index];
    
    CGRect frame = [self getImageViewFrameWithImage:imageView.image];
    
    CGSize size = frame.size;
    CGSize oSize = imageView.frame.size;
    
    if (!forceReset &&
        oSize.height > 0 &&
        size.height > 0 &&
        fabs(size.width/size.height - oSize.width/oSize.height) < 1e-2
        ) {
        oSize = CGSizeMake(scrollView.zoomScale*size.width, scrollView.zoomScale*size.height);
        frame.origin.y = (scrollView.frame.size.height - oSize.height) > 0 ? (scrollView.frame.size.height - oSize.height) * 0.5 : 0;
        frame.origin.x = (scrollView.frame.size.width - oSize.width) > 0 ? (scrollView.frame.size.width - oSize.width) * 0.5 : 0;
        frame.size = oSize;
        imageView.frame = frame;
        scrollView.contentSize = CGSizeMake(imageView.frame.size.width, imageView.frame.size.height);
    } else {
        scrollView.contentSize = CGSizeZero;
        [scrollView setZoomScale:1 animated:NO];
        [frontView viewWithTag:kRGPlayButtonTag].transform = CGAffineTransformMakeScale(1, 1);
        imageView.frame = frame;
        UIButton *play = [frontView viewWithTag:kRGPlayButtonTag];
        play.center = [imageView.superview convertPoint:imageView.center toView:frontView];
    }
    [self __configMaximumZoomScaleWithScrollView:scrollView imageViewSize:size];
}

- (void)loadLargeImageForCurrentPage {
    if (self.lastLoadPage == self.page) {
        return;
    }
    
    NSInteger page = self.page;
    UIImageView *imageView = self.imageViewArr[RGIGViewIndexM];
    
    NSInteger count = [self getCountWithSetContentSize:NO];
    if (page >= count || page < 0) {
        imageView.image = nil;
        return;
    }
    UIImage *image = [_dataSource imageGallery:self imageAtIndex:page targetSize:kRGImageLoadTargetSize updateImage:^(UIImage * _Nonnull image) {
        if (image && self.page == page) {
            UIImageView *imageView = self.imageViewArr[RGIGViewIndexM];
            imageView.image = image;
            [self configCurrentPageFrameAndScaleAtIndex:RGIGViewIndexM forceReset:NO];
        }
    }];
    if (image) {
        imageView.image = image;
        imageView.frame = [self getImageViewFrameWithImage:image];
    }
    _lastLoadPage = _page;
}

- (void)clearVideoCompletion {
    if (self.videoCompletion) {
        void(^temp)(void) = self.videoCompletion;
        self.videoCompletion = nil;
        temp();
    }
    self.videoView.layout = nil;
}

#pragma mark - UI Event

- (void)hide:(BOOL)hide toolbarWithAnimateDuration:(NSTimeInterval)duration {
    [self.view bringSubviewToFront:self.toolbar];
    CGFloat alpha = hide ? 0.0f : 1.0f;
    if (duration > 0) {
        [UIView animateWithDuration:duration animations:^{
            self->_toolbar.alpha = alpha;
            [self.frontViewArr enumerateObjectsUsingBlock:^(UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                obj.alpha = alpha;
            }];
        }];
    } else {
        self.toolbar.alpha = alpha;
        [self.frontViewArr enumerateObjectsUsingBlock:^(UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            obj.alpha = alpha;
        }];
    }
}

- (void)hide:(BOOL)hide topbarWithAnimateDuration:(NSTimeInterval)duration backgroundChange:(BOOL)change {
    if (self.pushState == RGImageGalleryPushStatePushed) {
        dispatch_async(dispatch_get_main_queue(), ^{
            void (^animate)(void) = ^{
                if (self.navigationController) {
                    [self.navigationController setNavigationBarHidden:hide animated:NO];
                    [self setNeedsStatusBarAppearanceUpdate];
                }
            };
            if (duration > 0) {
                [UIView animateWithDuration:duration animations:^{
                    animate();
                    if (change) {
                        [self.view setBackgroundColor:hide ? [UIColor blackColor] : [UIColor whiteColor]];
                    }
                }];
            } else {
                animate();
                if (change) {
                    [self.view setBackgroundColor:hide ? [UIColor blackColor] : [UIColor whiteColor]];
                }
            }
        });
    }
}

- (void)hideBar:(UITapGestureRecognizer *)recognizer {
    if (recognizer) {
        _hideTopBar = !_hideTopBar;
        _hideToolBar = !_hideToolBar;
        
        [self hide:_hideTopBar topbarWithAnimateDuration:0.4 backgroundChange:YES];
        [self hide:_hideToolBar toolbarWithAnimateDuration:0.4];
    } else {
        [self hide:NO topbarWithAnimateDuration:0 backgroundChange:NO];
    }
}

- (void)__zoomForTap:(UITapGestureRecognizer *)recognizer {
    UIScrollView *view = self.scrollViewArr[RGIGViewIndexM];
    UIImageView *imageView = self.imageViewArr[RGIGViewIndexM];
    if (view.zoomScale > 1) {
        [view setZoomScale:1 animated:YES];
    } else {
        CGFloat scale = view.maximumZoomScale/1.5;
        CGPoint point = [recognizer locationInView:imageView];
        CGRect frame = imageView.frame;
        
        CGSize size = CGSizeApplyAffineTransform(frame.size, CGAffineTransformMakeScale(1/scale, 1/scale));
        [view zoomToRect:CGRectMake(point.x - size.width/2, point.y - size.height/2, size.width, size.height) animated:YES];
    }
}

- (void)onPlayItem:(UIButton *)play {
    if (self.navigationControllerDelegate.interactive) {
        return;
    }
    if (play.alpha != 1) {
        return;
    }
    [self doPlayItem:play];
}

- (void)doPlayItem:(UIButton *)play {
    if (!_delegate || ![_delegate respondsToSelector:@selector(imageGallery:playVideoAtIndex:videoView:completion:)]) {
        return;
    }
    
    UIView *centerView = self.imageViewArr[RGIGViewIndexM];
    __block NSInteger page = _page;
    //    BOOL hideTopBar = self.hideTopBar;
    //    BOOL hideToolBar = self.hideToolBar;
    
    __weak typeof(self) wSelf = self;
    void(^completion)(void) = ^{
        if (page < 0) {
            return;
        }
        wSelf.videoView.layout = nil;
        wSelf.videoView.alpha = 0;
        
        [wSelf.videoView clearSubviews];
        [wSelf.videoView removeFromSuperview];
        
        wSelf.videoView.hidden = YES;
        if (play.enabled) {
            play.alpha = 1;
        }
        //        wSelf.hideTopBar = hideTopBar;
        //        wSelf.hideToolBar = hideToolBar;
        //
        //        [wSelf hide:hideToolBar toolbarWithAnimateDuration:0.3];
        //        [wSelf hide:hideTopBar topbarWithAnimateDuration:0.3 backgroundChange:YES];
        if ([wSelf.delegate respondsToSelector:@selector(imageGallery:stopVideoAtIndex:videoView:)]) {
            [wSelf.delegate imageGallery:wSelf stopVideoAtIndex:page videoView:wSelf.videoView];
        }
        page = -1;
    };
    
    __weak typeof(self.videoView) wView = self.videoView;
    
    if ([_delegate imageGallery:wSelf
               playVideoAtIndex:page
                      videoView:wView
                     completion:^{
                         [wSelf clearVideoCompletion];
                     }]) {
                         self.videoView.frame = centerView.bounds;
                         self.videoView.alpha = 0;
                         self.videoCompletion = completion;
                         self.videoView.hidden = NO;
                         [centerView addSubview:self.videoView];
                         [UIView animateWithDuration:0.3 animations:^{
                             play.alpha = 0;
                             self.videoView.alpha = 1;
                             //                             wSelf.hideTopBar = YES;
                             //                             wSelf.hideToolBar = YES;
                             //                             [wSelf hide:YES toolbarWithAnimateDuration:0];
                             //                             [wSelf hide:YES topbarWithAnimateDuration:0 backgroundChange:YES];
                         }];
                     }
}

- (void)reloadTitle {
    NSInteger page = self.page;
    NSInteger count = [self getCountWithSetContentSize:NO];
    if (page >= count || page < 0) {
        self.navigationItem.title = @"";
        return;
    }
    self.titleLabel.attributedText = nil;
    self.titleLabel.text = nil;
    if (_dataSource && [_dataSource respondsToSelector:@selector(attributedTitleForImageGallery:atIndex:)]) {
        self.navigationItem.title = @"";
        self.titleLabel.attributedText = [_dataSource attributedTitleForImageGallery:self atIndex:page];
        [self.titleLabel sizeToFit];
    } else {
        if (_dataSource && [_dataSource respondsToSelector:@selector(titleForImageGallery:atIndex:)]) {
            NSString *title = [_dataSource titleForImageGallery:self atIndex:page];
            self.navigationItem.title = title;
            self.titleLabel.text = title;
            [self.titleLabel sizeToFit];
        }
        if (_dataSource && [_dataSource respondsToSelector:@selector(titleColorForImageGallery:)]) {
            UIColor *color = [_dataSource titleColorForImageGallery:self];
            self.titleLabel.textColor = color;
        }
        if (_dataSource && [_dataSource respondsToSelector:@selector(tintColorForImageGallery:)]) {
            UIColor *color = [_dataSource tintColorForImageGallery:self];
            //            self.toolbar.tintColor = color;
            self.view.tintColor = color;
        }
    }
    
    self.navigationItem.titleView = nil;
    self.navigationItem.titleView = _titleLabel;
}

- (void)reloadToolBarItem {
    BOOL display = NO;
    
    NSInteger page = self.page;
    NSInteger count = [self getCountWithSetContentSize:NO];
    if (page >= count || page < 0) {
        display = NO;
    } else {
        if (_additionUIConfig && [_additionUIConfig respondsToSelector:@selector(imageGallery:toolBarItemsShouldDisplayForIndex:)]) {
            display = [_additionUIConfig imageGallery:self toolBarItemsShouldDisplayForIndex:page];
            
            if (display && _additionUIConfig && [_additionUIConfig respondsToSelector:@selector(imageGallery:toolBarItemsForIndex:)]) {
                [CATransaction begin];
                [CATransaction setDisableActions:YES];
                [self.toolbar setItems:[_additionUIConfig imageGallery:self toolBarItemsForIndex:page] animated:NO];
                [CATransaction commit];
            }
        }
    }
    self.toolbar.hidden = !display;
}

- (void)reloadFrontView {
    NSInteger count = [self getCountWithSetContentSize:NO];
    [self.frontViewArr enumerateObjectsUsingBlock:^(RGImageGalleryView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSUInteger index = self.page - RGIGViewIndexM + idx;
        if (index < count) {
            __weak typeof(self) wSelf = self;
            [self.additionUIConfig imageGallery:wSelf configFrontView:obj atIndex:self.page - RGIGViewIndexM + idx];
        }
    }];
}

- (void)showMessage:(NSString *)message atPercentY:(CGFloat)percentY {
    UIView *old = [self.view viewWithTag:199999];
    if (old) {
        [old removeFromSuperview];
    }
    UIView *showview =  [[UIView alloc]init];
    showview.backgroundColor = [UIColor blackColor];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, 0, 0)];
    label.textColor = [UIColor whiteColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.backgroundColor = [UIColor clearColor];
    label.font = [UIFont boldSystemFontOfSize:14];
    label.text = message;
    label.numberOfLines = 0;
    CGSize size = [label sizeThatFits:CGSizeMake(MIN(self.view.frame.size.width, self.view.frame.size.height) - 80, CGFLOAT_MAX)];
    label.frame = CGRectMake(10, 10, size.width, size.height);
    
    CGRect rect = UIEdgeInsetsInsetRect(label.frame, UIEdgeInsetsMake(-10, -10, -10, -10));
    showview.frame = rect;
    showview.center = CGPointMake(self.view.frame.size.width/2.0f, self.view.frame.size.height * percentY);
    
    showview.alpha = 1.0f;
    showview.layer.cornerRadius = 5.0f;
    showview.layer.masksToBounds = YES;
    showview.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin;
    showview.tag = 199999;
    
    [self.view addSubview:showview];
    [showview addSubview:label];
    
    [UIView animateWithDuration:2.5 animations:^{
        showview.alpha = 0;
    } completion:^(BOOL finished) {
        [showview removeFromSuperview];
    }];
}

- (BOOL)isPlayingVideo {
    return self.videoCompletion != nil;
}

- (void)startCurrentPageVideo {
    UIView *frontView = self.frontViewArr[RGIGViewIndexM];
    UIButton *button = (UIButton *)[frontView viewWithTag:kRGPlayButtonTag];
    if (button.isEnabled) {
        [self doPlayItem:button];
    }
}

- (void)stopCurrentVideo {
    [self clearVideoCompletion];
}

- (void)showVideoButton:(BOOL)show {
    UIView *frontView = self.frontViewArr[RGIGViewIndexM];
    UIButton *button = (UIButton *)[frontView viewWithTag:kRGPlayButtonTag];
    if (show) {
        if (button.isEnabled) {
            [UIView animateWithDuration:0.3 animations:^{
                button.alpha = 1.f;
            }];
        }
    } else {
        [UIView animateWithDuration:0.3 animations:^{
            button.alpha = 0.f;
        }];
    }
}

- (void)setLoading:(BOOL)loading {
    if (loading && !_activityIndicatorView) {
        _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        _activityIndicatorView.center = CGPointMake(self.view.frame.size.width/2.0f, self.view.frame.size.height/2.0f);
        _activityIndicatorView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        [self.view addSubview:_activityIndicatorView];
    }
    if (loading) {
        //        self.BgScrollView.scrollEnabled = NO;
        [self.view bringSubviewToFront:_activityIndicatorView];
        [_activityIndicatorView startAnimating];
    } else {
        //        self.BgScrollView.scrollEnabled = YES;
        [_activityIndicatorView stopAnimating];
    }
}

+ (UIImage *)imageForTranslucentNavigationBar:(UINavigationBar *)navigationBar backgroundImage:(UIImage *)image {
    if (SYSTEM_LESS_THAN(@"10")) {
        if (image!=nil) {
            CGRect rect = navigationBar.frame;
            rect.origin.y = 0;
            rect.size.height += 20;
            CGFloat scale = image.size.width/rect.size.width;
            
            rect.size.height *= scale*[[UIScreen mainScreen] scale];
            rect.size.width  *= scale*[[UIScreen mainScreen] scale];
            
            CGImageRef subImageRef = CGImageCreateWithImageInRect(image.CGImage, rect);
            UIImage* smallImage = [UIImage imageWithCGImage:subImageRef];
            CGImageRelease(subImageRef);
            return smallImage;
        }
    }
    return image;
}
#pragma mark - UIscrollview delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if(self.bgScrollView == scrollView) {
        CGFloat scrollviewW =  scrollView.frame.size.width;
        CGFloat x = scrollView.contentOffset.x;
        _page = (x + scrollviewW / 2) /scrollviewW;
        if (_page>=0 && _page<[self getCountWithSetContentSize:NO]) {
            
            //change Left's Left's View
            if (_page > _oldPage) {
                [self clearVideoCompletion];
                
                UIScrollView *changeScView = self.scrollViewArr[0];
                UIImageView  *changeImageView = self.imageViewArr[0];
                RGImageGalleryView  *changeFront = self.frontViewArr[0];
                
                [self.scrollViewArr removeObject:changeScView];
                [self.scrollViewArr addObject:changeScView];
                
                [self.imageViewArr removeObject:changeImageView];
                [self.imageViewArr addObject:changeImageView];
                
                [self.frontViewArr removeObject:changeFront];
                [self.frontViewArr addObject:changeFront];
                
                CGRect rect = changeScView.frame;
                rect.origin.x = (_page+RGIGViewIndexM)*kRGImagePageWidth;
                changeScView.frame  = rect;
                changeFront.frame = rect;
                
                [self loadThumbnail:changeImageView withScrollView:changeScView frontView:changeFront atPage:_page+RGIGViewIndexM];
                [self loadInfoWhenPageChanged:NO];
                if (_delegate && [_delegate respondsToSelector:@selector(imageGallery:middleImageHasChangeAtIndex:)]) {
                    [_delegate imageGallery:self middleImageHasChangeAtIndex:_page];
                }
                _oldPage = _page;
                
            } else if (_page < _oldPage) { //change Right's Right's View
                [self clearVideoCompletion];
                
                UIScrollView *changeScView = self.scrollViewArr[RGIGViewIndexCount-1];
                UIImageView  *changeImageView = self.imageViewArr[RGIGViewIndexCount-1];
                RGImageGalleryView  *changeFront = self.frontViewArr[RGIGViewIndexCount-1];
                [self.scrollViewArr removeObject:changeScView];
                [self.scrollViewArr insertObject:changeScView atIndex:0];
                
                [self.imageViewArr removeObject:changeImageView];
                [self.imageViewArr insertObject:changeImageView atIndex:0];
                
                [self.frontViewArr removeObject:changeFront];
                [self.frontViewArr insertObject:changeFront atIndex:0];

                CGRect rect = changeScView.frame;
                rect.origin.x = (_page-RGIGViewIndexM)*kRGImagePageWidth;
                changeScView.frame  = rect;
                changeFront.frame = rect;
                [self loadThumbnail:changeImageView withScrollView:changeScView frontView:changeFront atPage:_page-RGIGViewIndexM];
                [self loadInfoWhenPageChanged:NO];
                if (_delegate && [_delegate respondsToSelector:@selector(imageGallery:middleImageHasChangeAtIndex:)]) {
                    [_delegate imageGallery:self middleImageHasChangeAtIndex:_page];
                }
                _oldPage = _page;
            }
        }
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if(self.bgScrollView == scrollView) {
        if (decelerate == NO) {
            [self scrollViewDidEndDecelerating:scrollView];
        }
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (self.bgScrollView == scrollView) {
        if (self.lastLoadPage != self.page) {
            for (RGIGViewIndex i = 0; i < RGIGViewIndexCount; i++) {
                if (i == RGIGViewIndexM) {
                    continue;
                }
                [self configCurrentPageFrameAndScaleAtIndex:i forceReset:YES];
            }
        }
        [self loadLargeImageForCurrentPage];
    }
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    if (self.bgScrollView == scrollView) {
        return nil;
    }
    NSUInteger index = [self.scrollViewArr indexOfObject:scrollView];
    if (index == NSNotFound) {
        return nil;
    }
    return self.imageViewArr[index];
}

- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view {
    scrollView.tag = 1000;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    int state = self.navigationControllerDelegate.gestureEnable;
    if (state > 0) {
        if (scrollView.zoomScale < 1) {
            scrollView.zoomScale = 1;
            scrollView.maximumZoomScale = 1;
            scrollView.minimumZoomScale = 1;
        }
        return;
    }
    if (state == 0 && scrollView.tag == 1000) {
        state = -1;
    }
    self.navigationControllerDelegate.gestureEnable = state;
    NSUInteger index = [self.scrollViewArr indexOfObject:scrollView];
    UIImageView *imageView = self.imageViewArr[index];
    
    CGRect frame = imageView.frame;
    
    frame.origin.y = (scrollView.frame.size.height - imageView.frame.size.height) > 0 ? (scrollView.frame.size.height - imageView.frame.size.height) * 0.5 : 0;
    frame.origin.x = (scrollView.frame.size.width - imageView.frame.size.width) > 0 ? (scrollView.frame.size.width - imageView.frame.size.width) * 0.5 : 0;
    imageView.frame = frame;
    
    scrollView.contentSize = CGSizeMake(imageView.frame.size.width, imageView.frame.size.height);
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(CGFloat)scale {
    scrollView.tag = 0;
    int state = self.navigationControllerDelegate.gestureEnable;
    if (state > 0) {
        return;
    }
    state = 0;
    self.navigationControllerDelegate.gestureEnable = state;
}

#pragma mark - gesture Delegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch{
    BOOL result = [self.frontViewArr containsObject:(RGImageGalleryView *)touch.view] ||
    [self.imageViewArr containsObject:(UIImageView *)touch.view] ||
    [self.scrollViewArr containsObject:(UIScrollView *)touch.view] || [touch.view isDescendantOfView:self.videoView];
    return result;
}

#pragma mark - DataSource

- (void)updatePages:(NSIndexSet *)pages {
    _lastLoadPage = -1;
    if (!pages.count || self.pushState == RGImageGalleryPushStateNoPush) {
        return;
    }
    
    [pages enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        for (RGIGViewIndex i = 0; i < self.scrollViewArr.count; i++) {
            if (self.page - RGIGViewIndexM + i == idx) {
                if (i == RGIGViewIndexM) {
                    self->_lastLoadPage = -1;
                    [self loadInfoWhenPageChanged:YES];
                    if (self.delegate && [self.delegate respondsToSelector:@selector(imageGallery:middleImageHasChangeAtIndex:)]) {
                        [self.delegate imageGallery:self middleImageHasChangeAtIndex:idx];
                    }
                } else {
                    [self loadThumbnail:self.imageViewArr[i] withScrollView:self.scrollViewArr[i] frontView:self.frontViewArr[i] atPage:idx];
                }
            }
        }
    }];
}

- (void)insertPages:(NSIndexSet *)pages {
    _lastLoadPage = -1;
    if (!pages.count || self.pushState == RGImageGalleryPushStateNoPush) {
        return;
    }
    
    __block NSInteger forwardPage = 0;
    __block BOOL containCurrentPage = NO;
    
    [pages enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        if (idx <= self.page) {
            forwardPage ++;
            self->_page ++;
        }
        if (idx == self.page) {
            containCurrentPage = YES;
        }
    }];
    
    if (forwardPage > 0) {
        if (_delegate && [_delegate respondsToSelector:@selector(imageGallery:middleImageHasChangeAtIndex:)]) {
            [_delegate imageGallery:self middleImageHasChangeAtIndex:_page];
        }
        
        // scroll
        [self setPositionAtPage:_page ignoreIndex:-1];
        [self.bgScrollView setDelegate:nil];
        [self.bgScrollView setContentOffset:CGPointMake(_page*kRGImagePageWidth, 0) animated:NO];
        [self.bgScrollView setDelegate:self];
    }
    
    [self getCountWithSetContentSize:YES];
    [self loadInfoWhenPageChanged:NO];
    
    for (RGIGViewIndex i = 0; i < self.scrollViewArr.count; i++) {
        if (i == RGIGViewIndexM) {
            continue;
        }
        // reload insert pages
        NSInteger newPage = _page - RGIGViewIndexM + i;
        if ([pages containsIndex:newPage]) {
            [self loadThumbnail:self.imageViewArr[i] withScrollView:self.scrollViewArr[i] frontView:self.frontViewArr[i] atPage:newPage];
        }
    }
    _oldPage = _page;
}

- (void)deletePages:(NSIndexSet *)pages {
    _lastLoadPage = -1;
    if (!pages.count || self.pushState == RGImageGalleryPushStateNoPush) {
        return;
    }
    
    NSInteger newCount = [self getCountWithSetContentSize:NO];
    NSInteger oldCount = self.bgScrollView.contentSize.width / kRGImagePageWidth;
    
    BOOL hasDataAfterCurrentPage = self.page < (oldCount - 1);
    
    __block NSInteger forwardPage = 0;
    __block BOOL containCurrentPage = NO;
    [pages enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        if (idx < self.page) {
            forwardPage ++;
        }
        if (idx == self.page) {
            containCurrentPage = YES;
        }
    }];
    
    _page -= forwardPage;
    
    if (_page > newCount - 1) {
        _page = newCount - 1;
        hasDataAfterCurrentPage = NO;
    }
    if (_page < 0) {
        _page = 0;
    }
    
    if (forwardPage > 0 || containCurrentPage) {
        if (_delegate && [_delegate respondsToSelector:@selector(imageGallery:middleImageHasChangeAtIndex:)]) {
            [_delegate imageGallery:self middleImageHasChangeAtIndex:_page];
        }
        
        // forward
        [self setPositionAtPage:_page ignoreIndex:-1];
        [self.bgScrollView setDelegate:nil];
        [self.bgScrollView setContentOffset:CGPointMake(_page*kRGImagePageWidth, 0) animated:NO];
        [self.bgScrollView setDelegate:self];
    }
    
    if (!containCurrentPage) {
        [self getCountWithSetContentSize:YES]; // adjust contentsize
        [self loadInfoWhenPageChanged:NO];
    } else {
        [self clearVideoCompletion];
    }
    
    for (RGIGViewIndex i = 0; i < self.scrollViewArr.count; i++) {
        if (i == RGIGViewIndexM) {
            continue;
        }
        // reload deleted pages
        NSInteger oldPage = _oldPage - RGIGViewIndexM + i;
        if ([pages containsIndex:oldPage]) {
        
            NSInteger newPage = _page - RGIGViewIndexM + i;
            if (containCurrentPage) {
                if (hasDataAfterCurrentPage) {
                    if (i > RGIGViewIndexM) {
                        newPage -= 1;
                    }
                } else {
                    if (i < RGIGViewIndexM) {
                        newPage += 1;
                    }
                }
            }
            [self loadThumbnail:self.imageViewArr[i] withScrollView:self.scrollViewArr[i] frontView:self.frontViewArr[i] atPage:newPage];
        }
    }
    _oldPage = _page;
    
    if (!containCurrentPage) {
        return;
    }
    
    UIImageView *deleteImageView = self.imageViewArr[RGIGViewIndexM];
    UIScrollView *deleteScrollView = self.scrollViewArr[RGIGViewIndexM];
    RGImageGalleryView *deleteFront = self.frontViewArr[RGIGViewIndexM];
    
    if (newCount == 0) {
        UIImageView *deleteImageView = self.imageViewArr[RGIGViewIndexM];
        UIButton *deleteButton = self.playButtonArr[RGIGViewIndexM];
        [UIView animateWithDuration:0.3 animations:^{
            deleteImageView.alpha = 0.0f;
            deleteImageView.transform =  CGAffineTransformMakeScale(0.5f, 0.5f);
            deleteButton.alpha = 0.0f;
        }completion:^(BOOL finished) {
            deleteImageView.image = nil;
            deleteImageView.alpha = 1.0f;
            deleteImageView.transform =  CGAffineTransformMakeScale(1.0f, 1.0f);
            deleteButton.alpha = 1.0f;
            
            self.navigationController.delegate = nil;
            [self.navigationController popViewControllerAnimated:YES];
            [self __setNavigationBarAndTabBarForImageGallery:NO];
            UINavigationController *ngv = self.navigationController;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (ngv.navigationBarHidden) {
                    [ngv setNavigationBarHidden:NO animated:NO];
                }
            });
        }];
    } else if (hasDataAfterCurrentPage) { // 后面还有数据，把后面的数据挪到前面
        
        [self.imageViewArr exchangeObjectAtIndex:RGIGViewIndexM withObjectAtIndex:RGIGViewIndexCount - 1];
        [self.scrollViewArr exchangeObjectAtIndex:RGIGViewIndexM withObjectAtIndex:RGIGViewIndexCount - 1];
        [self.frontViewArr exchangeObjectAtIndex:RGIGViewIndexM withObjectAtIndex:RGIGViewIndexCount - 1];

        [UIView animateWithDuration:0.3 animations:^{
            deleteScrollView.alpha = 0.0f;
            deleteImageView.transform =  CGAffineTransformMakeScale(0.5f, 0.5f);
            [self setPositionAtPage:self.page ignoreIndex:RGIGViewIndexCount - 1];
        } completion:^(BOOL finished) {
            [self setPositionAtPage:self.page ignoreIndex:-1];
            
            deleteScrollView.alpha = 1.0f;
            deleteImageView.transform =  CGAffineTransformMakeScale(1.0f, 1.0f);
            
            [self getCountWithSetContentSize:YES];
            
            
            [self loadThumbnail:deleteImageView withScrollView:deleteScrollView frontView:deleteFront atPage:self.page+RGIGViewIndexM];
            [self loadInfoWhenPageChanged:YES];
            if (self.delegate && [self.delegate respondsToSelector:@selector(imageGallery:middleImageHasChangeAtIndex:)]) {
                [self.delegate imageGallery:self middleImageHasChangeAtIndex:self.page];
            }
        }];
        
    } else {
        
        [self.imageViewArr exchangeObjectAtIndex:RGIGViewIndexM withObjectAtIndex:0];
        [self.scrollViewArr exchangeObjectAtIndex:RGIGViewIndexM withObjectAtIndex:0];
        [self.frontViewArr exchangeObjectAtIndex:RGIGViewIndexM withObjectAtIndex:0];
        
        [UIView animateWithDuration:0.3 animations:^{
            deleteScrollView.alpha = 0.0f;
            deleteImageView.transform =  CGAffineTransformMakeScale(0.5f, 0.5f);
            [self setPositionAtPage:self.page ignoreIndex:0];
        } completion:^(BOOL finished) {
            [self setPositionAtPage:self.page ignoreIndex:-1];
            
            deleteScrollView.alpha = 1.0f;
            deleteImageView.transform =  CGAffineTransformMakeScale(1.0f, 1.0f);
            
            [self getCountWithSetContentSize:YES];
            
            [self loadThumbnail:deleteImageView withScrollView:deleteScrollView frontView:deleteFront atPage:self.page-RGIGViewIndexM];
            [self loadInfoWhenPageChanged:YES];
            if (self.delegate && [self.delegate respondsToSelector:@selector(imageGallery:middleImageHasChangeAtIndex:)]) {
                [self.delegate imageGallery:self middleImageHasChangeAtIndex:self.page];
            }
        }];
    }
}

@end

#pragma mark - Push And Pop Animate

#define animateTtransitionDuration 0.4f
#define animatePopTtransitionDuration 0.2f
#define interationTtransitionDuration 0.2f

#define DampingRatio    0.7     //弹性的阻尼值
#define Velocity        0.01    //弹簧的修正速度

@implementation IGNavigationControllerDelegate

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController animationControllerForOperation:(UINavigationControllerOperation)operation fromViewController:(UIViewController *)fromVC toViewController:(UIViewController *)toVC {
    if (operation == UINavigationControllerOperationPush && [fromVC isKindOfClass:RGImageGallery.class]) {
        return nil;
    }
    if (operation == UINavigationControllerOperationPop && [toVC isKindOfClass:RGImageGallery.class]) {
        return nil;
    }
    _animationController = [[IGPushAndPopAnimationController alloc] initWithNavigationControllerOperation:operation];
    _animationController.transitionDelegate = self;
    return _animationController;
}

- (id<UIViewControllerInteractiveTransitioning>)navigationController:(UINavigationController *)navigationController interactionControllerForAnimationController:(id<UIViewControllerAnimatedTransitioning>)animationController {
    if (self.interactive) {
        self.leftProgress = 1.0f;
        return _interactionController;
    }
    self.leftProgress = 0.0f;
    self.operateSucceed = YES;
    return nil;
}

- (IGInteractionController *)interactionControllerWithFromVC:(UIViewController *)fromVC toVC:(UIViewController *)toVC  {
    IGInteractionController *interactionController = [[IGInteractionController alloc] init];
    interactionController.toVC = toVC;
    interactionController.fromVC = fromVC;
    interactionController.transitionDelegate = self;
    return interactionController;
}

@end

@implementation IGInteractionController

- (UIPinchGestureRecognizer *)pinchGestureRecognizer {
    if (!_pinchGestureRecognizer) {
        _pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchGesture:)];
        _pinchGestureRecognizer.delegate = self;
    }
    return _pinchGestureRecognizer;
}

- (UIPanGestureRecognizer *)panGestureRecognizer {
    if (!_panGestureRecognizer) {
        _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveGesture:)];
        [_panGestureRecognizer setMinimumNumberOfTouches:1];
        [_panGestureRecognizer setMaximumNumberOfTouches:4];
        _panGestureRecognizer.delegate = self;
    }
    return _panGestureRecognizer;
}

- (void)addPinchGestureOnView:(UIView *)view {
    [view addGestureRecognizer:self.pinchGestureRecognizer];
    [view addGestureRecognizer:self.panGestureRecognizer];
}

- (void)pinchGesture:(UIPinchGestureRecognizer *)gesture {
    RGImageGallery *imageGallery = self.imageGallery;
    CGFloat scale = gesture.scale;
    
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            if (self.transitionDelegate.gestureEnable == -1) {
                return;
            }
            if (!self.transitionDelegate.interactive &&
                       self.operation == UINavigationControllerOperationPop &&
                       gesture.scale < 1 &&
                       [self.toVC.navigationController.viewControllers containsObject:self.fromVC]) {
                self.transitionDelegate.interactionController = self;
                self.transitionDelegate.interactive = YES;
                self.transitionDelegate.gestureEnable = 1;
                
                [imageGallery hide:NO topbarWithAnimateDuration:0.3 backgroundChange:NO];
                [self.fromVC.navigationController popViewControllerAnimated:YES];
                
                NSUInteger touchCount = gesture.numberOfTouches;
                if (touchCount == 2) {
                    CGPoint p1 = [gesture locationOfTouch:0 inView:gesture.view];
                    CGPoint p2 = [gesture locationOfTouch:1 inView:gesture.view];
                    CGPoint center = CGPointMake((p1.x+p2.x)/2,(p1.y+p2.y)/2);
                    self.originalCenter = center;
                }
            }
            break;
        }
        case UIGestureRecognizerStateChanged: {
            if (self.transitionDelegate.gestureEnable != 1) {
                return;
            }
            if (!self.transitionDelegate.interactive) {
                return;
            }
            if (scale <= 3) {
                NSUInteger touchCount = gesture.numberOfTouches;
                if (touchCount == 2) {
                    CGPoint p1 = [gesture locationOfTouch:0 inView:gesture.view];
                    CGPoint p2 = [gesture locationOfTouch:1 inView:gesture.view];
                    CGPoint center = CGPointMake((p1.x+p2.x)/2,(p1.y+p2.y)/2);
                    
                    CGFloat x = self.originalCenter.x - center.x;
                    CGFloat y = self.originalCenter.y - center.y;
                    center = gesture.view.center;
                    center.x -= x;
                    center.y -= y;
                    [imageGallery updateInteractionPushCenter:center];
                }
                
                [imageGallery setMiddleImageViewForPopSetScale:scale setCenter:NO centerX:0 cencentY:0];
            }
            [self updateInteractiveTransition:[self getProgressWithScale:scale limit:YES]];
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            if (self.transitionDelegate.gestureEnable != 1) {
                return;
            }
            if (!self.transitionDelegate.interactive) {
                return;
            }
            self.transitionDelegate.gestureEnable = 0;
            
            CGFloat progress = [self getProgressWithScale:scale limit:YES];
            BOOL isSucceed = NO;
            if (self.operation == UINavigationControllerOperationPop) {
                isSucceed = (progress >= 0.2f);
            }
            [self finishInteractiveTransitionWithSucceed:isSucceed progress:progress];
            break;
        }
        default: {
            NSLog(@"%ld", (long)gesture.state);
        }
    }
}

- (void)moveGesture:(UIPanGestureRecognizer *)gesture {
    CGPoint translatedPoint = [gesture translationInView:gesture.view];
    RGImageGallery *imageGallery = self.imageGallery;
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            if (self.transitionDelegate.gestureEnable == -1) {
                return;
            }
            if (self.operation == UINavigationControllerOperationPop) {
                self.originalFrame = imageGallery.imageViewArr[RGIGViewIndexM].frame;
                self.originalCenter = imageGallery.imageViewArr[RGIGViewIndexM].center;
                if (!self.transitionDelegate.interactive) {
                    self.transitionDelegate.interactionController = self;
                    self.transitionDelegate.interactive = YES;
                    self.transitionDelegate.gestureEnable = 1;
                    
                    [imageGallery hide:NO topbarWithAnimateDuration:0.3 backgroundChange:NO];
                    [self.fromVC.navigationController popViewControllerAnimated:YES];
                }
            }
            break;
        }
        case UIGestureRecognizerStateChanged: {
            if (self.transitionDelegate.gestureEnable != 1) {
                return;
            }
            if (!self.transitionDelegate.interactive) {
                return;
            }
            
            CGFloat scale = (1 - translatedPoint.y / (self.fromVC.view.frame.size.height / 2.0f));
            translatedPoint = CGPointMake(self.originalCenter.x + translatedPoint.x, self.originalCenter.y + translatedPoint.y);
            
            [imageGallery setMiddleImageViewForPopSetScale:scale setCenter:YES centerX:translatedPoint.x cencentY:translatedPoint.y];
            [self updateInteractiveTransition:[self getProgressWithScale:scale limit:YES]];
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            if (self.transitionDelegate.gestureEnable != 1) {
                return;
            }
            if (!self.transitionDelegate.interactive) {
                return;
            }
            self.transitionDelegate.gestureEnable = 0;
            
            CGFloat scale = (1 - translatedPoint.y / (self.fromVC.view.frame.size.height / 2.0f));
            CGFloat progress = [self getProgressWithScale:scale limit:YES];
            BOOL isSucceed = (progress >= 0.02f);
            [self finishInteractiveTransitionWithSucceed:isSucceed progress:progress];
            break;
        }
        default: {
            NSLog(@"%ld", (long)gesture.state);
        }
    }
}

- (CGFloat)getProgressWithScale:(CGFloat)scale limit:(BOOL)limit {
    CGFloat progress = 1.0f - scale;
    if (limit) {
        if (progress < 0) {
            progress = 0;
        }
        if (progress > 1) {
            progress = 1;
        }
    }
    return progress/1.3;
}

- (void)finishInteractiveTransitionWithSucceed:(BOOL)succeed progress:(CGFloat)progress {
    
    if (!self.transitionDelegate.interactive) {
        return;
    }
    if (progress < 0) {
        progress = self.percentComplete;
    }

    self.transitionDelegate.operateSucceed = succeed;
    self.transitionDelegate.interactive = NO;
    
    RGImageGallery *imageGallery = self.imageGallery;

    if (succeed) {
        progress = 1 - progress;
    }
    self.transitionDelegate.leftProgress = progress;
    
    if (self.operation == UINavigationControllerOperationPush) {
        NSTimeInterval duration = MAX(0.1, progress * interationTtransitionDuration);
        if (succeed) {
            duration *= 2;
            self.transitionDelegate.leftProgress = duration/interationTtransitionDuration;
            [self finishInteractiveTransition];
            
            [UIView animateWithDuration:duration*0.6 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                [imageGallery setMiddleImageViewWhenPushAnimate];
            } completion:nil];
            [UIView animateWithDuration:duration*0.4 delay:duration*0.6 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                [imageGallery setMiddleImageViewWhenPushFinished];
            } completion:nil];
        } else {
            [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                [imageGallery setMiddleImageViewWhenPopFinished];
            } completion:^(BOOL finished) {
                [self cancelInteractiveTransition];
            }];
        }
        return;
    } else if (self.operation == UINavigationControllerOperationPop) {
        NSTimeInterval duration = MAX(0.1, progress * interationTtransitionDuration);
        self.transitionDelegate.leftProgress = duration/interationTtransitionDuration;
        if (succeed) {
            [self finishInteractiveTransition];
        } else {
            [self cancelInteractiveTransition];
        }
        
        [UIView animateKeyframesWithDuration:duration delay:0 options:UIViewAnimationOptionCurveEaseOut|UIViewAnimationOptionTransitionNone animations:^{
            if (succeed) {
                [imageGallery setMiddleImageViewWhenPopFinished];
            } else {
                [imageGallery setMiddleImageViewWhenPushFinished];
            }
        } completion:^(BOOL finished) {
            [imageGallery configCurrentPageFrameAndScaleAtIndex:RGIGViewIndexM forceReset:YES];
        }];
    }
}

#pragma mark - Gesture Delegate

- (RGImageGallery *)imageGallery {
    if ([self.fromVC isKindOfClass:[RGImageGallery class]]) {
        return (RGImageGallery *)self.fromVC;
    }
    if ([self.toVC isKindOfClass:[RGImageGallery class]]) {
        return (RGImageGallery *)self.toVC;
    }
    return nil;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    RGImageGallery *imageGallery = self.imageGallery;
    NSUInteger index = [imageGallery.scrollViewArr indexOfObject:(UIScrollView *)otherGestureRecognizer.view];
    if (index != NSNotFound) {
        if (self.transitionDelegate.gestureEnable == 0) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    UIScrollView *view = self.imageGallery.scrollViewArr[RGIGViewIndexM];
    if (self.transitionDelegate.gestureEnable < 0 && view == otherGestureRecognizer.view) {
        return YES;
    }
    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    UIScrollView *view = self.imageGallery.scrollViewArr[RGIGViewIndexM];
    if (self.transitionDelegate.gestureEnable > 0 && otherGestureRecognizer.view == view) {
        return YES;
    }
    return NO;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (self.transitionDelegate.gestureEnable < 0) {
        return NO;
    }
    
    UIScrollView *view = self.imageGallery.scrollViewArr[RGIGViewIndexM];
    if (view.zoomScale > 1) {
        return NO;
    }

    if (gestureRecognizer == self.panGestureRecognizer && [gestureRecognizer.view isKindOfClass:[UICollectionViewCell class]]
         && !self.transitionDelegate.interactive) {
        return NO;
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch{
    RGImageGallery *imageGallery = nil;
    if ([self.fromVC isKindOfClass:[RGImageGallery class]]) {
        imageGallery = (RGImageGallery *)self.fromVC;
    }
    if ([self.toVC isKindOfClass:[RGImageGallery class]]) {
        imageGallery = (RGImageGallery *)self.toVC;
    }
    return [imageGallery.frontViewArr containsObject:(RGImageGalleryView *)touch.view] ||
    [imageGallery.imageViewArr containsObject:(UIImageView *)touch.view] ||
    [imageGallery.scrollViewArr containsObject:(UIScrollView *)touch.view] || [touch.view isDescendantOfView:imageGallery.videoView];
}

@end

@implementation IGPushAndPopAnimationController

- (instancetype)initWithNavigationControllerOperation:(UINavigationControllerOperation)operation {
    self = [super init];
    if (self) {
        self.operation = operation;
    }
    return self;
}

#pragma mark - UIViewControllerAnimatedTransitioning

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext {
    if (self.transitionDelegate.interactive) {
        return interationTtransitionDuration;
    }
    if (self.operation == UINavigationControllerOperationPop) {
        return animatePopTtransitionDuration;
    }
    return animateTtransitionDuration;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    switch (_operation) {
        case UINavigationControllerOperationPush:{
            UIView *containerView       = [transitionContext containerView];
            RGImageGallery *toVC          = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
            UIView *toView              = SYSTEM_LESS_THAN(@"8")?toVC.view:[transitionContext viewForKey:UITransitionContextToViewKey];
            UIViewController *fromVC    = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
            NSTimeInterval duration     = [self transitionDuration:transitionContext];
            
            [containerView addSubview:toView];
            
            RGIMGalleryTransitionCompletion com = nil;
            if ([toVC.pushTransitionDelegate respondsToSelector:@selector(imageGallery:willBePushedWithParentViewController:)]) {
                com = [toVC.pushTransitionDelegate imageGallery:toVC willBePushedWithParentViewController:fromVC];
            }
            
            void(^completion)(BOOL finished) = ^(BOOL finished) {
                BOOL operateSucceed = self.transitionDelegate.operateSucceed;
                
                if (com) {
                    com(operateSucceed);
                }
                
                CGFloat leftTime = self.transitionDelegate.leftProgress * duration;
                
                if (!operateSucceed) {
                    [toVC __setNavigationBarAndTabBarForImageGallery:NO];
                }
                
                void (^operateBlock)(BOOL operateSucceed) = ^(BOOL operateSucceed) {
                    [transitionContext completeTransition:operateSucceed];
                    if (!operateSucceed) {
                        fromVC.navigationController.delegate = nil;
                    }
                };
                
                if (SYSTEM_LESS_THAN(@"8") || leftTime == 0) { // iOS 7 will crash if delay completeTransition:
                    operateBlock(operateSucceed);
                } else {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(leftTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        operateBlock(operateSucceed);
                    });
                }
            };
            
            [toVC.view setBackgroundColor:[UIColor colorWithWhite:1 alpha:0]];
            if (!self.transitionDelegate.interactive) {
                [UIView animateWithDuration:duration*0.6 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                    [toVC setMiddleImageViewWhenPushAnimate];
                    [self addAnimationForBackgroundColorInPushToVC:toVC];
                } completion:^(BOOL finished) {
                    
                }];
                [UIView animateWithDuration:duration*0.4 delay:duration*0.6 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                    [toVC setMiddleImageViewWhenPushFinished];
                } completion:completion];
                [UIView animateWithDuration:duration animations:^{
                    [self addAnimationForBarFrom:toVC isPush:YES];
                } completion:nil];
            } else {
                [UIView animateKeyframesWithDuration:duration delay:0.0 options:UIViewKeyframeAnimationOptionCalculationModeCubic animations:^{
                    [UIView addKeyframeWithRelativeStartTime:0 relativeDuration:1 animations:^{
                        [self addAnimationForBarFrom:toVC isPush:YES ];
                        [self addAnimationForBackgroundColorInPushToVC:toVC];
                    }];
                } completion:completion];
            }
            break;
        }
        case UINavigationControllerOperationPop:{
            UIView *containerView       = [transitionContext containerView];
            RGImageGallery *fromVC        = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
            UIViewController *toVC      = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
            
            UIView *fromView            = SYSTEM_LESS_THAN(@"8")?fromVC.view:[transitionContext viewForKey:UITransitionContextFromViewKey];
            UIView *toView              = SYSTEM_LESS_THAN(@"8")?toVC.view:[transitionContext viewForKey:UITransitionContextToViewKey];
            NSTimeInterval duration     = [self transitionDuration:transitionContext];
            
            [containerView insertSubview:toView belowSubview:fromView];
            [fromView bringSubviewToFront:toView];
            
            RGIMGalleryTransitionCompletion com = nil;
            if ([fromVC.pushTransitionDelegate respondsToSelector:@selector(imageGallery:willPopToParentViewController:)]) {
                com = [fromVC.pushTransitionDelegate imageGallery:fromVC willPopToParentViewController:toVC];
            }
            [UIView animateKeyframesWithDuration:duration delay:0.0 options:UIViewKeyframeAnimationOptionCalculationModeLinear animations:^{
                
                if (toVC.navigationController.navigationBarHidden) {
                    [fromVC hide:NO topbarWithAnimateDuration:0 backgroundChange:NO];
                }
                
                if (!self.transitionDelegate.interactive) {
                    [self addKeyFrameAnimationOnCellPopFromVC:fromVC];
                }
                [UIView addKeyframeWithRelativeStartTime:0 relativeDuration:1 animations:^{
                    [self addAnimationForBarFrom:fromVC isPush:NO];
                    [self addAnimationForBackgroundColorInPopWithFakeBackground:fromView];
                }];
            } completion:^(BOOL finished) {
                [fromVC __setNavigationBarAndTabBarForImageGallery:!self.transitionDelegate.operateSucceed];
                if (self.transitionDelegate.operateSucceed) {
                    toVC.navigationController.delegate = nil;
                    fromVC.navigationController.delegate = nil;
                    [transitionContext completeTransition:YES];
                    [fromVC showParentViewControllerNavigationBar:YES];
                    if (com) {
                        com(YES);
                    }
                } else {
                    [transitionContext completeTransition:NO];
                    if (com) {
                        com(NO);
                    }
                }
            }];
            break;
        }
        default:{}
        break;
    }
}

- (void)addKeyFrameAnimationOnCellPopFromVC:(RGImageGallery *)fromVC {
    [UIView addKeyframeWithRelativeStartTime:0 relativeDuration:1 animations:^{
        [fromVC setMiddleImageViewWhenPopFinished];
    }];
}

- (void)addAnimationForBackgroundColorInPushToVC:(RGImageGallery *)toVC {
    [toVC.view setBackgroundColor:[UIColor colorWithWhite:1 alpha:1]];
}

- (void)addAnimationForBackgroundColorInPopWithFakeBackground:(UIView *)toView {
    [toView setBackgroundColor:[UIColor colorWithWhite:1 alpha:0]];
}

- (void)addAnimationForBarFrom:(RGImageGallery *)imageGallery isPush:(BOOL)isPush {
    if (isPush) {
        [imageGallery hide:NO toolbarWithAnimateDuration:0];
    } else {
        [imageGallery hide:YES toolbarWithAnimateDuration:0];
    }
}

@end

