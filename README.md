URBAlertView
============

## Overview

`URBAlertView` is a block-based alternative to the default `UIAlertView` available in UIKit that offers easier customization and a wider range of presentation and dismissal animations (fade, zoom, slide, flip, tumble).

![Basic two-button layout example](http://dl.dropbox.com/u/197980/Screenshots/URBAlertView_screenshot01.png)
![Basic two-button layout example with text field](http://dl.dropbox.com/u/197980/Screenshots/URBAlertView_screenshot02.png)

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

## Customization

Many customization options are available for styles, such as colors, fonts radii and line widths, using the public properties on each instance. Alternatively, you can also use the available `UIAppearance` methods for applying these settings globally within your project. For customizating the buttons within `URBAlertView`, some styles can only be set using their respective `UIAppearance` methods, but I'm hoping to improve this in future updates.

Since the view is drawn completely in code, you can also have complete control over the look of your `URBAlertView` instances by modifying the code within `drawRect:` for both `URBAlertView` and `URBAlertViewButton`, both of which are found within the `URBAlertView.m` implementation.

## TODO

- Update to better resemble the init methods found in `UIAlertView`. (added 07/02/2013)
- Support for defining event handling blocks for each button instead of a single block for all buttons.
- `UIAppearance` conformance to allow for easier skinning and styling. (added 07/02/2013)
- More customization properties for buttons.

## License

This code is distributed under the terms and conditions of the MIT license.