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
    self.activityIndicator = [[DGActivityIndicatorView alloc] initWithType:DGActivityIndicatorAnimationTypeBallScaleMultiple];
    //self.activityIndicator.frame = self.frame;
    self.activityIndicator.center = self.center;
    self.activityIndicator.tintColor = UIColorFromRGB(0x2398B5);
    [self addSubview:self.activityIndicator];
    [self.activityIndicator startAnimating];
}

@end
