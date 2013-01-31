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
	
	self.view.backgroundColor = [UIColor whiteColor];
	
	CGFloat buttonPad = 10.0f;
	CGFloat buttonWidth = self.view.bounds.size.width - buttonPad * 2;
	CGFloat buttonYOffset = (self.view.bounds.size.height - buttonPad * 6 - 44.0 * 6) / 2.0;
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
}

- (void)viewDidAppear:(BOOL)animated {
	
	URBAlertView *alertView = [URBAlertView dialogWithTitle:@"Test Dialog" subtitle:@"This is just a test dialog"];
	alertView.blurBackground = NO;
	[alertView addButtonWithTitle:@"Close"];
	[alertView addButtonWithTitle:@"OK"];
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

@end
