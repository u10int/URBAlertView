URBAlertView
============

## Overview

`URBAlertView` is a block-based alternative to the default `UIAlertView` available in UIKit that offers easier customization and a wider range of presentation and dismissal animations (fade, zoom, slide, flip, tumble).

![Basic two-button layout example](http://dl.dropbox.com/u/197980/Screenshots/URBAlertView_screenshot01.png)

## Installation

To use `URBAlertView` in your own project, just import `URBAlertView.h` and `URBAlertView.m` files into your project, and then include "`URBAlertView.h`" where needed, or in your precompiled header.

The project uses ARC and targets iOS 5.0+.

## Usage Examples

The process of displaying an alert is very similar to that of UIKit's `UIAlertView`, except that you can use block for handling button events instead of the cumbersome delegate method. Just create an instance of `URBAlertView`, add some buttons and show (or show with a specific presentation style):

	URBAlertView *alertView = [URBAlertView alloc] initWithTitle:@"Test Dialog" subtitle:@"This is just a test dialog"];
	[alertView addButtonWithTitle:@"Close"];
	[alertView addButtonWithTitle:@"OK"];
	[alertView setHandlerBlock:^(NSInteger buttonIndex, URBAlertView *alertView) {
		[self.alertView hideWithCompletionBlock:^{
			NSLog(@"Alert view closed.");
		}];
	}];
	[self.alertView showWithAnimation:URBAlertAnimationFlipHorizontal];

By default, the dismissal animation will be in the same style as the presentation animation, unless you specifically use a different animation style when hiding:

	[alertView hideWithAnimation:URBAlertAnimationTumble];

## TODO

- Update to better resemple the init methods found in `UIAlertView`.
- Support for defining event handling blocks for each button instead of a single block for all buttons.
- `UIAppearance` conformance to allow for easier skinning and styling.
- Support for setting the `UIImage` instances to use for backgrounds and buttons without having to edit the core classes.
- Support for dynamically swapping out the content view without having to display another alert view.

## License

This code is distributed under the terms and conditions of the MIT license.