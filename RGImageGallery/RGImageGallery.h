//
//  RGImageGallery.h
//  RGImageGallery
//
//  Created by renge on 2019/9/10.
//  Copyright © 2019 Renge. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for RGImageGallery.
FOUNDATION_EXPORT double RGImageGalleryVersionNumber;

//! Project version string for RGImageGallery.
FOUNDATION_EXPORT const unsigned char RGImageGalleryVersionString[];


NS_ASSUME_NONNULL_BEGIN

@class RGImageGallery;

typedef void(^RGIMGalleryTransitionCompletion)(BOOL flag);
typedef void(^RGImageGalleryViewLayout)(UIView *wrapper, RGImageGallery *imageGallery);

typedef enum : NSUInteger {
    RGImageGalleryPushStateNoPush,
    RGImageGalleryPushStatePushing,
    RGImageGalleryPushStatePushed,
    RGImageGalleryPushStatePoping,
} RGImageGalleryPushState;

@interface RGImageGalleryView : UIView

@property (nonatomic, copy, nullable) RGImageGalleryViewLayout layout;

- (void)clearSubviews;

@end

@protocol RGImageGalleryDataSource, RGImageGalleryAdditionUIConfig, RGImageGalleryPushTransitionDelegate, RGImageGalleryDelegate;

@interface RGImageGallery : UIViewController

@property (assign, nonatomic, readonly) NSInteger page;

@property (assign, nonatomic) BOOL pushFromView;
@property (assign, nonatomic, readonly) RGImageGalleryPushState pushState;

@property (weak, nonatomic) id<RGImageGalleryDataSource> dataSource;
@property (weak, nonatomic) id<RGImageGalleryAdditionUIConfig> additionUIConfig;
@property (weak, nonatomic) id<RGImageGalleryDelegate> delegate;
@property (weak, nonatomic) id<RGImageGalleryPushTransitionDelegate> pushTransitionDelegate;

@property (nonatomic, strong) UIToolbar *toolbar;

+ (UIImage *)imageForTranslucentNavigationBar:(UINavigationBar *)navigationBar backgroundImage:(UIImage *)image;

- (instancetype)initWithPlaceHolder:(UIImage *_Nullable)placeHolder andDataSource:(id<RGImageGalleryDataSource>)dataSource;

#pragma mark - Push

- (void)showImageGalleryAtIndex:(NSInteger)index fatherViewController:(UIViewController *)viewController;

/* Interaction Push */
- (void)beganInteractionPushAtIndex:(NSInteger)index fatherViewController:(UIViewController *)viewController;

- (void)updateInteractionPushCenter:(CGPoint)center;
- (void)updateInteractionPushSize:(CGSize)size;

- (UIImageView *)interactionPushView;

- (void)updateInteractionPushProgress:(CGFloat)progress;
- (CGFloat)interactionPushProgress;

- (void)finishInteractionPush:(BOOL)succeed progress:(CGFloat)progress;
/* Interaction Push */

#pragma mark - DataSource

- (void)updatePages:(NSIndexSet *_Nullable)pages;
- (void)insertPages:(NSIndexSet *_Nullable)pages;
- (void)deletePages:(NSIndexSet *_Nullable)pages;

#pragma mark - UI

- (void)showMessage:(NSString *)message atPercentY:(CGFloat)percentY;

- (void)reloadTitle;
- (void)reloadToolBarItem;
- (void)reloadFrontView;

- (BOOL)isPlayingVideo;
- (void)startCurrentPageVideo;
- (void)stopCurrentVideo;
- (void)showVideoButton:(BOOL)show;

- (void)setLoading:(BOOL)loading;

@end

#pragma mark - Protocol

@protocol RGImageGalleryDataSource <NSObject>

- (NSInteger)numOfImagesForImageGallery:(RGImageGallery *)imageGallery;

- (UIImage *)imageGallery:(RGImageGallery *)imageGallery thumbnailAtIndex:(NSInteger)index targetSize:(CGSize)targetSize;

- (UIImage *_Nullable)imageGallery:(RGImageGallery *)imageGallery imageAtIndex:(NSInteger)index targetSize:(CGSize)targetSize updateImage:(void(^_Nullable)(UIImage *image))updateImage;

@optional

- (void)configNavigationBarForImageGallery:(BOOL)forImageGallery imageGallery:(RGImageGallery *)imageGallery;

- (NSAttributedString *_Nullable)attributedTitleForImageGallery:(RGImageGallery *)imageGallery atIndex:(NSInteger)index;
- (UIColor *_Nullable)titleColorForImageGallery:(RGImageGallery *)imageGallery;
- (UIColor *_Nullable)tintColorForImageGallery:(RGImageGallery *)imageGallery;
- (NSString *_Nullable)titleForImageGallery:(RGImageGallery *)imageGallery atIndex:(NSInteger)index;

@end


@protocol RGImageGalleryPushTransitionDelegate <NSObject>
@optional

- (UIView *_Nullable)imageGallery:(RGImageGallery *)imageGallery thumbViewForTransitionAtIndex:(NSInteger)index;

- (RGIMGalleryTransitionCompletion)imageGallery:(RGImageGallery *)imageGallery willPopToParentViewController:(UIViewController *)viewController;

- (RGIMGalleryTransitionCompletion)imageGallery:(RGImageGallery *)imageGallery willBePushedWithParentViewController:(UIViewController *)viewController;

@end


@protocol RGImageGalleryAdditionUIConfig <NSObject>
@optional

- (BOOL)imageGallery:(RGImageGallery *)imageGallery toolBarItemsShouldDisplayForIndex:(NSInteger)index;

- (NSArray <UIBarButtonItem *> *)imageGallery:(RGImageGallery *)imageGallery toolBarItemsForIndex:(NSInteger)index;

- (BOOL)imageGallery:(RGImageGallery *)imageGallery isVideoAtIndex:(NSInteger)index;

- (UIImage *_Nullable)playButtonImageWithImageGallery:(RGImageGallery *)imageGallery atIndex:(NSInteger)index;

- (void)imageGallery:(RGImageGallery *)imageGallery configFrontView:(RGImageGalleryView *)frontView atIndex:(NSInteger)index;

@end



@protocol RGImageGalleryDelegate <NSObject>
@optional

- (BOOL)imageGallery:(RGImageGallery *)imageGallery
    playVideoAtIndex:(NSInteger)index
           videoView:(RGImageGalleryView *)videoView
          completion:(void(^)(void))completion;

/**
 if delete page cause stop, index is old mark page and it maybe out of range
 */
- (void)imageGallery:(RGImageGallery *)imageGallery
    stopVideoAtIndex:(NSInteger)index
           videoView:(RGImageGalleryView *)videoView;

- (void)imageGallery:(RGImageGallery *)imageGallery middleImageHasChangeAtIndex:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END
