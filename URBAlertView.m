//
//  URBAlertView.m
//  URBFlipModalViewControllerDemo
//
//  Created by Nicholas Shipes on 12/21/12.
//  Copyright (c) 2012 Urban10 Interactive. All rights reserved.
//

#import "URBAlertView.h"
#import <QuartzCore/QuartzCore.h>
#import <Accelerate/Accelerate.h>

enum {
	URBAlertViewDefaultButtonType = 0,
	URBAlertViewCancelButtonType
};
typedef NSUInteger URBAlertViewButtonType;

@interface UIDevice (OSVersion)
- (BOOL)iOSVersionIsAtLeast:(NSString *)version;
@end

@interface UIView (Screenshot)
- (UIImage*)screenshot;
@end

@interface UIImage (Blur)
-(UIImage *)boxblurImageWithBlur:(CGFloat)blur;
@end

@interface UIColor (URBAlertView)
- (UIColor *)adjustBrightness:(CGFloat)amount;
@end

@interface URBAlertWindowOverlay : UIView
@property (nonatomic, strong) URBAlertView *alertView;
@end

@interface URBAlertViewButton : UIButton
@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic, strong) UIColor *strokeColor;
@property (nonatomic, assign) CGFloat strokeWidth;
@property (nonatomic, strong) UIFont *textFont;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, strong) UIColor *textShadowColor;
@property (nonatomic, assign) URBAlertViewButtonType buttonStyle;
@end

@interface URBAlertViewTextField : UITextField
@end

typedef void (^URBAnimationBlock)();

@interface URBAlertView ()
@property (nonatomic, strong) UIImageView *backgroundView;
@property (nonatomic, strong) URBAlertViewButton *cancelButton;
@property (nonatomic, strong) NSMutableArray *buttons;
@property (nonatomic, strong) NSMutableArray *textFields;
@property (nonatomic, weak, readwrite) UITextField *focusedTextField;
@property (nonatomic, strong) URBAlertWindowOverlay *overlay;
@property (nonatomic, assign) URBAlertAnimation animationType;
@property (nonatomic, strong) URBAlertViewBlock block;
@property (nonatomic, strong) UIView *blurredBackgroundView;
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIColor *backgroundTopColor;
@property (nonatomic, strong) UIColor *backgroundBottomColor;
@property (nonatomic, strong) UIColor *lightKeylineColor;
@property (nonatomic, strong) UIColor *darkKeylineColor;
@property (nonatomic, strong) UIColor *hatchLineColor;
- (void)initialize;
- (CGRect)defaultFrame;
- (void)animateWithType:(URBAlertAnimation)animation show:(BOOL)show completionBlock:(void(^)())completion;
- (void)showOverlay:(BOOL)show;
- (void)buttonTapped:(id)button;
- (void)updateBackgroundGradient;
- (UIView *)blurredBackground;
- (UIImage *)defaultBackgroundImage;
- (void)layoutComponents;
- (void)setTextAttributes:(NSDictionary *)textAttributes forLabel:(UILabel *)label;
- (URBAlertViewButton *)buttonAtIndex:(NSInteger)buttonIndex;
- (void)cleanup;
- (void)alertViewDidShow;
@end

#define kURBAlertBackgroundRadius 10.0
#define kURBAlertFrameInset 7.0
#define kURBAlertPadding 8.0
#define kURBAlertButtonPadding 6.0
#define kURBAlertButtonHeight 44.0
#define kURBAlertButtonOffset 58.0
#define kURBAlertTextFieldHeight 29.0

static CGSize const kURBAlertViewDefaultSize = {280.0, 180.0};

@implementation URBAlertView {
	UIInterfaceOrientation _currentOrientation;
	CGFloat _keyboardHeight;
	BOOL _hasLaidOut;
	
@private
	struct {
		CGRect titleRect;
		CGRect messageRect;
		CGRect buttonRect;
		CGRect buttonRegionRect;
		CGRect textFieldsRect;
	} layout;
}

#pragma mark - Class methods

+ (URBAlertView *)dialogWithTitle:(NSString *)title message:(NSString *)message {
	return [[URBAlertView alloc] initWithTitle:title message:message];
}

#pragma mark - init

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:[self defaultFrame]];
	if (self) {
		[self initialize];
	}
	return self;
}

- (id)initWithTitle:(NSString *)title message:(NSString *)message {
	self = [self initWithFrame:CGRectZero];
	if (self) {
		self.title = title;
		self.message = message;
	}
	return self;
}

- (id)initWithTitle:(NSString *)title
			message:(NSString *)message
  cancelButtonTitle:(NSString *)cancelButtonTitle
  otherButtonTitles:(NSString *)otherButtonTitles, ...
{
	self = [self initWithTitle:title message:message];
	if (self) {
		if (cancelButtonTitle) {
			NSUInteger cancelButtonIndex = [self addButtonWithTitle:cancelButtonTitle];
			URBAlertViewButton *cancelButton = [self buttonAtIndex:cancelButtonIndex];
			cancelButton.buttonStyle = URBAlertViewCancelButtonType;
			self.cancelButton = cancelButton;
		}
		if (otherButtonTitles) {
			va_list otherTitles;
			va_start(otherTitles, otherButtonTitles);
			for (NSString *otherTitle = otherButtonTitles; otherTitle; otherTitle = (va_arg(otherTitles, NSString *))) {
				[self addButtonWithTitle:otherTitle];
			}
			va_end(otherTitles);
		}
	}
	return self;
}

- (void)initialize {
	_backgroundColor = [UIColor colorWithWhite:0.22 alpha:1.0];
	_backgroundGradation = 0.1;
	_strokeColor = [UIColor colorWithWhite:0.8 alpha:1.000];
	_strokeWidth = 3.0;
	_cornerRadius = 6.0;
	
	_titleFont = [UIFont boldSystemFontOfSize:18.0];
	_titleColor = [UIColor whiteColor];
	_titleShadowColor = [UIColor blackColor];
	_titleShadowOffset = CGSizeMake(0.0, -1.0);
	
	_messageFont = [UIFont systemFontOfSize:14.0];
	_messageColor = [UIColor whiteColor];
	_messageShadowColor = [UIColor blackColor];
	_messageShadowOffset = CGSizeMake(0.0, -1.0);
	
	_buttonBackgroundColor = [UIColor colorWithWhite:0.35 alpha:1.0];
	[self updateBackgroundGradient];
		
	self.animationType = URBAlertAnimationDefault;
	self.buttons = [NSMutableArray array];
	self.textFields = [NSMutableArray array];
	
	self.opaque = NO;
	self.alpha = 1.0;
	self.darkenBackground = YES;
	self.blurBackground = NO;
	
	_hasLaidOut = NO;
	
	// register for device orientation changes
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
	
	// register for keyboard notifications
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
	
	// register with the device that we want to know when the device orientation changes
	[[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
	
	[self build];
}

- (void)setHandlerBlock:(URBAlertViewBlock)block {
	self.block = block;
}

- (void)setTitleFont:(UIFont *)titleFont {
	if (titleFont != _titleFont) {
		_titleFont = titleFont;
	}
}

- (void)setMessageFont:(UIFont *)messageFont {
	if (messageFont != _messageFont) {
		_messageFont = messageFont;
	}
}

- (void)setTitleTextAttributes:(NSDictionary *)textAttributes {
	UIFont *font = [textAttributes objectForKey:UITextAttributeFont];
	UIColor *textColor = [textAttributes objectForKey:UITextAttributeTextColor];
	UIColor *textShadowColor = [textAttributes objectForKey:UITextAttributeTextShadowColor];
	NSValue *shadowOffsetValue = [textAttributes objectForKey:UITextAttributeTextShadowOffset];
	
	if (font) {
		self.titleFont = font;
	}
	if (textColor) {
		self.titleColor = textColor;
	}
	if (textShadowColor) {
		self.titleShadowColor = textShadowColor;
	}
	if (shadowOffsetValue) {
		UIOffset shadowOffset = [shadowOffsetValue UIOffsetValue];
		self.titleShadowOffset = CGSizeMake(shadowOffset.horizontal, shadowOffset.vertical);
	}
}

- (void)setMessageTextAttributes:(NSDictionary *)textAttributes {
	UIFont *font = [textAttributes objectForKey:UITextAttributeFont];
	UIColor *textColor = [textAttributes objectForKey:UITextAttributeTextColor];
	UIColor *textShadowColor = [textAttributes objectForKey:UITextAttributeTextShadowColor];
	NSValue *shadowOffsetValue = [textAttributes objectForKey:UITextAttributeTextShadowOffset];
	
	if (font) {
		self.messageFont = font;
	}
	if (textColor) {
		self.messageColor = textColor;
	}
	if (textShadowColor) {
		self.messageShadowColor = textShadowColor;
	}
	if (shadowOffsetValue) {
		UIOffset shadowOffset = [shadowOffsetValue UIOffsetValue];
		self.messageShadowOffset = CGSizeMake(shadowOffset.horizontal, shadowOffset.vertical);
	}
}

- (void)setTextFieldTextAttributes:(NSDictionary *)textAttributes {
	[self.textFields enumerateObjectsUsingBlock:^(URBAlertViewTextField *field, NSUInteger idx, BOOL *stop) {
		[self setTextAttributes:textAttributes forLabel:(UILabel *)field];
	}];
}

- (void)setButtonTextAttributes:(NSDictionary *)textAttributes forState:(UIControlState)state {
	UIFont *font = [textAttributes objectForKey:UITextAttributeFont];
	UIColor *textColor = [textAttributes objectForKey:UITextAttributeTextColor];
	UIColor *textShadowColor = [textAttributes objectForKey:UITextAttributeTextShadowColor];
	NSValue *shadowOffsetValue = [textAttributes objectForKey:UITextAttributeTextShadowOffset];
	
	[self.buttons enumerateObjectsUsingBlock:^(URBAlertViewButton *button, NSUInteger idx, BOOL *stop) {
		if (font) {
			button.titleLabel.font = font;
		}
		
		if (textColor) {
			[button setTitleColor:textColor forState:state];
		}
		
		if (textShadowColor) {
			[button setTitleShadowColor:textShadowColor forState:state];
		}
		
		if (shadowOffsetValue) {
			UIOffset shadowOffset = [shadowOffsetValue UIOffsetValue];
			button.titleLabel.shadowOffset = CGSizeMake(shadowOffset.horizontal, shadowOffset.vertical);
		}
	}];
}

- (void)setCancelButtonTextAttributes:(NSDictionary *)textAttributes forState:(UIControlState)state {
	if (self.cancelButton) {
		UIFont *font = [textAttributes objectForKey:UITextAttributeFont];
		UIColor *textColor = [textAttributes objectForKey:UITextAttributeTextColor];
		UIColor *textShadowColor = [textAttributes objectForKey:UITextAttributeTextShadowColor];
		NSValue *shadowOffsetValue = [textAttributes objectForKey:UITextAttributeTextShadowOffset];
		
		if (font) {
			self.cancelButton.titleLabel.font = font;
		}
		
		if (textColor) {
			[self.cancelButton setTitleColor:textColor forState:state];
		}
		
		if (textShadowColor) {
			[self.cancelButton setTitleShadowColor:textShadowColor forState:state];
		}
		
		if (shadowOffsetValue) {
			UIOffset shadowOffset = [shadowOffsetValue UIOffsetValue];
			self.cancelButton.titleLabel.shadowOffset = CGSizeMake(shadowOffset.horizontal, shadowOffset.vertical);
		}
	}
}

- (void)setTextAttributes:(NSDictionary *)textAttributes forLabel:(UILabel *)label {
	UIFont *font = [textAttributes objectForKey:UITextAttributeFont];
	UIColor *textColor = [textAttributes objectForKey:UITextAttributeTextColor];
	UIColor *textShadowColor = [textAttributes objectForKey:UITextAttributeTextShadowColor];
	NSValue *shadowOffsetValue = [textAttributes objectForKey:UITextAttributeTextShadowOffset];
	
	if (font) {
		label.font = font;
	}
	
	if (textColor) {
		label.textColor = textColor;
	}
	
	if (textShadowColor) {
		label.shadowColor = textShadowColor;
	}
	
	if (shadowOffsetValue) {
		UIOffset shadowOffset = [shadowOffsetValue UIOffsetValue];
		label.shadowOffset = CGSizeMake(shadowOffset.horizontal, shadowOffset.vertical);
	}
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
	if (backgroundColor != _backgroundColor) {
		_backgroundColor = backgroundColor;
		
		// update other background-dependent colors
		[self updateBackgroundGradient];
		self.lightKeylineColor = [self.backgroundColor adjustBrightness:1.1];
		self.darkKeylineColor = [self.backgroundColor adjustBrightness:0.85];
		self.hatchLineColor = [self.backgroundColor adjustBrightness:0.85];
		
		[self setNeedsDisplay];
	}
}

- (void)setButtonBackgroundColor:(UIColor *)buttonBackgroundColor {
	if (buttonBackgroundColor != _buttonBackgroundColor) {
		_buttonBackgroundColor = buttonBackgroundColor;
		
		if (!self.cancelButtonBackgroundColor) {
			self.cancelButtonBackgroundColor = buttonBackgroundColor;
		}
		
		[self.buttons enumerateObjectsUsingBlock:^(URBAlertViewButton *button, NSUInteger idx, BOOL *stop) {
			if (button.buttonStyle == URBAlertViewCancelButtonType) {
				button.backgroundColor = self.cancelButtonBackgroundColor;
			}
			else {
				button.backgroundColor = buttonBackgroundColor;
			}
		}];
	}
}

- (void)setButtonStrokeColor:(UIColor *)buttonStrokeColor {
	if (buttonStrokeColor != _buttonStrokeColor) {
		_buttonStrokeColor = buttonStrokeColor;
		
		[self.buttons enumerateObjectsUsingBlock:^(URBAlertViewButton *button, NSUInteger idx, BOOL *stop) {
			button.strokeColor = buttonStrokeColor;
		}];
	}
}

- (void)setCancelButtonBackgroundColor:(UIColor *)cancelButtonBackgroundColor {
	if (cancelButtonBackgroundColor != _cancelButtonBackgroundColor) {
		_cancelButtonBackgroundColor = cancelButtonBackgroundColor;
		
		if (self.cancelButton) {
			self.cancelButton.backgroundColor = cancelButtonBackgroundColor;
		}
	}
}

- (void)setBackgroundGradation:(CGFloat)backgroundGradation {
	if (backgroundGradation != _backgroundGradation) {
		_backgroundGradation = backgroundGradation;
		
		// need to update background with new gradient
		[self updateBackgroundGradient];
	}
}

- (void)updateBackgroundGradient {
	self.backgroundTopColor = (self.backgroundGradation > 0) ? [self.backgroundColor adjustBrightness:(1.0 + self.backgroundGradation)] : self.backgroundColor;
	self.backgroundBottomColor = (self.backgroundGradation > 0) ? [self.backgroundColor adjustBrightness:(1.0 - self.backgroundGradation)] : self.backgroundColor;
}

#pragma mark - Buttons and Text Fields

- (NSInteger)addButtonWithTitle:(NSString *)title {	
	// convert button over to internal button
	URBAlertViewButton *button = [[URBAlertViewButton alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, kURBAlertButtonHeight)];
	[button setTitle:title forState:UIControlStateNormal];
	[button addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
	button.titleLabel.font = [UIFont boldSystemFontOfSize:16.0];
	
	if (self.buttonBackgroundColor) {
		button.backgroundColor = self.buttonBackgroundColor;
	}
	
	[self.buttons addObject:button];
	
	return [self.buttons indexOfObject:button];
}

- (URBAlertViewButton *)buttonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex >= 0 && buttonIndex < [self.buttons count]) {
		return [self.buttons objectAtIndex:buttonIndex];
	}
	return nil;
}

- (void)addTextFieldWithPlaceholder:(NSString *)placeholder secure:(BOOL)secure {
	for (UITextField *field in self.textFields) {
		field.returnKeyType = UIReturnKeyNext;
	}
	
	URBAlertViewTextField *field = [[URBAlertViewTextField alloc] initWithFrame:CGRectMake(0, 0, 200.0, kURBAlertTextFieldHeight)];
	field.returnKeyType = UIReturnKeyDone;
	field.placeholder = placeholder;
	field.secureTextEntry = secure;
	field.font = self.messageFont;
	field.textColor = [UIColor blackColor];
	field.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
	field.keyboardAppearance = UIKeyboardAppearanceAlert;
	field.delegate = self;
	
	[self.textFields addObject:field];
}

- (NSString *)textForTextFieldAtIndex:(NSUInteger)index {
	return ((UITextField *)[self.textFields objectAtIndex:index]).text;
}

#pragma mark - Animations

- (void)show {
	[self animateWithType:self.animationType show:YES completionBlock:nil];
}

- (void)showWithCompletionBlock:(void (^)())completion {
	[self animateWithType:self.animationType show:YES completionBlock:completion];
}

- (void)showWithAnimation:(URBAlertAnimation)animation {
	self.animationType = animation;
	[self animateWithType:self.animationType show:YES completionBlock:nil];
}

- (void)showWithAnimation:(URBAlertAnimation)animation completionBlock:(void (^)())completion {
	self.animationType = animation;
	[self animateWithType:animation show:YES completionBlock:completion];
}

- (void)hide {
	[self animateWithType:self.animationType show:NO completionBlock:nil];
}

- (void)hideWithCompletionBlock:(void (^)())completion {
	[self animateWithType:self.animationType show:NO completionBlock:completion];
}

- (void)hideWithAnimation:(URBAlertAnimation)animation {
	self.animationType = animation;
	[self animateWithType:self.animationType show:NO completionBlock:nil];
}

- (void)hideWithAnimation:(URBAlertAnimation)animation completionBlock:(void (^)())completion {
	self.animationType = animation;
	[self animateWithType:animation show:NO completionBlock:completion];
}

- (void)animateWithType:(URBAlertAnimation)animation show:(BOOL)show completionBlock:(void (^)())completion {
	CGSize screenSize = [UIScreen mainScreen].bounds.size;
	CGAffineTransform transform = self.transform;
	
	if (show) {
		_currentOrientation = [UIApplication sharedApplication].statusBarOrientation;
		transform = [self transformForOrientation:_currentOrientation];
		self.transform = transform;
		self.layer.transform = CATransform3DMakeAffineTransform(transform);
	}
	
	// some animation durations need to be slightly longer on iPad since more distance to travel, so assign a scale factor
	CGFloat durationScale = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 1.2 : 1.0;
	
	// fade animation
	if (animation == URBAlertAnimationFade) {
		if (show) {
			[self showOverlay:YES];
			
			self.alpha = 0.0f;
			self.transform = CGAffineTransformScale(transform, 0.95, 0.95);
			[UIView animateWithDuration:0.2 animations:^{
				self.alpha = 1.0f;
				self.transform = transform;
			} completion:^(BOOL finished) {
				[self alertViewDidShow];
				if (completion)
					completion();
			}];
		}
		else {
			[self showOverlay:NO];
			
			[UIView animateWithDuration:0.2 animations:^{
				self.transform = CGAffineTransformScale(transform, 0.95, 0.95);
				self.alpha = 0.0f;
			} completion:^(BOOL finished) {
				self.transform = transform;
				[self cleanup];
				if (completion)
					completion();
			}];
		}
	}
	
	// flip animation
	else if (animation == URBAlertAnimationFlipHorizontal || animation == URBAlertAnimationFlipVertical) {
		
		CGFloat xAxis = (animation == URBAlertAnimationFlipVertical) ? 1.0 : 0.0;
		CGFloat yAxis = (animation == URBAlertAnimationFlipHorizontal) ? 1.0 : 0.0;
		CGFloat firstDurationScale = (animation == URBAlertAnimationFlipHorizontal) ? 1.2 : 1.0;
		
		// define our 3d perspective for the flip effect
		self.layer.zPosition = 100;
		CATransform3D perspectiveTransform = CATransform3DMakeAffineTransform(transform);
		perspectiveTransform.m34 = 1.0 / -500;
		
		if (show) {
			[self showOverlay:YES];
			
			// initial starting rotation
			self.layer.transform = CATransform3DConcat(CATransform3DMakeRotation(70.0 * M_PI / 180.0, xAxis, yAxis, 0.0), perspectiveTransform);
			self.alpha = 0.0f;
			
			[UIView animateWithDuration:0.2 * firstDurationScale animations:^{ // flip remaining + bounce
				self.layer.transform = CATransform3DConcat(CATransform3DMakeRotation(-25.0 * M_PI / 180.0, xAxis, yAxis, 0.0), perspectiveTransform);
				self.alpha = 1.0f;
			} completion:^(BOOL finished) {
				[UIView animateWithDuration:0.13 animations:^{
					self.layer.transform = CATransform3DConcat(CATransform3DMakeRotation(12.0 * M_PI / 180.0, xAxis, yAxis, 0.0), perspectiveTransform);
				} completion:^(BOOL finished) {
					[UIView animateWithDuration:0.1 animations:^{
						self.layer.transform = CATransform3DConcat(CATransform3DMakeRotation(-8.0 * M_PI / 180.0, xAxis, yAxis, 0.0), perspectiveTransform);
					} completion:^(BOOL finished) {
						[UIView animateWithDuration:0.1 animations:^{
							self.layer.transform = CATransform3DConcat(CATransform3DMakeRotation(0.0 * M_PI / 180.0, xAxis, yAxis, 0.0), perspectiveTransform);
						} completion:^(BOOL finished) {
							[self alertViewDidShow];
							if (completion)
								completion();
						}];
					}];
				}];
			}];
		}
		else {
			[self showOverlay:NO];
			
			// initial transform on dismissal is same as ending transform on present
			self.layer.transform = CATransform3DConcat(CATransform3DMakeRotation(0.0 * M_PI / 180.0, xAxis, yAxis, 0.0), perspectiveTransform);
			self.alpha = 1.0f;
			
			[UIView animateWithDuration:0.08 animations:^{
				self.layer.transform = CATransform3DConcat(CATransform3DMakeRotation(-10.0 * M_PI / 180.0, xAxis, yAxis, 0.0), perspectiveTransform);
			} completion:^(BOOL finished) {
				[UIView animateWithDuration:0.17 * firstDurationScale animations:^{
					self.layer.transform = CATransform3DConcat(CATransform3DMakeRotation(70.0 * M_PI / 180.0, xAxis, yAxis, 0.0), perspectiveTransform);
					self.alpha = 0.0f;
				} completion:^(BOOL finished) {
					[self cleanup];
					if (completion)
						completion();
				}];
			}];
		}
	}
	
	// tumble animation
	else if (animation == URBAlertAnimationTumble) {
		if (show) {
			[self showOverlay:YES];
			
			CGAffineTransform rotate = CGAffineTransformRotate(transform, 50.0 * M_PI / 180.0);
			CGAffineTransform translate = CGAffineTransformTranslate(transform, 20.0, -screenSize.height / 2.0 - CGRectGetWidth(self.bounds));
			self.transform = CGAffineTransformConcat(rotate, translate);
			
			[UIView animateWithDuration:0.4 * durationScale delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
				//self.layer.transform = CATransform3DIdentity;
				self.transform = transform;
			} completion:^(BOOL finished) {
				[self alertViewDidShow];
				if (completion)
					completion();
			}];
		}
		else {
			[self showOverlay:NO];
			
			CGAffineTransform rotate = CGAffineTransformRotate(transform, -50.0 * M_PI / 180.0);
			CGAffineTransform translate = CGAffineTransformTranslate(transform, 20.0, screenSize.height / 2.0 + CGRectGetWidth(self.bounds));
			
			[UIView animateWithDuration:0.4 * durationScale delay:0.0 options:UIViewAnimationOptionCurveEaseIn animations:^{
				self.transform = CGAffineTransformConcat(rotate, translate);
			} completion:^(BOOL finished) {
				[self cleanup];
				if (completion)
					completion();
			}];
		}
	}
	
	// slide animation
	else if (animation == URBAlertAnimationSlideLeft || animation == URBAlertAnimationSlideRight) {
		if (show) {
			[self showOverlay:YES];
			
			CGFloat startX = (animation == URBAlertAnimationSlideLeft) ? screenSize.width / 2.0 + 10.0 : -screenSize.width / 2.0 - 10.0;
			CGFloat shiftX = 10.0;
			if (animation == URBAlertAnimationSlideLeft)
				shiftX *= -1.0;
			
			self.transform = CGAffineTransformTranslate(transform, startX, 0.0);
			[UIView animateWithDuration:0.12 * durationScale delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
				self.transform = CGAffineTransformTranslate(transform, shiftX, 0.0);
			} completion:^(BOOL finished) {
				[UIView animateWithDuration:0.18 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
					self.transform = transform;
				} completion:^(BOOL finished) {
					[self alertViewDidShow];
					if (completion)
						completion();
				}];
			}];
		}
		else {
			[self showOverlay:NO];
			
			CGFloat finalX = (animation == URBAlertAnimationSlideLeft) ? -screenSize.width / 2.0 - 10.0 : screenSize.width / 2.0 + 10.0;
			CGFloat shiftX = 10.0;
			if (animation == URBAlertAnimationSlideRight)
				shiftX *= 1.0;
			
			[UIView animateWithDuration:0.18 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
				self.transform = CGAffineTransformTranslate(transform, shiftX, 0.0);
			} completion:^(BOOL finished) {
				[UIView animateWithDuration:0.12 * durationScale delay:0.0 options:UIViewAnimationOptionCurveEaseIn animations:^{
					self.transform = CGAffineTransformTranslate(self.transform, finalX, 0.0);
				} completion:^(BOOL finished) {
					[self cleanup];
					if (completion)
						completion();
				}];
			}];
		}
	}
	
	// default "pop" animation like UIAlertView
	else {
		if (show) {
			[self showOverlay:YES];
			
			self.alpha = 0.0f;
			self.transform = CGAffineTransformScale(transform, 0.7, 0.7);
			
			[UIView animateWithDuration:0.18 animations:^{
				self.transform = CGAffineTransformScale(transform, 1.1, 1.1);
				self.alpha = 1.0f;
			} completion:^(BOOL finished) {
				[UIView animateWithDuration:0.13 animations:^{
					self.transform = CGAffineTransformScale(transform, 0.9, 0.9);
				} completion:^(BOOL finished) {
					[UIView animateWithDuration:0.1 animations:^{
						self.transform = transform;
					} completion:^(BOOL finished) {
						[self alertViewDidShow];
						if (completion)
							completion();
					}];
				}];
			}];
		}
		else {
			[self showOverlay:NO];
			
			[UIView animateWithDuration:0.13 animations:^{
				self.transform = CGAffineTransformScale(transform, 1.1, 1.1);
			} completion:^(BOOL finished) {
				[UIView animateWithDuration:0.18 animations:^{
					self.transform = CGAffineTransformScale(transform, 0.7, 0.7);
					self.alpha = 0.0f;
				} completion:^(BOOL finished) {
					[self cleanup];
					if (completion)
						completion();
				}];
			}];
		}
	}
}

#pragma mark - Drawing

- (void)build {
	//[super layoutSubviews];
	
	if (!self.contentView) {
		self.contentView = [[UIView alloc] initWithFrame:CGRectZero];
		self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
		[self addSubview:self.contentView];
	}
	
	self.layer.shadowColor = [UIColor blackColor].CGColor;
	self.layer.shadowOpacity = 0.8;
	self.layer.shadowOffset = CGSizeMake(0, 1.0);
	self.layer.shadowRadius = 5.0;
}

- (void)layoutSubviews {
	[super layoutSubviews];	
	[self layoutComponents];
	
	// rotation and position based on the new layout
	[self reposition];
}

- (void)layoutComponents {
	self.layer.transform = CATransform3DIdentity;
	self.transform = CGAffineTransformIdentity;
	
	CGRect defaultFrame = [self defaultFrame];
	CGFloat layoutFrameInset = kURBAlertFrameInset + kURBAlertPadding;
	CGRect layoutFrame = CGRectInset(CGRectMake(0, 0, CGRectGetWidth(defaultFrame), CGRectGetHeight(defaultFrame)), layoutFrameInset, layoutFrameInset);
	CGRect textFrame = CGRectInset(layoutFrame, 6.0, 0.0);
	CGFloat layoutWidth = CGRectGetWidth(layoutFrame);
	
	self.contentView.frame = layoutFrame;
	
	// title frame
	CGFloat titleHeight = 0;
	CGFloat minY = CGRectGetMinY(textFrame);
	if (self.title.length > 0) {
		if ([self.title respondsToSelector:@selector(boundingRectWithSize:options:attributes:context:)]) {
			CGRect titleBounds = [self.title boundingRectWithSize:CGSizeMake(CGRectGetWidth(textFrame), MAXFLOAT)
														  options:(NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading)
													   attributes:@{NSFontAttributeName:self.titleFont}
														  context:nil];
			titleHeight = titleBounds.size.height;
		}
		else {
			CGSize titleSize = [self.title sizeWithFont:self.titleFont
									  constrainedToSize:CGSizeMake(CGRectGetWidth(textFrame), MAXFLOAT)
										  lineBreakMode:NSLineBreakByWordWrapping];
			titleHeight = titleSize.height;
		}
		titleHeight = ceilf(titleHeight);
		minY += kURBAlertPadding;
	}
	layout.titleRect = CGRectMake(CGRectGetMinX(textFrame), minY, CGRectGetWidth(textFrame), titleHeight);
	
	// message frame
	CGFloat messageHeight = 0;
	minY = CGRectGetMaxY(layout.titleRect);
	if (self.message.length > 0) {
		if ([self.title respondsToSelector:@selector(boundingRectWithSize:options:attributes:context:)]) {
			CGRect messageBounds = [self.message boundingRectWithSize:CGSizeMake(CGRectGetWidth(textFrame), MAXFLOAT)
															  options:(NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading)
														   attributes:@{NSFontAttributeName:self.messageFont}
															  context:nil];
			messageHeight = messageBounds.size.height;
		}
		else {
			CGSize messageSize = [self.message sizeWithFont:self.messageFont
										  constrainedToSize:CGSizeMake(CGRectGetWidth(textFrame), MAXFLOAT)
											  lineBreakMode:NSLineBreakByWordWrapping];
			messageHeight = messageSize.height;
		}
		messageHeight = ceilf(messageHeight);
		minY += kURBAlertPadding;
	}
	layout.messageRect = CGRectMake(CGRectGetMinX(textFrame), minY, CGRectGetWidth(textFrame), messageHeight);
	
	// text fields frame
	CGFloat textFieldsHeight = 0;
	NSUInteger totalFields = self.textFields.count;
	CGFloat fieldBottomPadding = 0;
	minY = CGRectGetMaxY(layout.messageRect);
	if (totalFields > 0) {
		textFieldsHeight = kURBAlertTextFieldHeight * (CGFloat)totalFields + kURBAlertPadding * (CGFloat)totalFields;
		//minY += kURBAlertPadding;
		fieldBottomPadding = 5.0;
	}
	layout.textFieldsRect = CGRectMake(kURBAlertPadding, minY, layoutWidth - kURBAlertPadding * 2, textFieldsHeight);
	
	// reset main frame based on title and message heights and set background frame and image
	CGFloat buttonRegionOffsetY = ([self.buttons count] > 2) ? (kURBAlertButtonHeight * [self.buttons count] + kURBAlertButtonPadding * ([self.buttons count] - 1) + 16) : kURBAlertButtonOffset;
	self.frame = CGRectMake(0, 0, CGRectGetWidth(defaultFrame), CGRectGetMaxY(layout.textFieldsRect) + kURBAlertPadding + buttonRegionOffsetY + layoutFrameInset + fieldBottomPadding);
	self.backgroundView.frame = self.bounds;
	
	CGFloat buttonRegionHeight = buttonRegionOffsetY + self.strokeWidth / 2.0;
	layout.buttonRegionRect = CGRectMake(kURBAlertFrameInset, CGRectGetHeight(self.bounds) - buttonRegionHeight - kURBAlertFrameInset,
										 CGRectGetWidth(self.bounds) - kURBAlertFrameInset * 2.0, buttonRegionOffsetY);
		
	// buttons frame
	NSUInteger totalButtons = [self.buttons count];
	CGFloat buttonsHeight = 0;
	CGFloat buttonRegionPadding = ((kURBAlertButtonOffset - kURBAlertFrameInset) - kURBAlertButtonHeight) / 2.0 - 2.0;
	minY = CGRectGetMinY(layout.buttonRegionRect) + buttonRegionPadding;
	if (totalButtons > 0) {
		buttonsHeight = kURBAlertButtonHeight;
		minY += kURBAlertPadding;
	}
	CGFloat buttonsOffsetY = (totalButtons > 2) ? CGRectGetMinY(layout.buttonRegionRect) + 8.0 : CGRectGetMidY(layout.buttonRegionRect) - kURBAlertButtonHeight / 2.0;
	layout.buttonRect = CGRectMake(CGRectGetMinX(layoutFrame), buttonsOffsetY, layoutWidth, buttonsHeight);
	// adjust layout frame
	layoutFrame.size.height = CGRectGetMaxY(layout.buttonRect);
	
	// layout textfields
	NSUInteger fieldCount = self.textFields.count;
	if (fieldCount > 0) {
		for (int i = 0; i < fieldCount; i++) {
			CGFloat yOffset = CGRectGetMinY(layout.textFieldsRect) + (kURBAlertButtonPadding + kURBAlertTextFieldHeight) * (CGFloat)i;
			CGRect frame = CGRectIntegral(CGRectMake(CGRectGetMinX(layout.textFieldsRect), yOffset, CGRectGetWidth(layout.textFieldsRect), kURBAlertTextFieldHeight));
			
			UITextField *field = (UITextField *)[self.textFields objectAtIndex:i];
			field.frame = frame;
			field.autoresizingMask = UIViewAutoresizingFlexibleWidth;
			
			[self.contentView addSubview:field];
		}
	}
	
	// layout buttons
	// if we have more than two buttons, we lay out buttons vertically, otherwise two buttons are placed next to each other horizontally
	NSUInteger count = self.buttons.count;
	if (count > 0) {
		
		// if we are laying buttons out vertically (more than two buttons) and we have a cancel button, shift array so cancel button will always be
		// inserted at the bottom of the button column
		if (count > 2 && self.cancelButton != nil) {
			if ([self buttonAtIndex:0] == self.cancelButton) {
				[self.buttons removeObject:self.cancelButton];
				[self.buttons addObject:self.cancelButton];
			}
		}
		
		CGFloat buttonWidth = (totalButtons > 2) ? CGRectGetWidth(layout.buttonRect) : (CGRectGetWidth(layout.buttonRect) - kURBAlertButtonPadding * ((CGFloat)count - 1.0)) / (CGFloat)count;
		for (int i = 0; i < count; i++) {
			CGFloat xOffset = CGRectGetMinX(layout.buttonRect);
			CGFloat yOffset = CGRectGetMinY(layout.buttonRect);
			
			if (totalButtons > 2) {
				yOffset = CGRectGetMinY(layout.buttonRect) + (kURBAlertButtonHeight + kURBAlertButtonPadding) * (CGFloat)i;
			}
			else {
				xOffset = CGRectGetMinX(layout.buttonRect) + (kURBAlertButtonPadding + buttonWidth) * (CGFloat)i;
			}
			
			CGRect frame = CGRectIntegral(CGRectMake(xOffset, yOffset, buttonWidth, CGRectGetHeight(layout.buttonRect)));
			
			URBAlertViewButton *button = (URBAlertViewButton *)[self.buttons objectAtIndex:i];
			button.frame = frame;
			button.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
			
			[self addSubview:button];
		}
	}
		
	UIWindow *window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	CGRect dialogFrame = self.frame;
	dialogFrame.origin.x = (CGRectGetWidth(window.bounds) - CGRectGetWidth(dialogFrame)) / 2.0;
	dialogFrame.origin.y = (CGRectGetHeight(window.bounds) - CGRectGetHeight(dialogFrame)) / 2.0;
	self.frame = CGRectIntegral(dialogFrame);
	
	[self reposition];
	_hasLaidOut = YES;
}

- (void)drawRect:(CGRect)rect {
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	
	// base shape
	CGRect activeBounds = rect;
	CGRect backgroundBaseRect = CGRectInset(self.bounds, kURBAlertFrameInset, kURBAlertFrameInset);
	
	// colors
	UIColor* baseGradientTopColor = self.backgroundTopColor;
	UIColor* baseGradientBottomColor = self.backgroundBottomColor;
	UIColor* baseStrokeColor = self.strokeColor;
	
	// gradients
	NSArray* baseGradientColors = @[(id)baseGradientTopColor.CGColor, (id)baseGradientBottomColor.CGColor];
	CGFloat baseGradientLocations[] = {0, 1};
	CGGradientRef baseGradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)baseGradientColors, baseGradientLocations);
		
	// background
	UIBezierPath *backgroundBasePath = [UIBezierPath bezierPathWithRoundedRect:backgroundBaseRect cornerRadius:self.cornerRadius];
	CGContextSaveGState(context);
	[backgroundBasePath addClip];
	CGContextDrawLinearGradient(context, baseGradient,
								CGPointMake(CGRectGetMidX(backgroundBaseRect), CGRectGetMinY(backgroundBaseRect)),
								CGPointMake(CGRectGetMidX(backgroundBaseRect), CGRectGetMaxY(backgroundBaseRect)),
								0);
	CGContextRestoreGState(context);
	
	// hatched background behind buttons
	CGFloat buttonOffset = CGRectGetHeight(backgroundBaseRect) - CGRectGetHeight(layout.buttonRegionRect); // offset buttonOffset by half point for crisp lines
	CGContextSaveGState(context); // save context state before clipping "hatchPath"
	CGRect hatchFrame = CGRectMake(CGRectGetMinX(backgroundBaseRect), CGRectGetMinY(backgroundBaseRect) + buttonOffset, CGRectGetWidth(backgroundBaseRect), CGRectGetHeight(layout.buttonRegionRect));
	CGContextClipToRect(context, hatchFrame);
	CGFloat spacer = 4.0f;
	int rows = (activeBounds.size.width + activeBounds.size.height/spacer);
	CGFloat padding = 0.0f;
	CGMutablePathRef hatchPath = CGPathCreateMutable();
	for(int i=1; i<=rows; i++) {
		CGPathMoveToPoint(hatchPath, NULL, spacer * i, padding);
		CGPathAddLineToPoint(hatchPath, NULL, padding, spacer * i);
	}
	CGContextAddPath(context, hatchPath);
	CGPathRelease(hatchPath);
	CGContextSetLineWidth(context, 1.0f);
	CGContextSetLineCap(context, kCGLineCapRound);
	CGContextSetStrokeColorWithColor(context, self.hatchLineColor.CGColor);
	CGContextDrawPath(context, kCGPathStroke);
	CGContextRestoreGState(context);
	
	// keylines
	CGContextSaveGState(context);
	UIBezierPath *keylinePath = [UIBezierPath bezierPath];
	[keylinePath moveToPoint:CGPointMake(CGRectGetMinX(backgroundBaseRect), 0)];
	[keylinePath addLineToPoint:CGPointMake(CGRectGetMaxX(backgroundBaseRect), 0)];
	keylinePath.lineWidth = 1.0;
	
	CGContextTranslateCTM(context, 0, CGRectGetMinY(hatchFrame) - 2.0);
	[self.darkKeylineColor setStroke];
	[keylinePath stroke];
	CGContextTranslateCTM(context, 0, 1.0);
	[self.lightKeylineColor setStroke];
	[keylinePath stroke];
	CGContextRestoreGState(context);
	
	UIBezierPath *backgroundStrokePath = backgroundBasePath;
	NSInteger stroke = self.strokeWidth;
	if (stroke % 2 > 0) {
		backgroundStrokePath = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(backgroundBaseRect, -0.5, -0.5) cornerRadius:self.cornerRadius];
	}
	
	[baseStrokeColor setStroke];
	backgroundStrokePath.lineWidth = self.strokeWidth;
	[backgroundStrokePath stroke];
	
	[self drawText:self.title inRect:layout.titleRect font:self.titleFont color:self.titleColor shadowColor:self.titleShadowColor shadowOffset:self.titleShadowOffset];	
	[self drawText:self.message inRect:layout.messageRect font:self.messageFont color:self.messageColor shadowColor:self.messageShadowColor shadowOffset:self.messageShadowOffset];
}

- (void)drawText:(NSString *)text inRect:(CGRect)rect font:(UIFont *)font color:(UIColor *)color shadowColor:(UIColor *)shadowColor shadowOffset:(CGSize)shadowOffset {
	if (text.length > 0) {
		CGContextRef context = UIGraphicsGetCurrentContext();
		CGContextSaveGState(context);
		
		if (!font) font = [UIFont systemFontOfSize:12.0];
		if (!color) color = [UIColor whiteColor];
		[color set];
		if (shadowColor != nil && !CGSizeEqualToSize(shadowOffset, CGSizeZero)) {
			CGContextSetShadowWithColor(context, shadowOffset, 0.0, shadowColor.CGColor);
		}
		
		if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1) {
			// iOS 7 and later
			NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
			style.lineBreakMode = NSLineBreakByWordWrapping;
			style.alignment = NSTextAlignmentCenter;
			
			NSDictionary *textAttributes = @{NSFontAttributeName: font,
											 NSForegroundColorAttributeName: color,
											 NSParagraphStyleAttributeName: style};
			[text drawInRect:rect withAttributes:textAttributes];
		}
		else {
			[text drawInRect:rect withFont:font lineBreakMode:NSLineBreakByWordWrapping alignment:NSTextAlignmentCenter];
		}
		
		CGContextRestoreGState(context);		
	}
}

- (UIImage *)defaultBackgroundImage {
	UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, 0);
	
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	// base shape
	CGRect activeBounds = self.bounds;
	CGFloat cornerRadius = kURBAlertBackgroundRadius;
	CGRect pathFrame = CGRectInset(self.bounds, kURBAlertFrameInset, kURBAlertFrameInset);
	CGPathRef path = [UIBezierPath bezierPathWithRoundedRect:pathFrame cornerRadius:cornerRadius].CGPath;
	
	// fill and drop shadow
	CGContextAddPath(context, path);
	CGContextSetFillColorWithColor(context, [UIColor colorWithRed:210.0f/255.0f green:210.0f/255.0f blue:210.0f/255.0f alpha:1.0f].CGColor);
	//CGContextSetShadowWithColor(context, CGSizeMake(0.0f, 1.0f), 6.0f, [UIColor colorWithRed:0.0f/255.0f green:0.0f/255.0f blue:0.0f/255.0f alpha:1.0f].CGColor);
	CGContextDrawPath(context, kCGPathFill);
	
	// clip context to main shape
	CGContextSaveGState(context);
	CGContextAddPath(context, path);
	CGContextClip(context);
	
	// background gradient
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	size_t count = 3;
	CGFloat locations[3] = {0.0f, 0.57f, 1.0f};
	CGFloat components[12] =
    {
        70.0f/255.0f, 70.0f/255.0f, 70.0f/255.0f, 1.0f,     //1
        55.0f/255.0f, 55.0f/255.0f, 55.0f/255.0f, 1.0f,     //2
        40.0f/255.0f, 40.0f/255.0f, 40.0f/255.0f, 1.0f      //3
    };
	CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, count);
	CGPoint startPoint = CGPointMake(activeBounds.size.width * 0.5f, 0.0f);
	CGPoint endPoint = CGPointMake(activeBounds.size.width * 0.5f, activeBounds.size.height);
	CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
	CGColorSpaceRelease(colorSpace);
	CGGradientRelease(gradient);
	
	// hatched background behind buttons
	CGFloat buttonOffset = activeBounds.size.height - kURBAlertButtonOffset; // offset buttonOffset by half point for crisp lines
	CGContextSaveGState(context); // save context state before clipping "hatchPath"
	CGRect hatchFrame = CGRectMake(0.0f, buttonOffset, activeBounds.size.width, (activeBounds.size.height - buttonOffset+1.0f));
	CGContextClipToRect(context, hatchFrame);
	CGFloat spacer = 4.0f;
	int rows = (activeBounds.size.width + activeBounds.size.height/spacer);
	CGFloat padding = 0.0f;
	CGMutablePathRef hatchPath = CGPathCreateMutable();
	for(int i=1; i<=rows; i++) {
		CGPathMoveToPoint(hatchPath, NULL, spacer * i, padding);
		CGPathAddLineToPoint(hatchPath, NULL, padding, spacer * i);
	}
	CGContextAddPath(context, hatchPath);
	CGPathRelease(hatchPath);
	CGContextSetLineWidth(context, 1.0f);
	CGContextSetLineCap(context, kCGLineCapRound);
	CGContextSetStrokeColorWithColor(context, [UIColor colorWithRed:0.0f/255.0f green:0.0f/255.0f blue:0.0f/255.0f alpha:0.15f].CGColor);
	CGContextDrawPath(context, kCGPathStroke);
	CGContextRestoreGState(context);
	
	// dividing line
	CGMutablePathRef linePath = CGPathCreateMutable();
	CGFloat linePathY = (buttonOffset - 1.0f);
	CGPathMoveToPoint(linePath, NULL, 0.0f, linePathY);
	CGPathAddLineToPoint(linePath, NULL, activeBounds.size.width, linePathY);
	CGContextAddPath(context, linePath);
	CGPathRelease(linePath);
	CGContextSetLineWidth(context, 1.0f);
	CGContextSaveGState(context);
	CGContextSetStrokeColorWithColor(context, [UIColor colorWithRed:0.0f/255.0f green:0.0f/255.0f blue:0.0f/255.0f alpha:0.6f].CGColor);
	CGContextSetShadowWithColor(context, CGSizeMake(0.0f, 1.0f), 0.0f, [UIColor colorWithRed:255.0f/255.0f green:255.0f/255.0f blue:255.0f/255.0f alpha:0.2f].CGColor);
	CGContextDrawPath(context, kCGPathStroke);
	CGContextRestoreGState(context);
	
	// inner shadow
	CGContextAddPath(context, path);
	CGContextSetLineWidth(context, 3.0f);
	CGContextSetStrokeColorWithColor(context, [UIColor colorWithRed:210.0f/255.0f green:210.0f/255.0f blue:210.0f/255.0f alpha:1.0f].CGColor);
	CGContextSetShadowWithColor(context, CGSizeMake(0.0f, 0.0f), 6.0f, [UIColor colorWithRed:0.0f/255.0f green:0.0f/255.0f blue:0.0f/255.0f alpha:1.0f].CGColor);
	CGContextDrawPath(context, kCGPathStroke);
	
	// redraw outer line to avoid pixelation on rounded corners after clipping
	CGContextRestoreGState(context); // restore first context state before clipping path
	CGContextAddPath(context, path);
	CGContextSetLineWidth(context, 3.0f);
	CGContextSetStrokeColorWithColor(context, [UIColor colorWithRed:210.0f/255.0f green:210.0f/255.0f blue:210.0f/255.0f alpha:1.0f].CGColor);
	CGContextSetShadowWithColor(context, CGSizeMake(0.0f, 0.0f), 0.0f, [UIColor colorWithRed:0.0f/255.0f green:0.0f/255.0f blue:0.0f/255.0f alpha:0.1f].CGColor);
	CGContextDrawPath(context, kCGPathStroke);
	
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	
	CGFloat topCap = CGRectGetMidY(activeBounds) - 10.0;
	CGFloat bottomCap = kURBAlertButtonOffset;
	CGFloat leftCap = CGRectGetMidX(activeBounds) - 10.0;
	
	return [image resizableImageWithCapInsets:UIEdgeInsetsMake(topCap, leftCap, bottomCap, leftCap)];
}

#pragma mark - Private

- (CGRect)defaultFrame {
	CGRect appFrame = [[UIScreen mainScreen] applicationFrame];
	// keep alert view in center of app frame
	CGRect insetFrame = CGRectIntegral(CGRectInset(appFrame, (appFrame.size.width - kURBAlertViewDefaultSize.width) / 2, (appFrame.size.height - kURBAlertViewDefaultSize.height) / 2));
	
	return insetFrame;
}

- (void)buttonTapped:(id)button {
	NSUInteger buttonIndex = [self.buttons indexOfObject:(URBAlertViewButton *)button];
	if (self.block) {
		self.block(buttonIndex, self);
	}
	else if ([self.buttons count] == 1) {
		// if only a single button and no handler block, then it's probably just an "OK" button so automatically hide
		[self hide];
	}
}

- (UIView *)blurredBackground {
	UIView *backgroundView = [[UIApplication sharedApplication] keyWindow];
	UIImageView *blurredView = [[UIImageView alloc] initWithFrame:backgroundView.bounds];
	blurredView.image = [[backgroundView screenshot] boxblurImageWithBlur:0.08];
	
	return blurredView;
}

- (void)showOverlay:(BOOL)show {
	if (show) {
		// create a new window to add our overlay and dialogs to
		UIWindow *window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
		self.window = window;
		window.windowLevel = UIWindowLevelStatusBar + 1;
		window.opaque = NO;
		
		// darkened background
		if (self.darkenBackground) {
			self.overlay = [URBAlertWindowOverlay new];
			URBAlertWindowOverlay *overlay = self.overlay;
			overlay.opaque = NO;
			overlay.alertView = self;
			overlay.frame = self.window.bounds;
			overlay.alpha = 0.0;
		}
		
//		// blurred background
//		if (self.blurBackground) {
//			self.blurredBackgroundView = [self blurredBackground];
//			self.blurredBackgroundView.alpha = 0.0f;
//			[self.window addSubview:self.blurredBackgroundView];
//		}
		
		[self.window addSubview:self.overlay];
		[self.window addSubview:self];
		
		// window has to be un-hidden on the main thread
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.window makeKeyAndVisible];
			
			// fade in overlay
			[UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionLayoutSubviews animations:^{
				//self.blurredBackgroundView.alpha = 1.0f;
				self.overlay.alpha = 1.0f;
			} completion:^(BOOL finished) {
				// stub
			}];
		});
	}
	else {
		[UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionLayoutSubviews animations:^{
			self.overlay.alpha = 0.0f;
			//self.blurredBackground.alpha = 0.0f;
		} completion:^(BOOL finished) {
			self.blurredBackgroundView = nil;
		}];
	}
}

- (void)alertViewDidShow {
	if ([self.textFields count] > 0) {
		UITextField *textField = (UITextField *)[self.textFields objectAtIndex:0];
		[textField becomeFirstResponder];
	}
}

- (void)cleanup {
	// dismiss keyboard if currently active
	if (self.focusedTextField) {
		[self.focusedTextField resignFirstResponder];
	}
	//self.layer.transform = CATransform3DIdentity;
	//self.transform = CGAffineTransformIdentity;
	self.alpha = 1.0f;
	self.window = nil;
	// rekey main AppDelegate window
	[[[[UIApplication sharedApplication] delegate] window] makeKeyWindow];
}

#pragma mark - Orientation Helpers

- (void)deviceOrientationChanged:(NSNotification *)notification {
	UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
	if (_currentOrientation != orientation) {
		_currentOrientation = orientation;
		[self reposition];
	}
}

- (CGAffineTransform)transformForOrientation:(UIInterfaceOrientation)orientation {
	CGAffineTransform transform = CGAffineTransformIdentity;
	
	// calculate a rotation transform that matches the required orientation
	if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
		transform = CGAffineTransformMakeRotation(M_PI);
	}
	else if (orientation == UIInterfaceOrientationLandscapeLeft) {
		transform = CGAffineTransformMakeRotation(-M_PI_2);
	}
	else if (orientation == UIInterfaceOrientationLandscapeRight) {
		transform = CGAffineTransformMakeRotation(M_PI_2);
	}
	
	return transform;
}

- (void)reposition {
	CGAffineTransform baseTransform = [self transformForOrientation:_currentOrientation];
	
	// block used for repositioning ourselves to account for keyboard and interface orientation changes
	URBAnimationBlock layoutBlock = ^{
		self.transform = baseTransform;
	};
	
	// determine if the rotation we're about to undergo is 90 or 180 degrees
	CGAffineTransform t1 = self.transform;
	CGAffineTransform t2 = baseTransform;	
	CGFloat dot = t1.a * t2.a + t1.c * t2.c;
	CGFloat n1 = sqrtf(t1.a * t1.a + t1.c * t1.c);
	CGFloat n2 = sqrtf(t2.a * t2.a + t2.c * t2.c);
	CGFloat rotationDelta = acosf(dot / (n1 * n2));
	const CGFloat HALF_PI = 1.581;
	BOOL isDoubleRotation = (rotationDelta > HALF_PI);
	
	// use the system rotation duration
	CGFloat duration = [UIApplication sharedApplication].statusBarOrientationAnimationDuration;
	// iPad lies about its rotation duration
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) { duration = 0.4; }
	
	// double the animation duration if we're rotation 180 degrees
	if (isDoubleRotation) { duration *= 2; }
	
	// if we haven't laid out the subviews yet, we don't want to animate rotation and position transforms
	if (_hasLaidOut) {
		[UIView animateWithDuration:duration animations:layoutBlock];
	}
	else {
		layoutBlock();
	}
}

#pragma mark - Keyboard Helpers

- (void)keyboardWillShow:(NSNotification *)note {
	NSValue *value = [[note userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey];
	CGRect frame = [value CGRectValue];
	
	[self adjustToKeyboardBounds:frame];
}

- (void)keyboardWillHide:(NSNotification *)note {
	[self adjustToKeyboardBounds:CGRectZero];
}

- (void)adjustToKeyboardBounds:(CGRect)bounds {
	CGRect screenBounds = [[UIScreen mainScreen] bounds];
	CGFloat height = CGRectGetHeight(screenBounds) - CGRectGetHeight(bounds);
	CGRect frame = self.frame;
	frame.origin.y = (height - CGRectGetHeight(self.bounds)) / 2.0;
	
	if (CGRectGetMinY(frame) < 0) {
		NSLog(@"warning: dialog is clipped, origin negative (%f)", CGRectGetMinY(frame));
	}
	
	[UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
		self.frame = frame;
	} completion:nil];
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField {
	self.focusedTextField = textField;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
	self.focusedTextField = nil;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	NSUInteger index = [self.textFields indexOfObject:textField];
	NSUInteger count = self.textFields.count;
	
	if (index < (count - 1)) {
		UITextField *nextField = [self.textFields objectAtIndex:index + 1];
		[nextField becomeFirstResponder];
	}
	else {
		[textField resignFirstResponder];
	}
	
	return YES;
}

@end


#pragma mark - URBAlertWindowOverlay

@implementation URBAlertWindowOverlay

- (void)drawRect:(CGRect)rect {
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	/// colors
	UIColor *gradientOuter = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 0.4];
	UIColor *gradientInner = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 0.1];
	
	NSArray *radialGradientColors = @[(id)gradientInner.CGColor, (id)gradientOuter.CGColor];
	CGFloat radialGradientLocations[] = {0, 0.5, 1};
	CGGradientRef radialGradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)radialGradientColors, radialGradientLocations);
	
	// main shape
	UIBezierPath *rectanglePath = [UIBezierPath bezierPathWithRect: CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height)];
	CGContextSaveGState(context);
	[rectanglePath addClip];
	CGContextDrawRadialGradient(context, radialGradient,
								CGPointMake(rect.origin.x + rect.size.width / 2, rect.origin.y + rect.size.height / 2), rect.size.width / 4,
								CGPointMake(rect.origin.x + rect.size.width / 2, rect.origin.y + rect.size.height / 2), rect.size.width,
								kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
	CGContextRestoreGState(context);
	
	CGGradientRelease(radialGradient);
	CGColorSpaceRelease(colorSpace);
}

@end


#pragma mark - URBAlertViewButton

@implementation URBAlertViewButton {
	BOOL _hasDrawnBackgrounds;
}

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		_hasDrawnBackgrounds = NO;
		_backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
		_strokeColor = [UIColor colorWithWhite:0.2 alpha:1.0];
		_buttonStyle = URBAlertViewDefaultButtonType;
	}
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	
	if (!_hasDrawnBackgrounds) {
		_hasDrawnBackgrounds = YES;
		[self updateBackgrounds];
	}
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
	if (backgroundColor != _backgroundColor) {
		_backgroundColor = backgroundColor;
		
		if (_hasDrawnBackgrounds)
			[self updateBackgrounds];
	}
}

- (void)setStrokeColor:(UIColor *)strokeColor {
	if (strokeColor != _strokeColor) {
		_strokeColor = strokeColor;
		
		if (_hasDrawnBackgrounds)
			[self updateBackgrounds];
	}
}

- (void)setButtonStyle:(URBAlertViewButtonType)buttonStyle {
	if (buttonStyle != _buttonStyle) {
		_buttonStyle = buttonStyle;
		
		if (_hasDrawnBackgrounds)
			[self updateBackgrounds];
	}
}

- (void)updateBackgrounds {
	[self setBackgroundImage:[self normalButtonImage] forState:UIControlStateNormal];
	[self setBackgroundImage:[self selectedButtonImage] forState:UIControlStateHighlighted];
}

- (UIImage *)normalButtonImage {
	UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, 0);
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	// colors
	UIColor *buttonBgGradientColorTop = [UIColor colorWithWhite:0.3 alpha:1.0];
	UIColor *buttonBgGradientColorBottom = [UIColor colorWithWhite:0.25 alpha:1.0];
	UIColor *buttonOuterGradientColor = [self.strokeColor adjustBrightness:1.05];
	UIColor *buttonOuterGradientColor2 = [self.strokeColor adjustBrightness:0.95];
	UIColor *buttonInnerGradientColor = [self.backgroundColor adjustBrightness:1.05];
	UIColor *buttonInnerGradientColor2 = [self.backgroundColor adjustBrightness:0.95];
	
	// gradients
	NSArray *buttonBgGradientColors = @[(id)buttonBgGradientColorTop.CGColor, (id)buttonBgGradientColorBottom.CGColor];
	CGFloat buttonBgGradientLocations[] = {0, 1};
	CGGradientRef buttonBgGradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)buttonBgGradientColors, buttonBgGradientLocations);
	NSArray *buttonOuterGradientColors = @[(id)buttonOuterGradientColor.CGColor, (id)buttonOuterGradientColor2.CGColor];
	CGFloat buttonOuterGradientLocations[] = {0, 1};
	CGGradientRef buttonOuterGradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)buttonOuterGradientColors, buttonOuterGradientLocations);
	NSArray *buttonInnerGradientColors = @[(id)buttonInnerGradientColor.CGColor, (id)buttonInnerGradientColor2.CGColor];
	CGFloat buttonInnerGradientLocations[] = {0, 1};
	CGGradientRef buttonInnerGradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)buttonInnerGradientColors, buttonInnerGradientLocations);
	
	// shadows
	UIColor *buttonShadow = [UIColor blackColor];
	CGSize buttonShadowOffset = CGSizeMake(0.1, -0.1);
	CGFloat buttonShadowBlurRadius = 2;

	CGRect frame = self.bounds;	
	
	// base drawing
	CGRect buttonBgRect = frame;
	UIBezierPath *buttonBgPath = [UIBezierPath bezierPathWithRoundedRect:buttonBgRect cornerRadius:4];
	CGContextSaveGState(context);
	[buttonBgPath addClip];
	CGContextDrawLinearGradient(context, buttonBgGradient,
								CGPointMake(CGRectGetMidX(buttonBgRect), CGRectGetMinY(buttonBgRect)),
								CGPointMake(CGRectGetMidX(buttonBgRect), CGRectGetMaxY(buttonBgRect)),
								0);
	CGContextRestoreGState(context);
	
	// outer drawing
	CGRect buttonOuterRect = CGRectInset(frame, 4.0, 4.0);
	UIBezierPath *buttonOuterPath = [UIBezierPath bezierPathWithRoundedRect:buttonOuterRect cornerRadius:2];
	CGContextSaveGState(context);
	CGContextSetShadowWithColor(context, buttonShadowOffset, buttonShadowBlurRadius, buttonShadow.CGColor);
	CGContextBeginTransparencyLayer(context, NULL);
	[buttonOuterPath addClip];
	CGContextDrawLinearGradient(context, buttonOuterGradient,
								CGPointMake(CGRectGetMidX(buttonOuterRect), CGRectGetMinY(buttonOuterRect)),
								CGPointMake(CGRectGetMidX(buttonOuterRect), CGRectGetMaxY(buttonOuterRect)),
								0);
	CGContextEndTransparencyLayer(context);
	CGContextRestoreGState(context);
	
	
	
	// inner drawing
	CGRect buttonInnerRect = CGRectInset(frame, 6.0, 6.0);
	UIBezierPath *buttonInnerPath = [UIBezierPath bezierPathWithRoundedRect:buttonInnerRect cornerRadius:1];
	CGContextSaveGState(context);
	[buttonInnerPath addClip];
	CGContextDrawLinearGradient(context, buttonInnerGradient,
								CGPointMake(CGRectGetMidX(buttonInnerRect), CGRectGetMinY(buttonInnerRect)),
								CGPointMake(CGRectGetMidX(buttonInnerRect), CGRectGetMaxY(buttonInnerRect)),
								0);
	CGContextRestoreGState(context);	
	
	CGGradientRelease(buttonBgGradient);
	CGGradientRelease(buttonOuterGradient);
	CGGradientRelease(buttonInnerGradient);
	CGColorSpaceRelease(colorSpace);
	
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
	
	CGFloat topInset = CGRectGetMidY(self.bounds) - 1.0;
	
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(topInset, 6.0, topInset, 6.0)];
}

- (UIImage *)selectedButtonImage {
	UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, 0);
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	// colors
	UIColor *buttonBgGradientColorTop = [UIColor colorWithWhite:0.3 alpha:1.0];
	UIColor *buttonBgGradientColorBottom = [UIColor colorWithWhite:0.25 alpha:1.0];
	UIColor *buttonOuterGradientColor = [self.strokeColor adjustBrightness:0.95];
	UIColor *buttonOuterGradientColor2 = [self.strokeColor adjustBrightness:1.05];
	UIColor *buttonInnerGradientColor = [self.backgroundColor adjustBrightness:0.95];
	UIColor *buttonInnerGradientColor2 = [self.backgroundColor adjustBrightness:1.05];
	
	// gradients
	NSArray *buttonBgGradientColors = @[(id)buttonBgGradientColorTop.CGColor, (id)buttonBgGradientColorBottom.CGColor];
	CGFloat buttonBgGradientLocations[] = {0, 1};
	CGGradientRef buttonBgGradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)buttonBgGradientColors, buttonBgGradientLocations);
	NSArray *buttonOuterGradientColors = @[(id)buttonOuterGradientColor.CGColor, (id)buttonOuterGradientColor2.CGColor];
	CGFloat buttonOuterGradientLocations[] = {0, 1};
	CGGradientRef buttonOuterGradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)buttonOuterGradientColors, buttonOuterGradientLocations);
	NSArray *buttonInnerGradientColors = @[(id)buttonInnerGradientColor.CGColor, (id)buttonInnerGradientColor2.CGColor];
	CGFloat buttonInnerGradientLocations[] = {0, 1};
	CGGradientRef buttonInnerGradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)buttonInnerGradientColors, buttonInnerGradientLocations);
	
	// shadows
	UIColor *buttonShadow = [UIColor blackColor];
	CGSize buttonShadowOffset = CGSizeMake(0.1, -0.1);
	CGFloat buttonShadowBlurRadius = 2;
	
	CGRect frame = self.bounds;
	
	// base drawing
	CGRect buttonBgRect = frame;
	UIBezierPath *buttonBgPath = [UIBezierPath bezierPathWithRoundedRect:buttonBgRect cornerRadius:3];
	CGContextSaveGState(context);
	[buttonBgPath addClip];
	CGContextDrawLinearGradient(context, buttonBgGradient,
								CGPointMake(CGRectGetMidX(buttonBgRect), CGRectGetMinY(buttonBgRect)),
								CGPointMake(CGRectGetMidX(buttonBgRect), CGRectGetMaxY(buttonBgRect)),
								0);
	CGContextRestoreGState(context);
	
	
	// outer drawing
	CGRect buttonOuterRect = CGRectInset(frame, 4.0, 4.0);
	UIBezierPath *buttonOuterPath = [UIBezierPath bezierPathWithRoundedRect:buttonOuterRect cornerRadius:2];
	CGContextSaveGState(context);
	CGContextSetShadowWithColor(context, buttonShadowOffset, buttonShadowBlurRadius, buttonShadow.CGColor);
	CGContextBeginTransparencyLayer(context, NULL);
	[buttonOuterPath addClip];
	CGContextDrawLinearGradient(context, buttonOuterGradient,
								CGPointMake(CGRectGetMidX(buttonOuterRect), CGRectGetMinY(buttonOuterRect)),
								CGPointMake(CGRectGetMidX(buttonOuterRect), CGRectGetMaxY(buttonOuterRect)),
								0);
	CGContextEndTransparencyLayer(context);
	CGContextRestoreGState(context);
	
	
	
	// inner drawing
	CGRect buttonInnerRect = CGRectInset(frame, 6.0, 6.0);
	UIBezierPath *buttonInnerPath = [UIBezierPath bezierPathWithRoundedRect:buttonInnerRect cornerRadius:1];
	CGContextSaveGState(context);
	[buttonInnerPath addClip];
	CGContextDrawLinearGradient(context, buttonInnerGradient,
								CGPointMake(CGRectGetMidX(buttonInnerRect), CGRectGetMinY(buttonInnerRect)),
								CGPointMake(CGRectGetMidX(buttonInnerRect), CGRectGetMaxY(buttonInnerRect)),
								0);
	CGContextRestoreGState(context);
	
	CGGradientRelease(buttonBgGradient);
	CGGradientRelease(buttonOuterGradient);
	CGGradientRelease(buttonInnerGradient);
	CGColorSpaceRelease(colorSpace);
	
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
	
    CGFloat topInset = CGRectGetMidY(self.bounds) - 1.0;
	
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(topInset, 6.0, topInset, 6.0)];
}

@end


#pragma mark - URBAlertViewTextField

@implementation URBAlertViewTextField

- (CGRect)textRectForBounds:(CGRect)bounds {
	return CGRectInset(bounds, 4.0, 4.0);
}

- (CGRect)editingRectForBounds:(CGRect)bounds {
	return [self textRectForBounds:bounds];
}

- (void)drawRect:(CGRect)rect {
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSaveGState(context);
	
	// colors
	UIColor *white10 = [UIColor colorWithWhite:1.0 alpha:0.1];
	UIColor *grey40 = [UIColor colorWithWhite:0.4 alpha:1.0];
	
	CGColorRef innerShadow = grey40.CGColor;
	CGSize innerShadowOffset = CGSizeMake(0, 2);
	CGFloat innerShadowBlurRadius = 2;
	CGColorRef outerShadow = white10.CGColor;
	CGSize outerShadowOffset = CGSizeMake(0, 1);
	CGFloat outerShadowBlurRadius = 0;
	
	// base
	UIBezierPath *rectanglePath = [UIBezierPath bezierPathWithRect: CGRectIntegral(rect)];
	CGContextSaveGState(context);
	CGContextSetShadowWithColor(context, outerShadowOffset, outerShadowBlurRadius, outerShadow);
	[[UIColor whiteColor] setFill];
	[rectanglePath fill];
	
	// inner shadow
	CGRect rectangleBorderRect = CGRectInset([rectanglePath bounds], -innerShadowBlurRadius, -innerShadowBlurRadius);
	rectangleBorderRect = CGRectOffset(rectangleBorderRect, -innerShadowOffset.width, -innerShadowOffset.height);
	rectangleBorderRect = CGRectInset(CGRectUnion(rectangleBorderRect, [rectanglePath bounds]), -1, -1);
	
	UIBezierPath* rectangleNegativePath = [UIBezierPath bezierPathWithRect: rectangleBorderRect];
	[rectangleNegativePath appendPath: rectanglePath];
	rectangleNegativePath.usesEvenOddFillRule = YES;
	
	CGContextSaveGState(context);
	{
		CGFloat xOffset = innerShadowOffset.width + round(rectangleBorderRect.size.width);
		CGFloat yOffset = innerShadowOffset.height;
		CGContextSetShadowWithColor(context,
									CGSizeMake(xOffset + copysign(0.1, xOffset), yOffset + copysign(0.1, yOffset)),
									innerShadowBlurRadius,
									innerShadow);
		
		[rectanglePath addClip];
		CGAffineTransform transform = CGAffineTransformMakeTranslation(-round(rectangleBorderRect.size.width), 0);
		[rectangleNegativePath applyTransform: transform];
		[[UIColor grayColor] setFill];
		[rectangleNegativePath fill];
	}
	
	CGContextRestoreGState(context);
	CGContextRestoreGState(context);
	
	[[UIColor blackColor] setStroke];
	rectanglePath.lineWidth = 1;
	[rectanglePath stroke];
	
	CGContextRestoreGState(context);
}

@end


#pragma mark - UIDevice + OSVersion

@implementation UIDevice (OSVersion)

- (BOOL)iOSVersionIsAtLeast:(NSString *)version {
    NSComparisonResult result = [[self systemVersion] compare:version options:NSNumericSearch];
    return (result == NSOrderedDescending || result == NSOrderedSame);
}

@end


#pragma mark - UIView + Screenshot

@implementation UIView (Screenshot)

- (UIImage*)screenshot {
    UIGraphicsBeginImageContext(self.bounds.size);
    [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // hack, helps w/ our colors when blurring
    NSData *imageData = UIImageJPEGRepresentation(image, 1); // convert to jpeg
    image = [UIImage imageWithData:imageData];
    
    return image;
}

@end


#pragma mark - UIImage + Blur

@implementation UIImage (Blur)

-(UIImage *)boxblurImageWithBlur:(CGFloat)blur {
    if (blur < 0.f || blur > 1.f) {
        blur = 0.5f;
    }
    int boxSize = (int)(blur * 50);
    boxSize = boxSize - (boxSize % 2) + 1;
    
    CGImageRef img = self.CGImage;
    vImage_Buffer inBuffer, outBuffer;
    vImage_Error error;
    void *pixelBuffer;
    
    
    //create vImage_Buffer with data from CGImageRef
    CGDataProviderRef inProvider = CGImageGetDataProvider(img);
    CFDataRef inBitmapData = CGDataProviderCopyData(inProvider);
    
    inBuffer.width = CGImageGetWidth(img);
    inBuffer.height = CGImageGetHeight(img);
    inBuffer.rowBytes = CGImageGetBytesPerRow(img);
    
    inBuffer.data = (void*)CFDataGetBytePtr(inBitmapData);
    
    //create vImage_Buffer for output
    pixelBuffer = malloc(CGImageGetBytesPerRow(img) * CGImageGetHeight(img));
    
    if (pixelBuffer == NULL)
        NSLog(@"No pixelbuffer");
    
    outBuffer.data = pixelBuffer;
    outBuffer.width = CGImageGetWidth(img);
    outBuffer.height = CGImageGetHeight(img);
    outBuffer.rowBytes = CGImageGetBytesPerRow(img);
    
    //perform convolution
    error = vImageBoxConvolve_ARGB8888(&inBuffer, &outBuffer, NULL, 0, 0, boxSize, boxSize, NULL, kvImageEdgeExtend);
    
    
    if (error) {
        NSLog(@"error from convolution %ld", error);
    }
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(outBuffer.data,
                                             outBuffer.width,
                                             outBuffer.height,
                                             8,
                                             outBuffer.rowBytes,
                                             colorSpace,
                                             kCGImageAlphaNoneSkipLast);
    CGImageRef imageRef = CGBitmapContextCreateImage (ctx);
    UIImage *returnImage = [UIImage imageWithCGImage:imageRef];
    
    //clean up
    CGContextRelease(ctx);
    CGColorSpaceRelease(colorSpace);
    
    free(pixelBuffer);
    CFRelease(inBitmapData);
    
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(imageRef);
    
    return returnImage;
}

@end


#pragma mark - UIColor+URBAlertView

@implementation UIColor (URBAlertView)

- (UIColor *)adjustBrightness:(CGFloat)amount {
	CGFloat h, s, b, a, w;
	
    if ([self getHue:&h saturation:&s brightness:&b alpha:&a]) {
		b += (amount-1.0);
        b = MAX(MIN(b, 1.0), 0.0);
        return [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
	}
	else if ([self getWhite:&w alpha:&a]) {
		w += (amount-1.0);
        w = MAX(MIN(w, 1.0), 0.0);
		return [UIColor colorWithWhite:w alpha:a];
	}
	
    return nil;
}

@end
