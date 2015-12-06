//
//  ImageViewController.m
//  FlickrSearchAT
//
//  Created by Suhail Bhat on 07/12/15.
//  Copyright © 2015 SRB. All rights reserved.
//

#import "ImageViewController.h"
#import <SDWebImage/UIImageView+WebCache.h>

@interface ImageViewController ()

@end

@implementation ImageViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.imageView sd_setImageWithURL:self.photoURL];
    [self.navigationController.navigationBar setFrame:CGRectMake(0, 20, [[UIScreen mainScreen] bounds].size.width, 44)];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
