//
//  HistoryViewController.m
//  FlickrSearchAT
//
//  Created by Suhail Bhat on 07/12/15.
//  Copyright © 2015 SRB. All rights reserved.
//

#import "HistoryViewController.h"

@interface HistoryViewController ()<UITableViewDataSource, UITableViewDelegate>

@property (strong, nonatomic) IBOutlet UITableView *historyTable;

@end

@implementation HistoryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(askAndClearHistory)];
    self.historyTable.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)clearHistory {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"recentSearch"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self.searchQueries removeAllObjects];
    [self.historyTable reloadData];
}

-(void)askAndClearHistory {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Clear History" message:@"Are you sure you want to clear your search history?" preferredStyle:UIAlertControllerStyleAlert];

    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", @"") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {

    }]];

    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"DELETE", @"") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self clearHistory];
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark UITableView DS DEL

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.searchQueries.count;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    cell.textLabel.text = self.searchQueries[indexPath.row];
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *searchItem = self.searchQueries[indexPath.row];
    [[FlickrManager sharedManager] setLastSearchQuery:searchItem];
    [[FlickrManager sharedManager] setDataNeedsRefresh:YES];
    [self.navigationController popViewControllerAnimated:YES];
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @"Search History";
}

@end
