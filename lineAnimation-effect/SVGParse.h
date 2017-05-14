//
//  SVGParse.h
//  lineAnimation-effect
//
//  Created by JaminZhou on 2017/5/14.
//  Copyright © 2017年 Hangzhou Tomorning Technology Co., Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef enum {
    SVGCommandLine,
    SVGCommandPath,
    SVGCommandCircle,
    SVGCommandEllipse,
    SVGCommandPolyline
}SVGCommandType;

@interface SVGParse : NSObject 

+ (CALayer *)layerFromSVGPath:(NSDictionary *)pathDict command:(SVGCommandType)command;

@end

@interface UIView (Addition)
- (void)removeAllSublayer;
- (void)removeAllSubview;
@end
