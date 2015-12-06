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
#import <DGActivityIndicatorView/DGActivityIndicatorView.h>
#import <SVPullToRefresh/SVPullToRefresh.h>
#import "ImageViewController.h"

static NSString* const kCellIdentifier = @"PhotoCell";
static NSString *const kAPIEndpointURL = @"https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=3e7cc266ae2b0e0d78e279ce8e361736&format=json&nojsoncallback=1&text=kittens";

@interface CollectionViewController ()<UISearchBarDelegate, UIScrollViewDelegate>

@property (nonatomic,strong) NSMutableArray        *photos; // URLs
@property (nonatomic)        BOOL           searchBarActive;
@property (nonatomic)        float          searchBarBoundsY;
@property (nonatomic,strong) UISearchBar        *searchBar;
@property (nonatomic, assign) NSUInteger lastPageIndex;
@property (nonatomic, strong) NSMutableArray *recentArray;
@property (nonatomic, strong) DGActivityIndicatorView *indicatorView;
@property (nonatomic, strong) NSString *lastSearchQuery;
@property (nonatomic) CGFloat previousScrollViewYOffset;

@property NSCache *cache;

@end

@implementation CollectionViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self initializeUI];

    self.cache = [[NSCache alloc] init];
    self.photos = [NSMutableArray array];

    [[FlickrManager sharedManager] fetchDataForText:@"love" completionBlock:^(NSMutableArray *photoURLs, NSError *error) {
        [self.indicatorView stopAnimating];
        [self.indicatorView setHidden:YES];
        if (error) {
            [self showRetryAlertWithError:error];
        } else {
            self.photos = photoURLs;
            [self.collectionView reloadData];
        }
    }];

    __weak CollectionViewController *weakSelf = self;
    [self.collectionView addInfiniteScrollingWithActionHandler:^{
        [weakSelf fetchMoreImages];
    }];

    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"recentSearch"]) {
        self.recentArray =  [[[NSUserDefaults standardUserDefaults] objectForKey:@"recentSearch"] mutableCopy];
    }
}

-(void)initializeUI {
    self.indicatorView = [[DGActivityIndicatorView alloc] initWithType:DGActivityIndicatorAnimationTypeBallScaleMultiple tintColor:UIColorFromRGB(0x2398B5)];
    self.indicatorView.frame = self.view.frame;
    [self.view addSubview:self.indicatorView];
    [self.indicatorView startAnimating];

    self.navigationController.navigationBarHidden = NO;
    self.view.backgroundColor = [UIColor whiteColor];
    self.collectionView.backgroundColor = [UIColor whiteColor];
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceRotated) name:UIDeviceOrientationDidChangeNotification object:nil];
    [self addSearchBar];
}

-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
}

-(void)deviceRotated {
    self.indicatorView.frame = self.view.frame;
    [self.view addSubview:self.indicatorView];
    [self.searchBar setFrame:CGRectMake(0,self.searchBarBoundsY,[UIScreen mainScreen].bounds.size.width, 44)];
    [self.collectionView reloadData];
}

-(void)fetchMoreImages{
    [[FlickrManager sharedManager] fetchNextPageDataForText:self.lastSearchQuery completionBlock:^(NSMutableArray *photos, NSError *error) {
        if (error) {
            [self showRetryAlertWithError:error];
        } else {
            __weak CollectionViewController *weakSelf = self;
            int64_t delayInSeconds = 2.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                NSUInteger lastIndex = self.photos.count - kPageSize;
                NSMutableArray *indexPs = [NSMutableArray array];
                for (NSUInteger i = lastIndex; i<photos.count; i++) {
                    [indexPs addObject:[NSIndexPath indexPathForItem:i inSection:0]];
                }
                [weakSelf.collectionView insertItemsAtIndexPaths:indexPs];
                [weakSelf.collectionView.infiniteScrollingView stopAnimating];
            });
        }
    }];


}

-(void)dealloc{
    // remove Our KVO observer
    [self removeObservers];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


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


-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
    ImageViewController *imageController = [self.storyboard instantiateViewControllerWithIdentifier:@"ImageViewController"];
    imageController.photoURL = self.photos[indexPath.row];
    [self.navigationController pushViewController:imageController animated:YES];
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

#pragma mark - prepareVC

-(void)addSearchBar{
    if (!self.searchBar) {
        self.searchBarBoundsY = self.navigationController.navigationBar.frame.size.height + [UIApplication sharedApplication].statusBarFrame.size.height;
        self.searchBar = [[UISearchBar alloc]initWithFrame:CGRectMake(0,self.searchBarBoundsY,[UIScreen mainScreen].bounds.size.width, 44)];
        self.searchBar.searchBarStyle       = UISearchBarStyleMinimal;
        self.searchBar.tintColor            = [UIColor blackColor];
        self.searchBar.barTintColor         = [UIColor blackColor];
        self.searchBar.delegate             = self;
        self.searchBar.placeholder          = @"Search Images";

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

- (void)showRetryAlertWithError:(NSError*)error {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error fetching data", @"") message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];

    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", @"") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {

    }]];

    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Retry", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[FlickrManager sharedManager] fetchDataForText:self.lastSearchQuery completionBlock:^(NSMutableArray *photos, NSError *error) {
            if (error) {
                [self showRetryAlertWithError:error];
            } else {
                self.photos = photos;
                [self.collectionView reloadData];
            }
        }];
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - search

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar{
    [self cancelSearching];
    [self.collectionView reloadData];
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar{

    NSString *searchText = [self sanitizeSearchKeyword:searchBar.text];
    if (!searchText.length) {
        return;
    }
    self.lastSearchQuery = searchText;
    [self updateSearchHistoryWithText:searchText];

    [[[FlickrManager sharedManager] photos] removeAllObjects];
    [self.collectionView setHidden:YES];
    [self.indicatorView setHidden:NO];
    [self.indicatorView startAnimating];
    [[FlickrManager sharedManager] fetchDataForText:searchBar.text completionBlock:^(NSMutableArray *photos, NSError *error) {
        [self.indicatorView setHidden:YES];
        [self.indicatorView stopAnimating];
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
    [self.searchBar setShowsCancelButton:YES animated:YES];
}
- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar{
    self.searchBarActive = NO;
    [self.searchBar setShowsCancelButton:NO animated:YES];
}
-(void)cancelSearching{
    self.searchBarActive = NO;
    [self.searchBar resignFirstResponder];
    self.searchBar.text  = @"";
}

-(NSString*)sanitizeSearchKeyword:(NSString*)keyword {
    NSString *string = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [string lowercaseString];
}

-(void)updateSearchHistoryWithText:(NSString*)searchText {
    // Managing recent Search history
    NSMutableArray *recentArray;
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"recentSearch"]) {
        NSArray *imArray = [[NSUserDefaults standardUserDefaults] objectForKey:@"recentSearch"];
        recentArray = [NSMutableArray arrayWithArray:imArray];
        if ([recentArray containsObject:searchText]) {
            [recentArray removeObject:searchText];
        }
        [recentArray insertObject:searchText atIndex:0];
        [[NSUserDefaults standardUserDefaults] setObject:recentArray forKey:@"recentSearch"];
    } else {
        recentArray = [NSMutableArray arrayWithObject:searchText];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"recentSearch"];
        [[NSUserDefaults standardUserDefaults] setObject:recentArray forKey:@"recentSearch"];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];

    [self.recentArray removeAllObjects];
    self.recentArray = recentArray;
}

#pragma mark UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGRect frame = self.navigationController.navigationBar.frame;
    CGFloat size = frame.size.height - 21;
    CGFloat framePercentageHidden = ((20 - frame.origin.y) / (frame.size.height - 1));
    CGFloat scrollOffset = scrollView.contentOffset.y;
    CGFloat scrollDiff = scrollOffset - self.previousScrollViewYOffset;
    CGFloat scrollHeight = scrollView.frame.size.height;
    CGFloat scrollContentSizeHeight = scrollView.contentSize.height + scrollView.contentInset.bottom;

    if (scrollOffset <= -scrollView.contentInset.top) {
        frame.origin.y = 20;
    } else if ((scrollOffset + scrollHeight) >= scrollContentSizeHeight) {
        frame.origin.y = -size;
    } else {
        frame.origin.y = MIN(20, MAX(-size, frame.origin.y - (frame.size.height * (scrollDiff / scrollHeight))));
    }

    [self.navigationController.navigationBar setFrame:frame];
    [self updateBarButtonItems:(1 - framePercentageHidden)];
    self.previousScrollViewYOffset = scrollOffset;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self stoppedScrolling];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView
                  willDecelerate:(BOOL)decelerate
{
    if (!decelerate) {
        [self stoppedScrolling];
    }
}

- (void)stoppedScrolling
{
    CGRect frame = self.navigationController.navigationBar.frame;
    if (frame.origin.y < 20) {
        [self animateNavBarTo:-(frame.size.height - 21)];
    }
}

- (void)updateBarButtonItems:(CGFloat)alpha
{
    [self.navigationItem.leftBarButtonItems enumerateObjectsUsingBlock:^(UIBarButtonItem* item, NSUInteger i, BOOL *stop) {
        item.customView.alpha = alpha;
    }];
    [self.navigationItem.rightBarButtonItems enumerateObjectsUsingBlock:^(UIBarButtonItem* item, NSUInteger i, BOOL *stop) {
        item.customView.alpha = alpha;
    }];
    self.navigationItem.titleView.alpha = alpha;
    self.navigationController.navigationBar.tintColor = [self.navigationController.navigationBar.tintColor colorWithAlphaComponent:alpha];
}

- (void)animateNavBarTo:(CGFloat)y
{
    [UIView animateWithDuration:0.2 animations:^{
        CGRect frame = self.navigationController.navigationBar.frame;
        CGFloat alpha = (frame.origin.y >= y ? 0 : 1);
        frame.origin.y = y;
        [self.navigationController.navigationBar setFrame:frame];
        [self updateBarButtonItems:alpha];
    }];
}


@end
