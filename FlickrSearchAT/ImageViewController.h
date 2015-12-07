//
//  ImageViewController.h
//  FlickrSearchAT
//
//  Created by Suhail Bhat on 07/12/15.
//  Copyright © 2015 SRB. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <FSImageViewer/FSImageViewerViewController.h>

@interface ImageViewController : FSImageViewerViewController

@property (nonatomic, strong) NSURL *photoURL;
@property (strong, nonatomic) IBOutlet UIImageView *imageView;


@end
