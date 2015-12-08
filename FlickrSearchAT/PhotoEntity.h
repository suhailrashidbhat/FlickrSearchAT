//
//  PhotoEntity.h
//  FlickrSearchAT
//
//  Created by Suhail Bhat on 08/12/15.
//  Copyright © 2015 SRB. All rights reserved.
//

// Response from flickr API

/*{
 "id": "23528032911",
 "owner": "45976353@N06",
 "secret": "18eb73aea4",
 "server": "667",
 "farm": 1,
 "title": "DSCF2235 Château de Vaussieux, Vaux-sur-Seulles",
 "ispublic": 1,
 "isfriend": 0,
 "isfamily": 0
 }*/

#import <Foundation/Foundation.h>

@interface PhotoEntity : NSObject

@property (nonatomic, strong) NSString *uid;
@property (nonatomic, strong) NSString *owner;
@property (nonatomic, strong) NSString *secret;
@property (nonatomic, strong) NSString *server;
@property (nonatomic, strong) NSString *farm;
@property (nonatomic, strong) NSString *title;

-(instancetype)initWithDictionary:(NSDictionary*)dictionary;
-(NSURL*)getPhotoURL;

@end
