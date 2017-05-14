//
//  SVGParse.m
//  lineAnimation-effect
//
//  Created by JaminZhou on 2017/5/14.
//  Copyright © 2017年 Hangzhou Tomorning Technology Co., Ltd. All rights reserved.
//

#import "SVGParse.h"

NSInteger const maxPathComplexity	= 1000;
NSInteger const maxParameters		= 64;
NSInteger const maxTokenLength		= 64;
NSString* const separatorCharString = @"-, CcMmLlHhVvZzqQaAsS";
NSString* const commandCharString	= @"CcMmLlHhVvZzqQaAsS";
unichar const invalidCommand		= '*';

#define KScale UIScreen.mainScreen.scale


@interface Token : NSObject {
@private
    unichar			command;
    NSMutableArray  *values;
}

- (id)initWithCommand:(unichar)commandChar;
- (void)addValue:(CGFloat)value;
- (CGFloat)parameter:(NSInteger)index;
- (NSInteger)valence;
@property(nonatomic) unichar command;
@end


@implementation Token

+ (Token*) tokenWithCommand:(unichar) commandChar {
    Token *token = [[Token alloc] initWithCommand:commandChar];
    return token;
}

- (id)initWithCommand:(unichar)commandChar {
    self = [self init];
    if (self) {
        command = commandChar;
        values = [[NSMutableArray alloc] initWithCapacity:maxParameters];
    }
    return self;
}

- (void)addValue:(CGFloat)value {
    [values addObject:[NSNumber numberWithDouble:value]];
}

- (CGFloat)parameter:(NSInteger)index {
    return [[values objectAtIndex:index] doubleValue];
}

- (NSInteger)valence
{
    return [values count];
}


@synthesize command;

@end


@interface SVGParse (){
@private
    float			pathScale;
    UIBezierPath    *bezier;
    CGPoint			lastPoint;
    CGPoint			lastControlPoint;
    BOOL			validLastControlPoint;
    NSCharacterSet  *separatorSet;
    NSCharacterSet  *commandSet;
    NSMutableArray  *tokens;
}
@property(nonatomic, readonly) UIBezierPath *bezier;
@end


@implementation SVGParse

@synthesize bezier;

+ (CALayer *)layerFromSVGPath:(NSDictionary *)pathDict command:(SVGCommandType)command {
    switch (command) {
        case SVGCommandLine:
            return [SVGParse lineFromSVGPath:pathDict];
        case SVGCommandPath:
            return [SVGParse pathFromSVGPath:pathDict];
        case SVGCommandCircle:
            return [SVGParse circleFromSVGPath:pathDict];
        case SVGCommandEllipse:
            return [SVGParse ellipseFromSVGPath:pathDict];
        case SVGCommandPolyline:
            return [SVGParse polylineFromSVGPath:pathDict];
        default:
            return [CALayer layer];
    }
}

+ (CALayer *)pathFromSVGPath:(NSDictionary *)pathDict {
    NSString *pathString = pathDict[@"d"];
    SVGParse *svgParse = [SVGParse SVGParseFromSVGPathNodeDAttr:pathString];
    svgParse.bezier.flatness = 1;
    return [SVGParse convertLayer:svgParse.bezier.CGPath pathDict:pathDict];
}

+ (CALayer *)lineFromSVGPath:(NSDictionary *)pathDict {
    CGPoint point1 = CGPointMake([pathDict[@"x1"] floatValue]/KScale, [pathDict[@"y1"] floatValue]/KScale);
    CGPoint point2 = CGPointMake([pathDict[@"x2"] floatValue]/KScale, [pathDict[@"y2"] floatValue]/KScale);
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:point1];
    [path addLineToPoint:point2];
    return [SVGParse convertLayer:path.CGPath pathDict:pathDict];
}

+ (CALayer *)circleFromSVGPath:(NSDictionary *)pathDict {
    NSString *x = pathDict[@"cx"];
    NSString *y = pathDict[@"cy"];
    NSString *r = pathDict[@"r"];
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path addArcWithCenter:CGPointMake(x.floatValue/KScale, y.floatValue/KScale) radius:r.floatValue/KScale startAngle:0 endAngle:2*M_PI clockwise:YES];
    return [SVGParse convertLayer:path.CGPath pathDict:pathDict];
}

+ (CALayer *)ellipseFromSVGPath:(NSDictionary *)pathDict {
    CGFloat x = [pathDict[@"cx"] floatValue]/KScale;
    CGFloat y = [pathDict[@"cy"] floatValue]/KScale;
    CGFloat rx = [pathDict[@"rx"] floatValue]/KScale;
    CGFloat ry = [pathDict[@"ry"] floatValue]/KScale;
    UIBezierPath* path = [UIBezierPath bezierPathWithOvalInRect: CGRectMake(x-rx, y-ry, rx*2, ry*2)];
    return [SVGParse convertLayer:path.CGPath pathDict:pathDict];
}

+ (CALayer *)polylineFromSVGPath:(NSDictionary *)pathDict {
    NSString *points = pathDict[@"points"];
    NSArray *components = [points componentsSeparatedByString:@" "];
    UIBezierPath *path = [UIBezierPath bezierPath];
    for (int i=0; i<components.count; i++) {
        NSString *s = components[i];
        NSArray *com = [s componentsSeparatedByString:@","];
        NSString *x = com[0];
        NSString *y = com[1];
        CGPoint p = CGPointMake(x.floatValue/KScale, y.floatValue/KScale);
        if (i==0) {
            [path moveToPoint:p];
        } else {
            [path addLineToPoint:p];
        }
    }

    return [SVGParse convertLayer:path.CGPath pathDict:pathDict];
}

+ (CALayer *)convertLayer:(CGPathRef)path pathDict:(NSDictionary *)pathDict {
    CAShapeLayer *layer = [CAShapeLayer layer];
    layer.path = path;
    layer.strokeColor = [UIColor whiteColor].CGColor;
    layer.fillColor = [UIColor clearColor].CGColor;
    CGFloat strokeWidth = [pathDict[@"stroke-width"] floatValue]/KScale;
    layer.lineWidth = strokeWidth;
    return layer;
}

- (id)initFromSVGPathNodeDAttr:(NSString *)attr//
{
    self = [super init];
    if (self) {
        pathScale = 0;
        [self reset];
        separatorSet    = [NSCharacterSet characterSetWithCharactersInString:separatorCharString];
        commandSet      = [NSCharacterSet characterSetWithCharactersInString:commandCharString];
        tokens          = [self parsePath:attr];
        
        [self generateBezier:tokens];
    }
    return self;
}

+ (SVGParse*)SVGParseFromSVGPathNodeDAttr:(NSString *)attr//
{
    SVGParse *svgParse = [[SVGParse alloc] initFromSVGPathNodeDAttr:attr];
    return svgParse;
}

#pragma mark - Private methods
- (NSMutableArray *)parsePath:(NSString *)attr//
{
    NSMutableArray *stringTokens = [NSMutableArray arrayWithCapacity: maxPathComplexity];
    
    NSInteger index = 0;
    while (index < [attr length]) {
        unichar	charAtIndex = [attr characterAtIndex:index];
        //Jagie:Skip whitespace
        if (charAtIndex == 32) {
            index ++;
            continue;
        }
        NSMutableString *stringToken = [NSMutableString stringWithCapacity:maxTokenLength];
        [stringToken setString:@""];
        
        if (charAtIndex != ',') {
            [stringToken appendString:[NSString stringWithFormat:@"%c", charAtIndex]];
        }
        if (![commandSet characterIsMember:charAtIndex] && charAtIndex != ',') {
            // mnk 20150312 fix for scientific notation
            while ( (++index < [attr length]) && (![separatorSet characterIsMember:(charAtIndex = [attr characterAtIndex:index])] || ([attr characterAtIndex:index-1] == 'e') || ([attr characterAtIndex:index-1] == 'E'))) {
                [stringToken appendString:[NSString stringWithFormat:@"%c", charAtIndex]];
            }
        }
        else {
            index++;
        }
        
        if ([stringToken length]) {
            [stringTokens addObject:stringToken];
        }
    }
    
    if ([stringTokens count] == 0) {
        NSLog(@"*** SVGParse Error: Path string is empty of tokens");
        return nil;
    }
    
    // turn the stringTokens array into Tokens, checking validity of tokens as we go
    NSMutableArray* localTokens = [NSMutableArray arrayWithCapacity: maxPathComplexity];
    index = 0;
    NSString *stringToken = [stringTokens objectAtIndex:index];
    unichar command = [stringToken characterAtIndex:0];
    while (index < [stringTokens count]) {
        if (![commandSet characterIsMember:command]) {
            NSLog(@"*** SVGParse Error: Path string parse error: found float where expecting command at token %ld in path %s.",
                  (long)index, [attr cStringUsingEncoding:NSUTF8StringEncoding]);
            return nil;
        }
        Token *token = [Token tokenWithCommand:command];
        
        // There can be any number of floats after a command. Suck them in until the next command.
        while ((++index < [stringTokens count]) && ![commandSet characterIsMember:
                                                     (command = [(stringToken = [stringTokens objectAtIndex:index]) characterAtIndex:0])]) {
            
            NSScanner *floatScanner = [NSScanner scannerWithString:stringToken];
            float value;
            if (![floatScanner scanFloat:&value]) {
                NSLog(@"*** SVGParse Error: Path string parse error: expected float or command at token %ld (but found %s) in path %s.",
                      (long)index, [stringToken cStringUsingEncoding:NSUTF8StringEncoding], [attr cStringUsingEncoding:NSUTF8StringEncoding]);
                return nil;
            }
            // Maintain scale.
            pathScale = (fabsf(value) > pathScale) ? fabsf(value) : pathScale;
            [token addValue:value];
        }
        
        // now we've reached a command or the end of the stringTokens array
        [localTokens	addObject:token];
    }
    
    return localTokens;
}

- (void) generateBezier:(NSArray *)inTokens//
{
    bezier = [[UIBezierPath alloc] init];
    
    [self reset];
    for (Token *thisToken in inTokens) {
        unichar command = [thisToken command];
        switch (command) {
            case 'M':
            case 'm':
                [self appendSVGMCommand:thisToken];
                break;
            case 'L':
            case 'l':
            case 'H':
            case 'h':
            case 'V':
            case 'v':
                [self appendSVGLCommand:thisToken];
                break;
            case 'C':
            case 'c':
                [self appendSVGCCommand:thisToken];
                break;
            case 'S':
            case 's':
                [self appendSVGSCommand:thisToken];
                break;
            case 'Z':
            case 'z':
                [bezier closePath];
                break;
            default:
                NSLog(@"*** SVGParse Error: Cannot process command : '%c'", command);
                break;
        }
    }
}

- (void)reset//
{
    lastPoint = CGPointMake(0, 0);
    validLastControlPoint = NO;
}

- (CGPoint)convertPoint {
    return CGPointMake(lastPoint.x/KScale, lastPoint.y/KScale);
}

- (void)appendSVGMCommand:(Token *)token
{
    validLastControlPoint = NO;
    NSInteger index = 0;
    BOOL first = YES;
    while (index < [token valence]) {
        CGFloat x = [token parameter:index] + ([token command] == 'm' ? lastPoint.x : 0);
        if (++index == [token valence]) {
            NSLog(@"*** SVGParse Error: Invalid parameter count in M style token");
            return;
        }
        CGFloat y = [token parameter:index] + ([token command] == 'm' ? lastPoint.y : 0);
        lastPoint = CGPointMake(x, y);
        if (first) {
            [bezier moveToPoint:[self convertPoint]];
            first = NO;
        }
        else {
            [bezier addLineToPoint:[self convertPoint]];
        }
        index++;
    }
}

- (void)appendSVGLCommand:(Token *)token
{
    validLastControlPoint = NO;
    NSInteger index = 0;
    while (index < [token valence]) {
        CGFloat x = 0;
        CGFloat y = 0;
        switch ( [token command] ) {
            case 'l':
                x = lastPoint.x;
                y = lastPoint.y;
            case 'L':
                x += [token parameter:index];
                if (++index == [token valence]) {
                    NSLog(@"*** SVGParse Error: Invalid parameter count in L style token");
                    return;
                }
                y += [token parameter:index];
                break;
            case 'h' :
                x = lastPoint.x;
            case 'H' :
                x += [token parameter:index];
                y = lastPoint.y;
                break;
            case 'v' :
                y = lastPoint.y;
            case 'V' :
                y += [token parameter:index];
                x = lastPoint.x;
                break;
            default:
                NSLog(@"*** SVGParse Error: Unrecognised L style command.");
                return;
        }
        lastPoint = CGPointMake(x, y);
        [bezier addLineToPoint:[self convertPoint]];
        index++;
    }
}

- (void)appendSVGCCommand:(Token *)token
{
    NSInteger index = 0;
    while ((index + 5) < [token valence]) {  // we must have 6 floats here (x1, y1, x2, y2, x, y).
        CGFloat x1 = [token parameter:index++] + ([token command] == 'c' ? lastPoint.x : 0);
        CGFloat y1 = [token parameter:index++] + ([token command] == 'c' ? lastPoint.y : 0);
        CGFloat x2 = [token parameter:index++] + ([token command] == 'c' ? lastPoint.x : 0);
        CGFloat y2 = [token parameter:index++] + ([token command] == 'c' ? lastPoint.y : 0);
        CGFloat x  = [token parameter:index++] + ([token command] == 'c' ? lastPoint.x : 0);
        CGFloat y  = [token parameter:index++] + ([token command] == 'c' ? lastPoint.y : 0);
        lastPoint = CGPointMake(x, y);
        [bezier addCurveToPoint:[self convertPoint]
                  controlPoint1:CGPointMake(x1/KScale, y1/KScale)
                  controlPoint2:CGPointMake(x2/KScale, y2/KScale)];
        lastControlPoint = CGPointMake(x2, y2);
        validLastControlPoint = YES;
    }
    if (index == 0) {
        NSLog(@"*** SVGParse Error: Insufficient parameters for C command");
    }
}

- (void)appendSVGSCommand:(Token *)token
{
    if (!validLastControlPoint) {
        NSLog(@"*** SVGParse Error: Invalid last control point in S command");
    }
    NSInteger index = 0;
    while ((index + 3) < [token valence]) {  // we must have 4 floats here (x2, y2, x, y).
        CGFloat x1 = lastPoint.x + (lastPoint.x - lastControlPoint.x); // + ([token command] == 's' ? lastPoint.x : 0);
        CGFloat y1 = lastPoint.y + (lastPoint.y - lastControlPoint.y); // + ([token command] == 's' ? lastPoint.y : 0);
        CGFloat x2 = [token parameter:index++] + ([token command] == 's' ? lastPoint.x : 0);
        CGFloat y2 = [token parameter:index++] + ([token command] == 's' ? lastPoint.y : 0);
        CGFloat x  = [token parameter:index++] + ([token command] == 's' ? lastPoint.x : 0);
        CGFloat y  = [token parameter:index++] + ([token command] == 's' ? lastPoint.y : 0);
        lastPoint = CGPointMake(x, y);
        [bezier addCurveToPoint:[self convertPoint]
                  controlPoint1:CGPointMake(x1/KScale, y1/KScale)
                  controlPoint2:CGPointMake(x2/KScale, y2/KScale)];
        lastControlPoint = CGPointMake(x2, y2);
        validLastControlPoint = YES;
    }
    if (index == 0) {
        NSLog(@"*** SVGParse Error: Insufficient parameters for S command");
    }
}

@end

@implementation UIView (Addition)


- (void)removeAllSublayer {
    while (self.layer.sublayers.count) {
        CALayer *child = self.layer.sublayers.lastObject;
        [child removeFromSuperlayer];
    }
}
- (void)removeAllSubview {
    while (self.subviews.count) {
        UIView *child = self.subviews.lastObject;
        [child removeFromSuperview];
    }
}

@end
