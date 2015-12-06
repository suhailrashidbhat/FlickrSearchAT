//
//  FlickrManager.h
//  FlickrSearchAT
//
//  Created by Suhail Bhat on 06/12/15.
//  Copyright © 2015 SRB. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FlickrManager : NSObject

typedef void(^dataFetchCompletionBlock)(NSMutableArray*, NSError*);

@property (nonatomic, strong) NSMutableArray *photos; // NSURLs

@property (nonatomic, assign) NSUInteger lastFetchedPageIndex;

+ (id)sharedManager;
- (void)fetchDataForText:(NSString*)searchString completionBlock:(dataFetchCompletionBlock)completion;
- (void)fetchNextPageDataForText:(NSString *)searchString completionBlock:(dataFetchCompletionBlock)completion;

@end
