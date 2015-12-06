//
//  FlickrManager.m
//  FlickrSearchAT
//
//  Created by Suhail Bhat on 06/12/15.
//  Copyright © 2015 SRB. All rights reserved.
//

#import "FlickrManager.h"


static NSString *const kFlickrAPIKey = @"ffce5722188b15182473626a96decc2c";
static NSString *const kFlickrSearchURL = @"https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=%@&format=json&nojsoncallback=1&text=%@&page=%lu&per_page=51";

@implementation FlickrManager

+ (id)sharedManager {
    static FlickrManager *sharedMyManager = nil;
    @synchronized(self) {
        if (sharedMyManager == nil) {
            sharedMyManager = [[self alloc] init];
        }
    }
    return sharedMyManager;
}

-(instancetype)init {
    if (self = [super init]) {
        self.photos = [NSMutableArray array];
    }
    return self;
}

- (void)fetchDataForText:(NSString *)searchString completionBlock:(dataFetchCompletionBlock)completion {
    self.lastFetchedPageIndex = 1;
    NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:kFlickrSearchURL, kFlickrAPIKey, searchString, self.lastFetchedPageIndex]];
    NSLog(requestURL.description);
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:requestURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleResponse:response data:data error:error completion:completion];
        });
    }];
    [task resume];
}

- (void)fetchNextPageDataForText:(NSString *)searchString completionBlock:(dataFetchCompletionBlock)completion {

    NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:kFlickrSearchURL, kFlickrAPIKey, searchString, (unsigned long)++self.lastFetchedPageIndex]];
    NSLog(requestURL.description);
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:requestURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleResponse:response data:data error:error completion:completion];
        });
    }];
    [task resume];
}

- (void)handleResponse:(NSURLResponse*)response data:(NSData*)data error:(NSError*)error completion:(dataFetchCompletionBlock)completion {

    if (error) {
        completion(nil, error);
        return;
    }

    NSError *jsonError;
    NSDictionary *responseDict = (NSDictionary*) [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if(jsonError) {
        completion(nil, jsonError);
        return;
    }

    NSArray *photoEntities = [responseDict valueForKeyPath:@"photos.photo"];
    self.lastFetchedPageIndex = [[responseDict valueForKeyPath:@"photos.page"] unsignedIntegerValue];

    NSString *stat = [responseDict valueForKeyPath:@"stat"];
    if (![stat isEqualToString:@"ok"]) {
        completion(nil, nil);
    }
    if (photoEntities.count >0) {
        [self createPhotoURLs:photoEntities];
        completion(self.photos, nil);
    }
}

-(void)createPhotoURLs:(NSArray*)photos {
    for(NSDictionary *dic in photos) {
        // Create photo urls.
        NSString *urlS = [NSString stringWithFormat:@"http://farm%@.static.flickr.com/%@/%@_%@.jpg", [dic valueForKeyPath:@"farm"], [dic valueForKeyPath:@"server"], [dic valueForKeyPath:@"id"], [dic valueForKeyPath:@"secret"]];
        NSURL *url = [NSURL URLWithString:urlS];
        [self.photos addObject:url];
    }
}

@end
