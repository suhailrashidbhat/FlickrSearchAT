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
@property (nonatomic, strong) NSString *lastSearchQuery;
@property (nonatomic, assign) BOOL dataNeedsRefresh;
@property (nonatomic, strong) NSMutableArray *imageFailedBacklog;

+ (id)sharedManager;
- (void)fetchDataForText:(NSString*)searchString completionBlock:(dataFetchCompletionBlock)completion;
- (void)fetchNextPageDataForText:(NSString *)searchString completionBlock:(dataFetchCompletionBlock)completion;

@end
