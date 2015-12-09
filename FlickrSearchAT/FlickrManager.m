//
//  FlickrManager.m
//  FlickrSearchAT
//
//  Created by Suhail Bhat on 06/12/15.
//  Copyright © 2015 SRB. All rights reserved.
//

#import "FlickrManager.h"
#import "PhotoEntity.h"

static NSString *const kFlickrAPIKey = @"ffce5722188b15182473626a96decc2c";
static NSString *const kFlickrSearchURL = @"https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=%@&format=json&nojsoncallback=1&text=%@&page=%lu&per_page=51";


@interface FlickrManager()
@property (nonatomic, assign) NSUInteger totalPagesForQuery;
@property (nonatomic, assign) NSUInteger lastFetchedPageIndex;
@property (nonatomic, strong) SDWebImageDownloader *imageDownloader;
@end


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
        self.photoEntities = [NSMutableArray array];
        self.imageDownloader = [SDWebImageDownloader sharedDownloader];
        self.imageFailedBacklog = [NSMutableArray array];
        self.lastSearchQuery = @"love";
        self.dataNeedsRefresh = NO;
    }
    return self;
}

- (void)fetchDataForText:(NSString *)searchString completionBlock:(dataFetchCompletionBlock)completion {
    self.lastFetchedPageIndex = 1;
    self.totalPagesForQuery = 0;
    self.lastSearchQuery = searchString;
    searchString = [searchString urlencode];
    NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:kFlickrSearchURL, kFlickrAPIKey, searchString, (unsigned long)self.lastFetchedPageIndex]];
    NSLog(@"%@",requestURL.description);
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:requestURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleResponse:response data:data error:error completion:completion];
        });
    }];
    [task resume];
}

- (void)fetchNextPageDataForText:(NSString *)searchString completionBlock:(dataFetchCompletionBlock)completion {

    if (self.lastFetchedPageIndex >= self.totalPagesForQuery) {
        NSError *error = [NSError errorWithDomain:@"com.srb.resultend" code:003 userInfo:@{}];
        completion(nil, error);
        return;
    }

    searchString = [searchString urlencode];
    NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:kFlickrSearchURL, kFlickrAPIKey, searchString, (unsigned long)++self.lastFetchedPageIndex]];
    NSLog(@"%@",requestURL.description);
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:requestURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleResponse:response data:data error:error completion:completion];
        });
    }];
    [task resume];
}

- (void)handleResponse:(NSURLResponse*)response data:(NSData*)data error:(NSError*)error completion:(dataFetchCompletionBlock)completion {

    // Handle Error
    if (error) {
        completion(nil, error);
        return;
    }

    // Handle JSON Error
    NSError *jsonError;
    NSDictionary *responseDict = (NSDictionary*) [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if(jsonError) {
        completion(nil, jsonError);
        return;
    }

    NSLog(@"%@", responseDict);
    NSArray *photoEntities = [responseDict valueForKeyPath:@"photos.photo"];
    self.totalPagesForQuery = [[responseDict valueForKeyPath:@"photos.pages"] unsignedIntegerValue];
    self.lastFetchedPageIndex = [[responseDict valueForKeyPath:@"photos.page"] unsignedIntegerValue];


    // If Zero Count
    NSString *stat = [responseDict valueForKeyPath:@"stat"];
    if (![stat isEqualToString:@"ok"] && photoEntities.count > 0) {
        NSError *statError = [NSError errorWithDomain:@"Server Error!" code:002 userInfo:@{@"message":@"Stat is not OK!"}];
        completion(nil, statError);
    }
    if (photoEntities.count >0) {
        [self createPhotoEntities:photoEntities];
        completion(self.photos, nil);

        /*for (int i = 0; i<photoEntities.count; i++) {
            [self.imageDownloader downloadImageWithURL:self.photos[i] options:SDWebImageDownloaderHighPriority progress:nil completed:^(UIImage *image, NSData *data, NSError *error, BOOL finished) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (i == photoEntities.count/2) {
                        completion(self.photos, nil);
                    }
                });
            }];
        }*/
    } else {
        NSError *noDataError = [NSError errorWithDomain:@"No Results Found!" code:001 userInfo:@{@"message":@"No Photos for your query. :( "}];
        completion(nil, noDataError);
    }
}

-(void)createPhotoEntities:(NSArray*)photos {
    // Create photo Entities and URLs array.
    for(NSDictionary *dic in photos) {
        PhotoEntity *entity = [[PhotoEntity alloc] initWithDictionary:dic];
        [self.photos addObject:[entity getPhotoURL]];
        [self.photoEntities addObject:entity];
    }
}

@end
