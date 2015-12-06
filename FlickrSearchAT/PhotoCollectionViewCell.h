//
//  PhotoCollectionViewCell.h
//  FlickrSearchAT
//
//  Created by Suhail Bhat on 06/12/15.
//  Copyright © 2015 SRB. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <DGActivityIndicatorView.h>

@interface PhotoCollectionViewCell : UICollectionViewCell

@property (strong, nonatomic) IBOutlet UIImageView *imageView;

@property (strong, nonatomic) IBOutlet DGActivityIndicatorView *activityIndicator;

@end
