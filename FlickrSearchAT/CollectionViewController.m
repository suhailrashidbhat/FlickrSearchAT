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
#import "UIScrollView+SVInfiniteScrolling.h"
#import "ImageViewController.h"
#import "HistoryViewController.h"
#import <FSImageViewer/FSBasicImage.h>
#import <FSImageViewer/FSBasicImageSource.h>

static NSString* const kCellIdentifier = @"PhotoCell";
static NSString *const kAPIEndpointURL = @"https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=3e7cc266ae2b0e0d78e279ce8e361736&format=json&nojsoncallback=1&text=kittens";

@interface CollectionViewController ()<UISearchBarDelegate, UIScrollViewDelegate, UITableViewDelegate, UITableViewDataSource>

@property (nonatomic,strong) NSMutableArray        *photos; // URLs
@property (nonatomic)        BOOL           searchBarActive;
@property (nonatomic)        float          searchBarBoundsY;
@property (nonatomic,strong) UISearchBar        *searchBar;
@property (nonatomic, assign) NSUInteger lastPageIndex;
@property (nonatomic, strong) NSMutableArray *recentArray;
@property (nonatomic, strong) DGActivityIndicatorView *indicatorView;
@property (nonatomic) CGFloat previousScrollViewYOffset;
@property (nonatomic, strong) NSMutableArray *failedImages; // IndexPaths;
@property (nonatomic, strong) UIView *searchResultsView;
@property (nonatomic, strong) UITableView *searchResultTable;
@property (nonatomic, strong) NSArray *filteredResults;
@property (nonatomic, strong) UIImageView *goUpView;

@end

@implementation CollectionViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self initializeUI];

    self.photos = [NSMutableArray array];
    self.failedImages = [NSMutableArray array];

    [self loadData];

    __weak CollectionViewController *weakSelf = self;
    [self.collectionView addInfiniteScrollingWithActionHandler:^{
        [weakSelf fetchMoreImages];
    }];

    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"recentSearch"]) {
        self.recentArray =  [[[NSUserDefaults standardUserDefaults] objectForKey:@"recentSearch"] mutableCopy];
    }
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceRotated) name:UIDeviceOrientationDidChangeNotification object:nil];

    [self addSearchBar];
    self.searchBar.text = [[FlickrManager sharedManager] lastSearchQuery];

    // Check if data needs refresh!
    
    if ([[FlickrManager sharedManager] dataNeedsRefresh]) {
        [[FlickrManager sharedManager] setDataNeedsRefresh:NO];
        [self.photos removeAllObjects];
        [[[FlickrManager sharedManager] photos] removeAllObjects];
        [self.collectionView setHidden:YES];
        [self.indicatorView setHidden:NO];
        [self.indicatorView startAnimating];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // cpu intensive code
            [self refreshData];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.indicatorView stopAnimating];
            });
        });
    }
}

-(void)deviceRotated {
    self.indicatorView.frame = self.view.frame;
    [self.view addSubview:self.indicatorView];
    [self.searchBar setFrame:CGRectMake(0,self.searchBarBoundsY,[UIScreen mainScreen].bounds.size.width, 44)];
    [self.collectionView reloadData];
}

- (IBAction)historyTapped:(id)sender {
    HistoryViewController *historyVC = [self.storyboard instantiateViewControllerWithIdentifier:@"HistoryViewController"];
    historyVC.searchQueries = self.recentArray;
    [self.navigationController pushViewController:historyVC animated:YES];
}

-(void)fetchMoreImages{
    [[FlickrManager sharedManager] fetchNextPageDataForText:[[FlickrManager sharedManager] lastSearchQuery] completionBlock:^(NSMutableArray *photos, NSError *error) {
        if ([error.domain isEqualToString:@"com.srb.resultend"]) {
            [self.collectionView.infiniteScrollingView stopAnimating];
            return;
        }
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

-(void)loadData {
    [self refreshData];
}

-(void)refreshData {
    [[FlickrManager sharedManager] fetchDataForText:[[FlickrManager sharedManager] lastSearchQuery] completionBlock:^(NSMutableArray *photos, NSError *error) {
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
}

#pragma mark UICollectionViewDataSource

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
    UIColor *randomRGBColor = [[UIColor alloc] initWithRed:arc4random()%256/256.0
                                                     green:arc4random()%256/256.0
                                                      blue:arc4random()%256/256.0
                                                     alpha:0.5];
    cell.backgroundColor = randomRGBColor;
    [cell.imageView setHidden:YES];
    [cell.imageView sd_setImageWithURL:photoURL completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
        [cell.activityIndicator stopAnimating];
        [cell.activityIndicator setHidden:YES];
        [cell.imageView setHidden:NO];
        if (error || !image) {
            [[[FlickrManager sharedManager] imageFailedBacklog] addObject:imageURL];
            cell.imageView.contentMode = UIViewContentModeCenter;
            cell.imageView.image = [UIImage imageNamed:@"reload"];
            NSLog(@"\nImage download failed with error %@", error);
        } else  {
            [cell.imageView setBackgroundColor:[UIColor blackColor]];
        }
    }];
    return cell;
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    PhotoCollectionViewCell *cell = (PhotoCollectionViewCell*)[collectionView cellForItemAtIndexPath:indexPath];
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];

    if ([cell.imageView.image isEqual:[UIImage imageNamed:@"reload"]]) {
        // Attempt to download again
        [cell.imageView sd_setImageWithURL:self.photos[indexPath.row] placeholderImage:nil options:SDWebImageRetryFailed completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
            [cell.activityIndicator stopAnimating];
            [cell.activityIndicator setHidden:YES];
            [cell.imageView setHidden:NO];
            if ((error || !image) && cell) {
                [[[FlickrManager sharedManager] imageFailedBacklog] addObject:imageURL];
                cell.imageView.contentMode = UIViewContentModeCenter;
                cell.imageView.image = [UIImage imageNamed:@"reload"];
                NSLog(@"\nImage download failed with error %@ for url %@", error, imageURL);
            } else  {
                [cell.imageView setBackgroundColor:[UIColor blackColor]];
            }
        }];
        return;
    }
    
    NSMutableArray *fsbImages = [NSMutableArray array];
    for (int i = 0; i<self.photos.count; i++) {
        FSBasicImage *image = [[FSBasicImage alloc] initWithImageURL:self.photos[i]];
        [fsbImages addObject:image];
    }

    FSBasicImageSource *photoSource = [[FSBasicImageSource alloc] initWithImages:fsbImages];
    
    //ImageViewController *imageController = [self.storyboard instantiateViewControllerWithIdentifier:@"ImageViewController"];
    ImageViewController *imageVC = [[ImageViewController alloc] initWithImageSource:photoSource];
    [imageVC moveToImageAtIndex:indexPath.row animated:NO];
   // imageController.photoURL = self.photos[indexPath.row];
    [self.navigationController pushViewController:imageVC animated:YES];
}

#pragma mark -  UICollectionViewDelegateFlowLayout
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

-(void)initializeUI {
    self.indicatorView = [[DGActivityIndicatorView alloc] initWithType:DGActivityIndicatorAnimationTypeBallScaleMultiple tintColor:UIColorFromRGB(0x2398B5)];
    self.indicatorView.frame = self.view.frame;
    [self.view addSubview:self.indicatorView];
    [self.indicatorView startAnimating];

    self.goUpView = [[UIImageView alloc] initWithFrame:CGRectMake(self.collectionView.frame.size.width - 60, self.collectionView.frame.size.height - 60, 40, 40)];
    self.goUpView.contentMode = UIViewContentModeScaleAspectFit;
    self.goUpView.image = [UIImage imageNamed:@"goup"];
    self.goUpView.userInteractionEnabled = YES;
    UITapGestureRecognizer *singleTap =  [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(scrollToUP)];
    [singleTap setNumberOfTapsRequired:1];
    [self.goUpView addGestureRecognizer:singleTap];
    [self.goUpView setHidden:YES];
    self.goUpView.alpha = 0.5;
    [self.view addSubview:self.goUpView];

    self.searchResultsView = [[UIView alloc] initWithFrame:CGRectMake(0, self.collectionView.frame.origin.y + 44 + 5, self.collectionView.frame.size.width, self.collectionView.frame.size.height)];
    self.searchResultTable = [[UITableView alloc] initWithFrame:self.searchResultsView.frame style:UITableViewStylePlain];
    self.searchResultTable.delegate = self;
    self.searchResultTable.dataSource = self;
    [self.searchResultsView addSubview:self.searchResultTable];
    [self.view addSubview:self.searchResultsView];
    [self.searchResultsView setHidden:YES];
    [self addNavigationItems];
    self.navigationController.navigationBarHidden = NO;
    [self.navigationController.navigationBar setTintColor:UIColorFromRGB(0x2398B5)];
    self.view.backgroundColor = [UIColor whiteColor];
    self.collectionView.backgroundColor = [UIColor whiteColor];
}

-(void)scrollToUP {
    [self.collectionView setContentOffset:
     CGPointMake(0, -self.collectionView.contentInset.top) animated:YES];
}

-(void)addSearchBar{
    if (!self.searchBar) {
        self.searchBarBoundsY = self.navigationController.navigationBar.frame.size.height + [UIApplication sharedApplication].statusBarFrame.size.height;
        self.searchBar = [[UISearchBar alloc]initWithFrame:CGRectMake(0,self.searchBarBoundsY,[UIScreen mainScreen].bounds.size.width, 44)];
        self.searchBar.searchBarStyle       = UISearchBarStyleMinimal;
        self.searchBar.delegate             = self;
        self.searchBar.placeholder          = @"Search Images";
        // add KVO observer.. so we will be informed when user scroll colllectionView
        [self addObservers];
    }

    if (![self.searchBar isDescendantOfView:self.view]) {
        [self.view addSubview:self.searchBar];
    }
}


- (void)showRetryAlertWithError:(NSError*)error {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error fetching data", @"") message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];

    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", @"") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {

    }]];

    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Retry", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[FlickrManager sharedManager] fetchDataForText:[[FlickrManager sharedManager] lastSearchQuery] completionBlock:^(NSMutableArray *photos, NSError *error) {
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

#pragma mark - search

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar{
    [self cancelSearching];
    [self.collectionView reloadData];
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar{
    [self.searchResultsView setHidden:YES];
    [self.collectionView setHidden:NO];

    if (!searchBar.text.length) {
        return;
    }

    [self updateSearchHistoryWithText:searchBar.text];

    NSString *searchText = [self sanitizeSearchKeyword:searchBar.text];

    [[FlickrManager sharedManager] setLastSearchQuery:searchText];

    [[[FlickrManager sharedManager] photos] removeAllObjects];
    [self.collectionView setHidden:YES];
    [self.indicatorView setHidden:NO];
    [self.indicatorView startAnimating];
    [[FlickrManager sharedManager] fetchDataForText:searchText completionBlock:^(NSMutableArray *photos, NSError *error) {
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

-(void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if(searchBar.text.length) {
        [self updateFilteredResultsWithString:searchText];
        [self.searchResultsView setHidden:NO];
        [self.searchResultTable reloadData];
    } else {
        [self.searchResultsView setHidden:YES];
    }
}

-(void)updateFilteredResultsWithString:(NSString*)string {
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] %@", string];
    self.filteredResults = [self.recentArray filteredArrayUsingPredicate:predicate];
    [self.searchResultTable reloadData];
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
    if (!self.searchResultsView.isHidden || (([[UIDevice currentDevice] orientation] == UIDeviceOrientationLandscapeRight) || ([[UIDevice currentDevice] orientation] == UIInterfaceOrientationLandscapeLeft))) {
        return;
    }
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
    if (alpha == 0.0) {
        self.navigationItem.leftBarButtonItem = nil;
        self.navigationItem.rightBarButtonItem = nil;
        self.title = nil;
        [self.goUpView setHidden:NO];
    } else if (alpha == 1.0) {
        [self.goUpView setHidden:YES];
    } else {
        [self addNavigationItems];
    }
}

-(void)addNavigationItems {
    NSDictionary *attributes = @{
                                 NSUnderlineStyleAttributeName: @1,
                                 NSForegroundColorAttributeName : UIColorFromRGB(0x2398B5),
                                 NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue" size:15]
                                 };
    self.title = @"Flickr Search";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[[UIImage imageNamed:@"FlickrLogo"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:nil];
    [self.navigationItem.leftBarButtonItem setEnabled:NO];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[[UIImage imageNamed:@"history"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(historyTapped:)];

    [self.navigationController.navigationBar setTitleTextAttributes:attributes];
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

#pragma mark TableView Delegate and Data Source for Recent Search


-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredResults.count;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50.0;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *searchCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"searchCell"];
    searchCell.textLabel.text = self.filteredResults[indexPath.row];
    searchCell.backgroundColor = [UIColor whiteColor];
    searchCell.textLabel.textColor = UIColorFromRGB(0x2398B5);
    searchCell.textLabel.font = [UIFont fontWithName:@"HelveticaNeue-Regular" size:17];
    return searchCell;
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @"Recent Searches";
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self.view endEditing:YES];
    self.searchBar.text = self.filteredResults[indexPath.row];
    [[FlickrManager sharedManager] setLastSearchQuery:self.filteredResults[indexPath.row]];
    [self.searchResultsView setHidden:YES];
    [self.collectionView setHidden:YES];
    [self.photos removeAllObjects];
    [self.indicatorView setHidden:NO];
    [self.indicatorView startAnimating];
    [self refreshData];
}

#pragma mark Previewing Context - 3D Touch Implementation

-(UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location {
    NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:location];

    PhotoCollectionViewCell *cell = (PhotoCollectionViewCell*)[self.collectionView cellForItemAtIndexPath:indexPath];
    FSBasicImage *image = [[FSBasicImage alloc] initWithImageURL:self.photos[indexPath.row]];
    FSBasicImageSource *photoSource = [[FSBasicImageSource alloc] initWithImages:@[image]];

    ImageViewController *imageVC = [[ImageViewController alloc] initWithImageSource:photoSource];
    [imageVC moveToImageAtIndex:indexPath.row animated:NO];
    [self.navigationController pushViewController:imageVC animated:YES];
    imageVC.preferredContentSize = CGSizeMake(0.0, 320.0);
    previewingContext.sourceRect = cell.frame;
    return imageVC;
}

-(void)previewingContext:(id<UIViewControllerPreviewing>)previewingContext commitViewController:(UIViewController *)viewControllerToCommit {
    [self.navigationController showViewController:viewControllerToCommit sender:self];
}

@end
