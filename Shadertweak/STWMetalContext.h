
@import Metal;

@interface STWMetalContext : NSObject

+ (instancetype)defaultContext;
- (instancetype)initWithDevice:(id<MTLDevice>)device;

@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;

@end
