//
//  CollectionViewController.m
//  FlickrSearchAT
//
//  Created by Suhail Bhat on 06/12/15.
//  Copyright © 2015 SRB. All rights reserved.
//

#import "CollectionViewController.h"
#import "PhotoCollectionViewCell.h"
#import "FlickrManager.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import <SDWebImage/SDWebImageManager.h>
#import <UIActivityIndicator-for-SDWebImage/UIImageView+UIActivityIndicatorForSDWebImage.h>
#import <DGActivityIndicatorView/DGActivityIndicatorView.h>

static NSString* const kCellIdentifier = @"PhotoCell";
static NSString *const kAPIEndpointURL = @"https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=3e7cc266ae2b0e0d78e279ce8e361736&format=json&nojsoncallback=1&text=kittens";

@interface CollectionViewController ()<UISearchBarDelegate>

@property (nonatomic,strong) NSMutableArray        *photos; // URLs
@property (nonatomic)        BOOL           searchBarActive;
@property (nonatomic)        float          searchBarBoundsY;
@property (nonatomic,strong) UISearchBar        *searchBar;
@property (nonatomic, assign) NSUInteger lastPageIndex;
@property (nonatomic, strong) SDWebImageManager *imageDownloader;

@property NSCache *cache;

@end

@implementation CollectionViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.cache = [[NSCache alloc] init];
    self.photos = [NSMutableArray array];
    self.imageDownloader = [SDWebImageManager sharedManager];
    [[FlickrManager sharedManager] fetchDataForText:@"love" completionBlock:^(NSMutableArray *photoURLs, NSError *error) {
        if (error) {
            [self showRetryAlertWithError:error];
        } else {
            self.photos = photoURLs;
            [self.collectionView reloadData];
        }
    }];
    self.navigationController.navigationBarHidden = NO;
    self.view.backgroundColor = [UIColor whiteColor];
    self.collectionView.backgroundColor = [UIColor whiteColor];
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self addSearchBar];
}

-(void)dealloc{
    // remove Our KVO observer
    [self removeObservers];
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

#pragma mark <UICollectionViewDataSource>

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.photos.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    self.searchBarActive = NO;
    [self.view endEditing:YES];
    PhotoCollectionViewCell *cell = (PhotoCollectionViewCell*)[collectionView dequeueReusableCellWithReuseIdentifier:kCellIdentifier forIndexPath:indexPath];
    [cell.activityIndicator startAnimating];
    NSURL *photoURL = self.photos[indexPath.item];
    
    [cell.imageView sd_setImageWithURL:photoURL completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
        [cell.activityIndicator stopAnimating];
    }];
    cell.imageView.backgroundColor = [UIColor blackColor];
    return cell;
}

#pragma mark -  <UICollectionViewDelegateFlowLayout>
- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView
                        layout:(UICollectionViewLayout*)collectionViewLayout
        insetForSectionAtIndex:(NSInteger)section{
    return UIEdgeInsetsMake(self.searchBar.frame.size.height, 5, 5, 5);
}
- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout*)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath{
    CGFloat cellLeg = (self.collectionView.frame.size.width/3) - 5;
    return CGSizeMake(cellLeg,cellLeg);;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 2.0;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 2.0;
}


#pragma mark - Private

- (void)fetchData:(void(^)(void))completion {
    NSURL *requestURL = [NSURL URLWithString:kAPIEndpointURL];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:requestURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleResponse:response data:data error:error completion:completion];
        });
    }];

    // I run -[task resume] with delay because my network is too fast
    NSTimeInterval delay = (self.photos.count == 0 ? 0 : 5);

    [task performSelector:@selector(resume) withObject:nil afterDelay:delay];
}

- (void)handleResponse:(NSURLResponse*)response data:(NSData*)data error:(NSError*)error completion:(void(^)(void))completion {
    void(^finish)(void) = completion ?: ^{};

    if(error) {
        [self showRetryAlertWithError:error];
        finish();
        return;
    }

    NSError *jsonError;
    NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    // Fix broken Flickr JSON
    jsonString = [jsonString stringByReplacingOccurrencesOfString: @"\\'" withString: @"'"];
    NSData *fixedData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];

    NSDictionary *responseDict = (NSDictionary*) [NSJSONSerialization JSONObjectWithData:fixedData options:0 error:&jsonError];

    if(jsonError) {
        [self showRetryAlertWithError:jsonError];
        finish();
        return;
    }

    NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
    NSArray *photoEntities = [responseDict valueForKeyPath:@"photos.photo"];

    self.lastPageIndex = [[responseDict valueForKeyPath:@"photos.page"] unsignedIntegerValue];

    NSString *stat = [responseDict valueForKeyPath:@"stat"];
    if (![stat isEqualToString:@"ok"]) {
        [self showRetryAlertWithError:nil];
        return;
    }

    NSInteger index = self.photos.count;

    for(NSDictionary *dic in photoEntities) {

        // Create photo urls.

        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index++ inSection:0];

        //[self.photos addObject:[NSURL URLWithString:url]];
        [indexPaths addObject:indexPath];
    }

    //    self.modifiedAt = modifiedAt;

    [self.collectionView performBatchUpdates:^{
        [self.collectionView insertItemsAtIndexPaths:indexPaths];
    } completion:^(BOOL finished) {
        finish();
    }];
}


#pragma mark - prepareVC

-(void)addSearchBar{
    if (!self.searchBar) {
        self.searchBarBoundsY = self.navigationController.navigationBar.frame.size.height + [UIApplication sharedApplication].statusBarFrame.size.height;

        self.searchBar = [[UISearchBar alloc]initWithFrame:CGRectMake(0,self.searchBarBoundsY,[UIScreen mainScreen].bounds.size.width, 44)];

        self.searchBar.searchBarStyle       = UISearchBarStyleMinimal;
        self.searchBar.tintColor            = [UIColor blackColor];
        self.searchBar.barTintColor         = [UIColor blackColor];
        self.searchBar.delegate             = self;
        self.searchBar.placeholder          = @"search here";

        // add KVO observer.. so we will be informed when user scroll colllectionView
        [self addObservers];
    }

    if (![self.searchBar isDescendantOfView:self.view]) {
        [self.view addSubview:self.searchBar];
    }
}

#pragma mark - observer
- (void)addObservers{
    [self.collectionView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
}
- (void)removeObservers{
    [self.collectionView removeObserver:self forKeyPath:@"contentOffset" context:Nil];
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(UICollectionView *)object change:(NSDictionary *)change context:(void *)context{
    if ([keyPath isEqualToString:@"contentOffset"] && object == self.collectionView ) {
        self.searchBar.frame = CGRectMake(self.searchBar.frame.origin.x,
                                          self.searchBarBoundsY + ((-1* object.contentOffset.y)-self.searchBarBoundsY),
                                          self.searchBar.frame.size.width,
                                          self.searchBar.frame.size.height);
    }
}

- (void)downloadPhotoFromURL:(NSURL*)URL completion:(void(^)(NSURL *URL, UIImage *image))completion {
    static dispatch_queue_t downloadQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        downloadQueue = dispatch_queue_create("downloadQueue", DISPATCH_QUEUE_CONCURRENT);
    });

    dispatch_async(downloadQueue, ^{
        NSData *data = [NSData dataWithContentsOfURL:URL];
        UIImage *image = [UIImage imageWithData:data];

        if(image) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.cache setObject:image forKey:URL];
                if(completion) {
                    completion(URL, image);
                }
            });
        }
    });
}

- (void)showRetryAlertWithError:(NSError*)error {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error fetching data", @"") message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];

    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", @"") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {

    }]];

    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Retry", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self fetchData:nil];
    }]];

    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - search

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar{
    [self cancelSearching];
    [self.collectionView reloadData];
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar{
    [[[FlickrManager sharedManager] photos] removeAllObjects];
    [self.collectionView setHidden:YES];
    [[FlickrManager sharedManager] fetchDataForText:searchBar.text completionBlock:^(NSMutableArray *photos, NSError *error) {
        if (error) {
            [self showRetryAlertWithError:error];
        } else {
            self.photos = photos;
            [self.collectionView setHidden:NO];
            [self.collectionView reloadData];
        }
    }];
    self.searchBarActive = YES;
    [self.view endEditing:YES];
}
- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar{
    // we used here to set self.searchBarActive = YES
    // but we'll not do that any more... it made problems
    // it's better to set self.searchBarActive = YES when user typed something
    [self.searchBar setShowsCancelButton:YES animated:YES];
}
- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar{
    // this method is being called when search btn in the keyboard tapped
    // we set searchBarActive = NO
    // but no need to reloadCollectionView
    self.searchBarActive = NO;
    [self.searchBar setShowsCancelButton:NO animated:YES];
}
-(void)cancelSearching{
    self.searchBarActive = NO;
    [self.searchBar resignFirstResponder];
    self.searchBar.text  = @"";
}

@end
