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

@interface UIDevice (OSVersion)
- (BOOL)iOSVersionIsAtLeast:(NSString *)version;
@end

@interface UIView (Screenshot)
- (UIImage*)screenshot;
@end

@interface UIImage (Blur)
-(UIImage *)boxblurImageWithBlur:(CGFloat)blur;
@end



@interface URBAlertWindowOverlay : UIView
@property (nonatomic, strong) URBAlertView *alertView;
@end

@interface URBAlertViewButton : UIButton
@end

@interface URBAlertViewTextField : UITextField
@end

@interface URBAlertView ()
@property (nonatomic, strong) UIImageView *backgroundView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) NSMutableArray *buttons;
@property (nonatomic, strong) NSMutableArray *textFields;
@property (nonatomic, strong) URBAlertWindowOverlay *overlay;
@property (nonatomic, assign) URBAlertAnimation animationType;
@property (nonatomic, strong) URBAlertViewBlock block;
@property (nonatomic, strong) UIView *blurredBackgroundView;
@property (nonatomic, strong) UIWindow *window;
- (CGRect)defaultFrame;
- (void)animateWithType:(URBAlertAnimation)animation show:(BOOL)show completionBlock:(void(^)())completion;
- (void)showOverlay:(BOOL)show;
- (void)buttonTapped:(id)button;
- (UIView *)blurredBackground;
- (UIImage *)defaultBackgroundImage;
- (void)layoutComponents;
- (void)setTextAttributes:(NSDictionary *)textAttributes forLabel:(UILabel *)label;
- (void)cleanup;
@end

#define kURBAlertBackgroundRadius 10.0
#define kURBAlertFrameInset 7.0
#define kURBAlertPadding 8.0
#define kURBAlertButtonPadding 6.0
#define kURBAlertButtonHeight 44.0
#define kURBAlertButtonOffset 66.5
#define kURBAlertTextFieldHeight 29.0

static CGSize const kURBAlertViewDefaultSize = {280.0, 180.0};

@implementation URBAlertView {
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
		_titleFont = [UIFont boldSystemFontOfSize:18.0];
		_messageFont = [UIFont systemFontOfSize:14.0];
		_buttonFont = [UIFont fontWithName:self.titleFont.fontName size:16.0];
		_backgroundImage = nil;

		self.animationType = URBAlertAnimationDefault;
		self.buttons = [NSMutableArray array];
		self.textFields = [NSMutableArray array];
		
		self.opaque = NO;
		self.alpha = 1.0;
		self.darkenBackground = YES;
		self.blurBackground = NO;
		
		// register for keyboard notifications
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
		
		[self build];
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

- (void)setHandlerBlock:(URBAlertViewBlock)block {
	self.block = block;
}

- (void)setTitleFont:(UIFont *)titleFont {
	if (titleFont != _titleFont) {
		_titleFont = titleFont;
		self.titleLabel.font = titleFont;
	}
}

- (void)setMessageFont:(UIFont *)messageFont {
	if (messageFont != _messageFont) {
		_messageFont = messageFont;
		self.messageLabel.font = messageFont;
	}
}

- (void)setButtonFont:(UIFont *)buttonFont {
	if (buttonFont != _buttonFont) {
		_buttonFont = buttonFont;
		[self.buttons enumerateObjectsUsingBlock:^(URBAlertViewButton *button, NSUInteger idx, BOOL *stop) {
			button.titleLabel.font = buttonFont;
		}];
	}
}

- (void)setTitleTextAttributes:(NSDictionary *)textAttributes {
	[self setTextAttributes:textAttributes forLabel:self.titleLabel];
	self.titleFont = self.titleLabel.font;
}

- (void)setMessageTextAttributes:(NSDictionary *)textAttributes {
	[self setTextAttributes:textAttributes forLabel:self.messageLabel];
	self.messageFont = self.messageLabel.font;
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

#pragma mark - Buttons and Text Fields

- (NSInteger)addButtonWithTitle:(NSString *)title {	
	// convert button over to internal button
	URBAlertViewButton *button = [[URBAlertViewButton alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, kURBAlertButtonHeight)];
	[button setTitle:title forState:UIControlStateNormal];
	[button addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
	button.titleLabel.font = self.buttonFont;
	
	[self.buttons addObject:button];
	
	return [self.buttons indexOfObject:button];
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

#pragma mark - Drawing

- (void)build {
	[super layoutSubviews];
	
	if (!self.contentView) {
		self.contentView = [[UIView alloc] initWithFrame:CGRectZero];
		self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
		[self addSubview:self.contentView];
	}
	
	if (!self.backgroundView) {
		self.backgroundView = [[UIImageView alloc] initWithFrame:self.bounds];
		_backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
		[self insertSubview:self.backgroundView atIndex:0];
	}
	
	if (!self.titleLabel) {
		self.titleLabel = [[UILabel alloc] initWithFrame:self.bounds];
		_titleLabel.backgroundColor = [UIColor clearColor];
		_titleLabel.font = self.titleFont;
		_titleLabel.textAlignment = UITextAlignmentCenter;
		_titleLabel.textColor = [UIColor whiteColor];
		_titleLabel.numberOfLines = 0;
		[self.contentView addSubview:self.titleLabel];
	}
	
	if (!self.messageLabel) {
		self.messageLabel = [[UILabel alloc] initWithFrame:self.bounds];
		_messageLabel.backgroundColor = [UIColor clearColor];
		_messageLabel.font = self.messageFont;
		_messageLabel.textAlignment = UITextAlignmentCenter;
		_messageLabel.textColor = [UIColor whiteColor];
		_messageLabel.numberOfLines = 0;
		[self.contentView addSubview:self.messageLabel];
	}
	
	self.layer.shadowColor = [UIColor blackColor].CGColor;
	self.layer.shadowOpacity = 0.8;
	self.layer.shadowOffset = CGSizeMake(0, 1.0);
	self.layer.shadowRadius = 5.0;
}

- (void)layoutComponents {
	CGFloat layoutFrameInset = kURBAlertFrameInset + kURBAlertPadding;
	CGRect layoutFrame = CGRectInset(self.bounds, layoutFrameInset, layoutFrameInset);
	CGFloat layoutWidth = CGRectGetWidth(layoutFrame);
	
	self.contentView.frame = layoutFrame;
	
	// title frame
	CGFloat titleHeight = 0;
	CGFloat minY = 0;
	if (self.title.length > 0) {
		titleHeight = [self.title sizeWithFont:self.titleFont constrainedToSize:CGSizeMake(layoutWidth, MAXFLOAT) lineBreakMode:NSLineBreakByWordWrapping].height;
		minY += kURBAlertPadding;
	}
	layout.titleRect = CGRectMake(0, minY, layoutWidth, titleHeight);
	self.titleLabel.frame = layout.titleRect;
	self.titleLabel.text = self.title;
	
	// message frame
	CGFloat messageHeight = 0;
	minY = CGRectGetMaxY(layout.titleRect);
	if (self.message.length > 0) {
		messageHeight = [self.message sizeWithFont:self.messageFont constrainedToSize:CGSizeMake(layoutWidth, MAXFLOAT) lineBreakMode:NSLineBreakByWordWrapping].height;
		minY += kURBAlertPadding;
	}
	layout.messageRect = CGRectMake(0, minY, layoutWidth, messageHeight);
	self.messageLabel.frame = layout.messageRect;
	self.messageLabel.text = self.message;
	
	// text fields frame
	CGFloat textFieldsHeight = 0;
	NSUInteger totalFields = self.textFields.count;
	minY = CGRectGetMaxY(layout.messageRect);
	if (totalFields > 0) {
		textFieldsHeight = kURBAlertTextFieldHeight * (CGFloat)totalFields + kURBAlertPadding * (CGFloat)totalFields;
		minY += kURBAlertPadding;
	}
	layout.textFieldsRect = CGRectMake(kURBAlertPadding, minY, layoutWidth - kURBAlertPadding * 2, textFieldsHeight);
	
	// reset main frame based on title and message heights and set background frame and image
	self.frame = CGRectMake(0, 0, CGRectGetWidth(self.bounds), CGRectGetMaxY(layout.textFieldsRect) + kURBAlertPadding + kURBAlertButtonOffset + layoutFrameInset);
	self.backgroundView.frame = self.bounds;
	layout.buttonRegionRect = CGRectMake(0, CGRectGetHeight(self.bounds) - kURBAlertButtonOffset, CGRectGetWidth(self.bounds), kURBAlertButtonOffset);
	
	self.backgroundView.image = (self.backgroundImage) ? self.backgroundImage : [self defaultBackgroundImage];
	
	// buttons frame
	CGFloat buttonsHeight = 0;
	CGFloat buttonRegionPadding = ((kURBAlertButtonOffset - kURBAlertFrameInset) - kURBAlertButtonHeight) / 2.0 - 2.0;
	minY = CGRectGetMinY(layout.buttonRegionRect) + buttonRegionPadding;
	if (self.buttons.count > 0) {
		buttonsHeight = kURBAlertButtonHeight;
		minY += kURBAlertPadding;
	}
	layout.buttonRect = CGRectMake(CGRectGetMinX(layoutFrame), CGRectGetMinY(layout.buttonRegionRect) + buttonRegionPadding, layoutWidth, buttonsHeight);	
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
	NSUInteger count = self.buttons.count;
	if (count > 0) {
		CGFloat buttonWidth = (CGRectGetWidth(layout.buttonRect) - kURBAlertButtonPadding * ((CGFloat)count - 1.0)) / (CGFloat)count;
		for (int i = 0; i < count; i++) {
			CGFloat xOffset = CGRectGetMinX(layout.buttonRect) + (kURBAlertButtonPadding + buttonWidth) * (CGFloat)i;
			CGRect frame = CGRectIntegral(CGRectMake(xOffset, CGRectGetMinY(layout.buttonRect), buttonWidth, CGRectGetHeight(layout.buttonRect)));
			
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
}

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
	} completion:^(BOOL finished) {
		// stub
	}];
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
	if (self.block)
		self.block(buttonIndex, self);
}

- (UIView *)blurredBackground {
	UIView *backgroundView = [[UIApplication sharedApplication] keyWindow];
	UIImageView *blurredView = [[UIImageView alloc] initWithFrame:backgroundView.bounds];
	blurredView.image = [[backgroundView screenshot] boxblurImageWithBlur:0.08];
	
	return blurredView;
}

- (void)animateWithType:(URBAlertAnimation)animation show:(BOOL)show completionBlock:(void (^)())completion {
	// make sure everything is laid out before we try animation, otherwise we get some sketchy things happening
	// especially with the buttons
	if (show) {
		[self setNeedsLayout];
		//[self layoutIfNeeded];
		[self layoutComponents];
	}
	
	// fade animation
	if (animation == URBAlertAnimationFade) {
		if (show) {
			[self showOverlay:YES];
			
			self.transform = CGAffineTransformMakeScale(0.97, 0.97);
			[UIView animateWithDuration:0.15 animations:^{
				self.transform = CGAffineTransformIdentity;
				self.alpha = 1.0f;
			} completion:^(BOOL finished) {
				if (completion)
					completion();
			}];
		}
		else {
			[self showOverlay:NO];
			
			[UIView animateWithDuration:0.15 animations:^{
				self.transform = CGAffineTransformMakeScale(0.97, 0.97);
				self.alpha = 0.0f;
			} completion:^(BOOL finished) {
				[self cleanup];
				if (completion)
					completion();
			}];
		}
	}
	
	// horizontal flip animation
	else if (animation == URBAlertAnimationFlipHorizontal || animation == URBAlertAnimationFlipVertical) {
		
		CGFloat xAxis = (animation == URBAlertAnimationFlipVertical) ? 1.0 : 0.0;
		CGFloat yAxis = (animation == URBAlertAnimationFlipHorizontal) ? 1.0 : 0.0;
		
		if (show) {
			self.layer.zPosition = 100;
			
			CATransform3D perspectiveTransform = CATransform3DIdentity;
			perspectiveTransform.m34 = 1.0 / -500;
			
			// initial starting rotation
			self.layer.transform = CATransform3DConcat(CATransform3DMakeRotation(70.0 * M_PI / 180.0, xAxis, yAxis, 0.0), perspectiveTransform);
			self.alpha = 0.0f;
			
			[self showOverlay:YES];
			
			[UIView animateWithDuration:0.2 animations:^{ // flip remaining + bounce
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
						   if (completion)
							   completion();
					   }];
					}];
				}];
			}];
		}
		else {
			[self showOverlay:NO];
			
			self.layer.zPosition = 100;
			self.alpha = 1.0f;
			
			CATransform3D perspectiveTransform = CATransform3DIdentity;
			perspectiveTransform.m34 = 1.0 / -500;
			
			[UIView animateWithDuration:0.08 animations:^{
				self.layer.transform = CATransform3DConcat(CATransform3DMakeRotation(-10.0 * M_PI / 180.0, xAxis, yAxis, 0.0), perspectiveTransform);
			} completion:^(BOOL finished) {
				[UIView animateWithDuration:0.17 animations:^{
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
			
			CATransform3D rotate = CATransform3DMakeRotation(70.0 * M_PI / 180.0, 0.0, 0.0, 1.0);
			CATransform3D translate = CATransform3DMakeTranslation(20.0, -500.0, 0.0);
			self.layer.transform = CATransform3DConcat(rotate, translate);
			
			[UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationCurveEaseOut animations:^{
				self.layer.transform = CATransform3DIdentity;
			} completion:^(BOOL finished) {
				if (completion)
					completion();
			}];
		}
		else {
			[self showOverlay:NO];
			
			[UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationCurveEaseOut animations:^{
				CATransform3D rotate = CATransform3DMakeRotation(-70.0 * M_PI / 180.0, 0.0, 0.0, 1.0);
				CATransform3D translate = CATransform3DMakeTranslation(-20.0, 500.0, 0.0);
				self.layer.transform = CATransform3DConcat(rotate, translate);
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
			
			CGFloat startX = (animation == URBAlertAnimationSlideLeft) ? 200.0 : -200.0;
			CGFloat shiftX = 5.0;
			if (animation == URBAlertAnimationSlideLeft)
				shiftX *= -1.0;
			
			self.layer.transform = CATransform3DMakeTranslation(startX, 0.0, 0.0);
			[UIView animateWithDuration:0.15 delay:0.0 options:UIViewAnimationCurveEaseOut animations:^{
				self.layer.transform = CATransform3DMakeTranslation(shiftX, 0.0, 0.0);
			} completion:^(BOOL finished) {
				[UIView animateWithDuration:0.1 animations:^{
					self.layer.transform = CATransform3DIdentity;
				} completion:^(BOOL finished) {
					if (completion)
						completion();
				}];
			}];
		}
		else {
			[self showOverlay:NO];
			
			CGFloat finalX = (animation == URBAlertAnimationSlideLeft) ? -400.0 : 400.0;
			CGFloat shiftX = 5.0;
			if (animation == URBAlertAnimationSlideRight)
				shiftX *= 1.0;
			
			[UIView animateWithDuration:0.1 animations:^{
				self.layer.transform = CATransform3DMakeTranslation(shiftX, 0.0, 0.0);
			} completion:^(BOOL finished) {
				[UIView animateWithDuration:0.15 delay:0.0 options:UIViewAnimationCurveEaseIn animations:^{
					self.layer.transform = CATransform3DMakeTranslation(finalX, 0.0, 0.0);
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
			[UIView animateWithDuration:0.17 animations:^{
				self.layer.transform = CATransform3DMakeScale(1.1, 1.1, 1.0);
				self.alpha = 1.0f;
			} completion:^(BOOL finished) {
				[UIView animateWithDuration:0.12 animations:^{
					self.layer.transform = CATransform3DMakeScale(0.9, 0.9, 1.0);
				} completion:^(BOOL finished) {
					[UIView animateWithDuration:0.1 animations:^{
						self.layer.transform = CATransform3DIdentity;
					} completion:^(BOOL finished) {
						if (completion)
							completion();
					}];
				}];
			}];
		}
		else {
			[self showOverlay:NO];
			
			[UIView animateWithDuration:0.1 animations:^{
				self.layer.transform = CATransform3DMakeScale(1.1, 1.1, 1.0);
			} completion:^(BOOL finished) {
				[UIView animateWithDuration:0.15 animations:^{
					self.layer.transform = CATransform3DIdentity;
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
		
		// blurred background
		if (self.blurBackground) {
			self.blurredBackgroundView = [self blurredBackground];
			self.blurredBackgroundView.alpha = 0.0f;
			[self.window addSubview:self.blurredBackgroundView];
		}
		
		[self.window addSubview:self.overlay];
		[self.window addSubview:self];
		
		// window has to be un-hidden on the main thread
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.window makeKeyAndVisible];
			
			// fade in overlay
			[UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionLayoutSubviews animations:^{
				self.blurredBackgroundView.alpha = 1.0f;
				self.overlay.alpha = 1.0f;
			} completion:^(BOOL finished) {
				// stub
			}];
		});
	}
	else {
		[UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionLayoutSubviews animations:^{
			self.overlay.alpha = 0.0f;
			self.blurredBackground.alpha = 0.0f;
		} completion:^(BOOL finished) {
			self.blurredBackgroundView = nil;
		}];
	}
}

- (void)cleanup {
	self.layer.transform = CATransform3DIdentity;
	self.transform = CGAffineTransformIdentity;
	self.alpha = 1.0f;
	self.window = nil;
	// rekey main AppDelegate window
	[[[[UIApplication sharedApplication] delegate] window] makeKeyWindow];
}

#pragma mark - UITextFieldDelegate

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
	UIColor *gradientInner = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 0.25];
	
	// gradients
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
	
	// cleanup
	CGGradientRelease(radialGradient);
	CGColorSpaceRelease(colorSpace);
}

@end


#pragma mark - URBAlertViewButton

@implementation URBAlertViewButton

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		static UIImage *normalButtonImage;
		static dispatch_once_t once;
		dispatch_once(&once, ^{
			normalButtonImage = [self normalButtonImage];
		});
		[self setBackgroundImage:normalButtonImage forState:UIControlStateNormal];
	}
	return self;
}

- (UIImage *)normalButtonImage {
	UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, 0);
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	// colors
	UIColor *buttonBgGradientColorTop = [UIColor colorWithRed: 0.146 green: 0.146 blue: 0.146 alpha: 1];
	UIColor *buttonBgGradientColorBottom = [UIColor colorWithRed: 0.069 green: 0.069 blue: 0.069 alpha: 1];
	UIColor *buttonOuterGradientColor = [UIColor colorWithRed: 0.259 green: 0.259 blue: 0.259 alpha: 1];
	UIColor *buttonOuterGradientColor2 = [UIColor colorWithRed: 0.172 green: 0.172 blue: 0.172 alpha: 1];
	UIColor *buttonInnerGradientColor = [UIColor colorWithRed: 0.326 green: 0.326 blue: 0.326 alpha: 1];
	UIColor *buttonInnerGradientColor2 = [UIColor colorWithRed: 0.26 green: 0.26 blue: 0.26 alpha: 1];
	
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
	
	// cleanup
	CGGradientRelease(buttonBgGradient);
	CGGradientRelease(buttonOuterGradient);
	CGGradientRelease(buttonInnerGradient);
	CGColorSpaceRelease(colorSpace);
	
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
	
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(0.0, 6.0, 0.0, 6.0)];
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
	// General Declarations
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSaveGState(context);
	
	// Color Declarations
	UIColor *white10 = [UIColor colorWithWhite:1.0 alpha:0.1];
	UIColor *grey40 = [UIColor colorWithWhite:0.4 alpha:1.0];
	
	// Shadow Declarations
	CGColorRef innerShadow = grey40.CGColor;
	CGSize innerShadowOffset = CGSizeMake(0, 2);
	CGFloat innerShadowBlurRadius = 2;
	CGColorRef outerShadow = white10.CGColor;
	CGSize outerShadowOffset = CGSizeMake(0, 1);
	CGFloat outerShadowBlurRadius = 0;
	
	// Rectangle Drawing
	UIBezierPath *rectanglePath = [UIBezierPath bezierPathWithRect: CGRectIntegral(rect)];
	CGContextSaveGState(context);
	CGContextSetShadowWithColor(context, outerShadowOffset, outerShadowBlurRadius, outerShadow);
	[[UIColor whiteColor] setFill];
	[rectanglePath fill];
	
	// Rectangle Inner Shadow
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
    
    if(pixelBuffer == NULL)
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