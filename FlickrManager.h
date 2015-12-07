//
//  FlickrManager.h
//  FlickrSearchAT
//
//  Created by Suhail Bhat on 06/12/15.
//  Copyright © 2015 SRB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SDWebImage/SDWebImageDownloader.h>
#import <SDWebImage/SDWebImageDownloaderOperation.h>

@interface FlickrManager : NSObject

typedef void(^dataFetchCompletionBlock)(NSMutableArray*, NSError*);

@property (nonatomic, strong) NSMutableArray *photos; // NSURLs

@property (nonatomic, assign) NSUInteger lastFetchedPageIndex;
@property (nonatomic, strong) NSMutableArray *imageFailedBacklog;
@property (nonatomic, strong) SDWebImageDownloader *imageDownloader;
@property (nonatomic, strong) NSString *lastSearchQuery;
@property (nonatomic, assign) BOOL dataNeedsRefresh;

+ (id)sharedManager;
- (void)fetchDataForText:(NSString*)searchString completionBlock:(dataFetchCompletionBlock)completion;
- (void)fetchNextPageDataForText:(NSString *)searchString completionBlock:(dataFetchCompletionBlock)completion;

@end
