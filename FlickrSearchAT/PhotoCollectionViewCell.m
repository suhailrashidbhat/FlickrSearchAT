//
//  PhotoCollectionViewCell.m
//  FlickrSearchAT
//
//  Created by Suhail Bhat on 06/12/15.
//  Copyright © 2015 SRB. All rights reserved.
//

#import "PhotoCollectionViewCell.h"

@implementation PhotoCollectionViewCell

-(void)awakeFromNib {
    self.activityIndicator = [[DGActivityIndicatorView alloc] initWithType:DGActivityIndicatorAnimationTypeBallBeat];
    self.activityIndicator.frame = self.frame;
    self.activityIndicator.center = self.center;
    self.imageView.userInteractionEnabled = YES;
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.imageView.autoresizingMask = (UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth);
    self.activityIndicator.tintColor = UIColorFromRGB(0xF398B5);
    //[self addSubview:self.activityIndicator];  // no need of it for now! 
    [self.activityIndicator startAnimating];
}

@end
