//
//  URBAlertView.h
//  URBFlipModalViewControllerDemo
//
//  Created by Nicholas Shipes on 12/21/12.
//  Copyright (c) 2012 Urban10 Interactive. All rights reserved.
//

#import <UIKit/UIKit.h>

enum {
	URBAlertAnimationDefault = 0,
	URBAlertAnimationFade,
	URBAlertAnimationFlipHorizontal,
	URBAlertAnimationFlipVertical,
	URBAlertAnimationTumble,
	URBAlertAnimationSlideLeft,
	URBAlertAnimationSlideRight
};
typedef NSInteger URBAlertAnimation;

@interface URBAlertView : UIView <UITextFieldDelegate>

typedef void (^URBAlertViewBlock)(NSInteger buttonIndex, URBAlertView *alertView);

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, strong) UIView *contentView;

///-----------------
/// @name Appearance
///-----------------
@property (nonatomic, strong) UIImage *backgroundImage UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong) UIImage *buttonBackgroundImage UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong) UIFont *titleFont UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong) UIFont *messageFont UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong) UIFont *buttonFont UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong) UIFont *textFieldFont UI_APPEARANCE_SELECTOR;

@property (nonatomic, assign) BOOL darkenBackground;
@property (nonatomic, assign) BOOL blurBackground;

+ (URBAlertView *)dialogWithTitle:(NSString *)title message:(NSString *)message;

- (id)initWithTitle:(NSString *)title message:(NSString *)message;

- (NSInteger)addButtonWithTitle:(NSString *)title;
- (void)addTextFieldWithPlaceholder:(NSString *)placeholder secure:(BOOL)secure;
- (NSString *)textForTextFieldAtIndex:(NSUInteger)index;

- (void)setTitleTextAttributes:(NSDictionary *)textAttributes UI_APPEARANCE_SELECTOR;
- (void)setMessageTextAttributes:(NSDictionary *)textAttributes UI_APPEARANCE_SELECTOR;
- (void)setButtonTextAttributes:(NSDictionary *)textAttributes forState:(UIControlState)state UI_APPEARANCE_SELECTOR;
- (void)setTextFieldTextAttributes:(NSDictionary *)textAttributes;

- (void)setHandlerBlock:(URBAlertViewBlock)block;

///--------------------------------
/// @name Presenting and Dismissing
///--------------------------------
- (void)show;
- (void)showWithCompletionBlock:(void(^)())completion;
- (void)showWithAnimation:(URBAlertAnimation)animation;
- (void)showWithAnimation:(URBAlertAnimation)animation completionBlock:(void(^)())completion;

- (void)hide;
- (void)hideWithCompletionBlock:(void(^)())completion;
- (void)hideWithAnimation:(URBAlertAnimation)animation;
- (void)hideWithAnimation:(URBAlertAnimation)animation completionBlock:(void(^)())completion;

@end
