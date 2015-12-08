//
//  PhotoEntity.m
//  FlickrSearchAT
//
//  Created by Suhail Bhat on 08/12/15.
//  Copyright © 2015 SRB. All rights reserved.
//

#import "PhotoEntity.h"

@implementation PhotoEntity

-(instancetype)initWithDictionary:(NSDictionary*)dictionary {
    self = [[PhotoEntity alloc] init];
    if ([dictionary objectForKey:@"id"] && [dictionary objectForKey:@"id"] != [NSNull null]) {
        self.uid = [dictionary objectForKey:@"id"];
    }
    if ([dictionary objectForKey:@"owner"] && [dictionary objectForKey:@"owner"] != [NSNull null]) {
        self.owner = [dictionary objectForKey:@"owner"];
    }
    if ([dictionary objectForKey:@"secret"] && [dictionary objectForKey:@"secret"] != [NSNull null]) {
        self.secret = [dictionary objectForKey:@"secret"];
    }
    if ([dictionary objectForKey:@"farm"] && [dictionary objectForKey:@"farm"] != [NSNull null]) {
        self.farm = [dictionary objectForKey:@"farm"];
    }
    if ([dictionary objectForKey:@"server"] && [dictionary objectForKey:@"server"] != [NSNull null]) {
        self.server = [dictionary objectForKey:@"server"];
    }
    if ([dictionary objectForKey:@"title"] && [dictionary objectForKey:@"title"] != [NSNull null]) {
        self.title = [dictionary objectForKey:@"title"];
    }
    return self;
}

-(NSURL*)getPhotoURL {
    NSString *urlS = [NSString stringWithFormat:@"https://farm%@.static.flickr.com/%@/%@_%@.jpg", self.farm, self.server, self.uid, self.secret];
    return [NSURL URLWithString:urlS];
}

@end
