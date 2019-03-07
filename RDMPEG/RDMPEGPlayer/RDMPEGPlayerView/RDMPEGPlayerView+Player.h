//
//  RDMPEGPlayerView+Player.h
//  RDMPEG
//
//  Created by Serhii Alpieiev on 10/5/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import <RDMPEG/RDMPEG.h>

@class RDMPEGRenderView;



NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGPlayerView (Player)

@property (nonatomic, strong, nullable) RDMPEGRenderView *renderView;
@property (nonatomic, strong, nullable) NSString *subtitle;

@end

NS_ASSUME_NONNULL_END
