//
//  URBViewController.m
//  URBFlipModalViewControllerDemo
//
//  Created by Nicholas Shipes on 12/20/12.
//  Copyright (c) 2012 Urban10 Interactive. All rights reserved.
//

#import "ViewController.h"
#import "URBAlertView.h"

@interface ViewController ()
@property (nonatomic, strong) URBAlertView *alertView;
@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	
	NSValue *shadowOffset = [NSValue valueWithUIOffset:UIOffsetMake(0.0, 1.0)];
	NSDictionary *titleTextAttributes = @{UITextAttributeFont:[UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:18.0f], UITextAttributeTextColor:[UIColor colorWithWhite:0.1 alpha:1.0],
									   UITextAttributeTextShadowColor:[UIColor whiteColor], UITextAttributeTextShadowOffset:shadowOffset};
	NSDictionary *messageTextAttributes = @{UITextAttributeFont:[UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:14.0f], UITextAttributeTextColor:[UIColor colorWithWhite:0.3 alpha:1.0],
										 UITextAttributeTextShadowColor:[UIColor whiteColor], UITextAttributeTextShadowOffset:shadowOffset};
	NSDictionary *buttonTextAttributes = @{UITextAttributeFont:[UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:18.0f], UITextAttributeTextColor:[UIColor colorWithWhite:0.1 alpha:1.0],
										 UITextAttributeTextShadowColor:[UIColor whiteColor], UITextAttributeTextShadowOffset:shadowOffset};
	NSDictionary *cancelButtonTextAttributes = @{UITextAttributeFont:[UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:18.0f], UITextAttributeTextColor:[UIColor colorWithWhite:0.5 alpha:1.0],
										UITextAttributeTextShadowColor:[UIColor whiteColor], UITextAttributeTextShadowOffset:shadowOffset};
	[[URBAlertView appearance] setBackgroundColor:[UIColor colorWithWhite:0.9 alpha:1.0]];
	[[URBAlertView appearance] setBackgroundGradation:0.05];
	[[URBAlertView appearance] setStrokeColor:[UIColor colorWithWhite:0.35 alpha:1.0]];
	[[URBAlertView appearance] setStrokeWidth:3.0];
	[[URBAlertView appearance] setTitleTextAttributes:titleTextAttributes];
	[[URBAlertView appearance] setMessageTextAttributes:messageTextAttributes];
	[[URBAlertView appearance] setButtonBackgroundColor:[UIColor colorWithWhite:0.8 alpha:1.0]];
	[[URBAlertView appearance] setButtonStrokeColor:[UIColor colorWithWhite:0.65 alpha:1.0]];
	[[URBAlertView appearance] setButtonTextAttributes:buttonTextAttributes forState:UIControlStateNormal];
	[[URBAlertView appearance] setCancelButtonTextAttributes:cancelButtonTextAttributes forState:UIControlStateNormal];
	
	self.view.backgroundColor = [UIColor whiteColor];
	
	CGFloat buttonPad = 10.0f;
	CGFloat buttonWidth = self.view.bounds.size.width - buttonPad * 2;
	CGFloat buttonYOffset = (self.view.bounds.size.height - buttonPad * 7 - 44.0 * 8) / 2.0;
	CGRect buttonFrame = CGRectMake(buttonPad, 0, buttonWidth, 44.0);
	
	UIButton *defaultButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	defaultButton.frame = CGRectMake(CGRectGetMinX(buttonFrame), buttonYOffset, CGRectGetWidth(buttonFrame), CGRectGetHeight(buttonFrame));
	[defaultButton setTitle:@"Default" forState:UIControlStateNormal];
	[defaultButton addTarget:self action:@selector(showDialog) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:defaultButton];
	buttonYOffset += CGRectGetHeight(defaultButton.frame) + buttonPad;
	
	UIButton *fadeButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	fadeButton.frame = CGRectMake(CGRectGetMinX(buttonFrame), buttonYOffset, CGRectGetWidth(buttonFrame), CGRectGetHeight(buttonFrame));
	[fadeButton setTitle:@"Fade" forState:UIControlStateNormal];
	[fadeButton addTarget:self action:@selector(showDialogWithFade) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:fadeButton];
	buttonYOffset += CGRectGetHeight(fadeButton.frame) + buttonPad;
	
	UIButton *flipHorizButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	flipHorizButton.frame = CGRectMake(CGRectGetMinX(buttonFrame), buttonYOffset, CGRectGetWidth(buttonFrame), CGRectGetHeight(buttonFrame));
	[flipHorizButton setTitle:@"Flip Horizontal" forState:UIControlStateNormal];
	[flipHorizButton addTarget:self action:@selector(showDialogWithFlipHorizontal) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:flipHorizButton];
	buttonYOffset += CGRectGetHeight(flipHorizButton.frame) + buttonPad;
	
	UIButton *flipVertButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	flipVertButton.frame = CGRectMake(CGRectGetMinX(buttonFrame), buttonYOffset, CGRectGetWidth(buttonFrame), CGRectGetHeight(buttonFrame));
	[flipVertButton setTitle:@"Flip Vertical" forState:UIControlStateNormal];
	[flipVertButton addTarget:self action:@selector(showDialogWithFlipVertical) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:flipVertButton];
	buttonYOffset += CGRectGetHeight(flipVertButton.frame) + buttonPad;
	
	UIButton *tumbleButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	tumbleButton.frame = CGRectMake(CGRectGetMinX(buttonFrame), buttonYOffset, CGRectGetWidth(buttonFrame), CGRectGetHeight(buttonFrame));
	[tumbleButton setTitle:@"Tumble" forState:UIControlStateNormal];
	[tumbleButton addTarget:self action:@selector(showDialogWithTumble) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:tumbleButton];
	buttonYOffset += CGRectGetHeight(tumbleButton.frame) + buttonPad;
	
	UIButton *slideButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	slideButton.frame = CGRectMake(CGRectGetMinX(buttonFrame), buttonYOffset, CGRectGetWidth(buttonFrame), CGRectGetHeight(buttonFrame));
	[slideButton setTitle:@"Slide Left" forState:UIControlStateNormal];
	[slideButton addTarget:self action:@selector(showDialogWithSlide) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:slideButton];
	buttonYOffset += CGRectGetHeight(slideButton.frame) + buttonPad;
	
	UIButton *textFieldButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	textFieldButton.frame = CGRectMake(CGRectGetMinX(buttonFrame), buttonYOffset, CGRectGetWidth(buttonFrame), CGRectGetHeight(buttonFrame));
	[textFieldButton setTitle:@"Default with Text Field" forState:UIControlStateNormal];
	[textFieldButton addTarget:self action:@selector(showDialogWithTextField) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:textFieldButton];
	buttonYOffset += CGRectGetHeight(textFieldButton.frame) + buttonPad;
	
	UIButton *multipleButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	multipleButton.frame = CGRectMake(CGRectGetMinX(buttonFrame), buttonYOffset, CGRectGetWidth(buttonFrame), CGRectGetHeight(buttonFrame));
	[multipleButton setTitle:@"Default with Multiple Buttons" forState:UIControlStateNormal];
	[multipleButton addTarget:self action:@selector(showDialogWithMultipleButtons) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:multipleButton];
	buttonYOffset += CGRectGetHeight(multipleButton.frame) + buttonPad;
}

- (void)viewDidAppear:(BOOL)animated {
	
	URBAlertView *alertView = [[URBAlertView alloc] initWithTitle:@"Test Alert"
														  message:@"This is just a test dialog. Say something important here."
												cancelButtonTitle:@"Cancel"
												otherButtonTitles: @"OK", nil];
//	[alertView addButtonWithTitle:@"Close"];
//	[alertView addButtonWithTitle:@"OK"];
	[alertView setHandlerBlock:^(NSInteger buttonIndex, URBAlertView *alertView) {
		NSLog(@"button tapped: index=%i", buttonIndex);
		[self.alertView hideWithCompletionBlock:^{
			// stub
		}];
	}];
	
	self.alertView = alertView;	
}

- (void)showDialog {
	[self.alertView showWithAnimation:URBAlertAnimationDefault];
}

- (void)showDialogWithFade {
	[self.alertView showWithAnimation:URBAlertAnimationFade];
}

- (void)showDialogWithFlipHorizontal {
	[self.alertView showWithAnimation:URBAlertAnimationFlipHorizontal];
}

- (void)showDialogWithFlipVertical {
	[self.alertView showWithAnimation:URBAlertAnimationFlipVertical];
}

- (void)showDialogWithTumble {
	[self.alertView showWithAnimation:URBAlertAnimationTumble];
}

- (void)showDialogWithSlide {
	[self.alertView showWithAnimation:URBAlertAnimationSlideLeft];
}

- (void)showDialogWithTextField {
	URBAlertView *textAlertView = [URBAlertView dialogWithTitle:@"Test Alert" message:@"This is just a test dialog with a text field for the user to enter some data into."];
	[textAlertView addButtonWithTitle:@"Close"];
	[textAlertView addButtonWithTitle:@"OK"];
	[textAlertView addTextFieldWithPlaceholder:@"Testing" secure:NO];
	[textAlertView setHandlerBlock:^(NSInteger buttonIndex, URBAlertView *alertView) {
		NSLog(@"button tapped: index=%i, text=%@", buttonIndex, [alertView textForTextFieldAtIndex:0]);
		[alertView hideWithCompletionBlock:^{
			// stub
		}];
	}];
	[textAlertView showWithAnimation:URBAlertAnimationDefault];
}

- (void)showDialogWithMultipleButtons {
	URBAlertView *multiAlertView = [[URBAlertView alloc] initWithTitle:@"Select Option" message:@"Select the option you wish to proceed with." cancelButtonTitle:@"Cancel" otherButtonTitles:@"Option 1", @"Option 2", @"Option 3", nil];
	[multiAlertView setHandlerBlock:^(NSInteger buttonIndex, URBAlertView *alertView) {
		NSLog(@"button tapped: index=%i", buttonIndex);
		[alertView hide];
	}];
	[multiAlertView show];
}

@end
