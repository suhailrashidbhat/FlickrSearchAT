//
//  Constants.h
//  FlickrSearchAT
//
//  Created by Suhail Bhat on 06/12/15.
//  Copyright © 2015 SRB. All rights reserved.
//

#ifndef Constants_h
#define Constants_h


//RGB color macro
#define UIColorFromRGB(rgbValue) [UIColor \
colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 \
green:((float)((rgbValue & 0xFF00) >> 8))/255.0 \
blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]



#endif /* Constants_h */
