
#import "STWMetalContext.h"

@implementation STWMetalContext

+ (instancetype)defaultContext {
    static dispatch_once_t onceToken;
    static STWMetalContext *instance = nil;
    dispatch_once(&onceToken, ^{
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        instance = [[STWMetalContext alloc] initWithDevice:device];
    });

    return instance;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device {
    if ((self = [super init])) {
        _device = device;
        _commandQueue = [_device newCommandQueue];
    }

    return self;
}

@end
