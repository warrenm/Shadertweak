
#import "STWSceneView.h"
#import "STWUniforms.h"
#import "STWSnapshotter.h"

@interface STWTouch : NSObject
@property (nonatomic, assign) CGPoint point;
@property (nonatomic, assign) CGFloat force;

- (instancetype)initWithPoint:(CGPoint)point force:(CGFloat)force;
@end

@implementation STWTouch

- (instancetype)initWithPoint:(CGPoint)point force:(CGFloat)force {
    if ((self = [super init])) {
        _point = point;
        _force = force;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"STWPoint %@", NSStringFromCGPoint(self.point)];
}

@end


@interface STWSceneView ()
@property (nonatomic, strong) id<MTLRenderPipelineState> renderPipelineState;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@property (nonatomic, assign) NSTimeInterval startTime;
@property (nonatomic, copy) NSMutableArray *touches;
@property (nonatomic, copy) NSMutableArray *textures;
@end

@implementation STWSceneView

- (instancetype)initWithFrame:(CGRect)frameRect context:(STWMetalContext *)metalContext {
    if ((self = [super initWithFrame:frameRect device:metalContext.device])) {
        _metalContext = [STWMetalContext defaultContext];
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) {
        _metalContext = [STWMetalContext defaultContext];
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    _touches = [NSMutableArray array];
    _textures = [NSMutableArray array];

    self.device = _metalContext.device;

    self.multipleTouchEnabled = YES;

    // Setting these two properties prevents the view from redrawing periodically and
    // makes it responsive to the usual setNeedsDisplay message sequence
//    self.paused = YES;
//    self.enableSetNeedsDisplay = YES;

    self.startTime = CACurrentMediaTime();

    [self makeVertexBuffer];
    [self makeDefaultTextures];
}

- (void)makeVertexBuffer {
    // Vertex list for a full-screen quad described as a triangle strip.
    // Each vertex has two clip-space coordinates, followed by two texture coordinates.
    float vertices[] = {
        -1, -1, 0, 1,    // lower left
        -1,  1, 0, 0,    // upper left
         1, -1, 1, 1,    // lower right
         1,  1, 1, 0,    // upper right
    };

    _vertexBuffer = [_metalContext.device newBufferWithBytes:&vertices[0]
                                                      length:sizeof(vertices)
                                                     options:MTLResourceOptionCPUCacheModeDefault];
}

- (void)makeDefaultTextures {
    for (int i = 0; i < 4; ++i) {
        self.textures[i] = [NSNull null];
    }

//    MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
//                                                                                          width:32
//                                                                                         height:32
//                                                                                      mipmapped:NO];
//    self.textures[0] = [self.metalContext.device newTextureWithDescriptor:descriptor];

    MTKTextureLoader *textureLoader = [[MTKTextureLoader alloc] initWithDevice:self.metalContext.device];

    NSError *error = nil;
    NSURL *noiseTextureURL = [[NSBundle mainBundle] URLForResource:@"noise" withExtension:@"png"];
    NSData *noiseTextureData = [NSData dataWithContentsOfURL:noiseTextureURL options:0 error:&error];
    id<MTLTexture> noiseTexture = [textureLoader newTextureWithData:noiseTextureData options:@{} error:&error];
    if (!noiseTexture) {
        NSLog(@"Couldn't load default noise texture");
    } else {
        self.textures[0] = noiseTexture;
    }
}

- (void)makeRenderPipelineState {
    if (!_library) {
        NSLog(@"Library not valid; skipping render pipeline state creation");
        self.renderPipelineState = nil;
        return;
    }
    MTLVertexDescriptor *vertexDescriptor = [MTLVertexDescriptor vertexDescriptor];
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat2; // position
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[0].bufferIndex = 0;
    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat2; // texCoords
    vertexDescriptor.attributes[1].offset = 2 * sizeof(float);
    vertexDescriptor.attributes[1].bufferIndex = 0;
    vertexDescriptor.layouts[0].stepRate = 1;
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    vertexDescriptor.layouts[0].stride = 4 * sizeof(float);

    id <MTLFunction> vertexFunction = [_library newFunctionWithName:@"vertex_reshape"];
    id <MTLFunction> fragmentFunction = [_library newFunctionWithName:@"fragment_texture"];

    // TODO: Verify that functions are successfully retrieved

    MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
    pipelineDescriptor.vertexFunction = vertexFunction;
    pipelineDescriptor.fragmentFunction = fragmentFunction;
    pipelineDescriptor.vertexDescriptor = vertexDescriptor;
    pipelineDescriptor.colorAttachments[0].pixelFormat = self.colorPixelFormat;

    NSError *error = nil;
    _renderPipelineState = [_metalContext.device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (!_renderPipelineState) {
        NSLog(@"Error occurred when making render pipeline state: %@", [error localizedDescription]);
    }
}

- (void)setLibrary:(id<MTLLibrary>)library {
    _library = library;

    [self makeRenderPipelineState];

    [self setNeedsDisplay];
}

- (void)cacheTouchesForEvent:(UIEvent *)event {
    [self.touches removeAllObjects];
    NSArray *allTouches = event.allTouches.allObjects;
    for (UITouch *uiTouch in allTouches) {
        if (uiTouch.phase == UITouchPhaseCancelled || uiTouch.phase == UITouchPhaseEnded) {
            continue;
        }
        CGPoint location = [uiTouch locationInView:self];
        STWTouch *touch = [[STWTouch alloc] initWithPoint:location force:uiTouch.force];
        [self.touches addObject:touch];
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self cacheTouchesForEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self cacheTouchesForEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self cacheTouchesForEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self cacheTouchesForEvent:event];
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];

    if (self.renderPipelineState == nil) {
        NSLog(@"INFO: No render pipeline state; skipping draw. This isn't fatal, it just makes life temporarily less exciting");
        return;
    }

    STWUniforms uniforms;
    uniforms.time = CACurrentMediaTime() - self.startTime;
    uniforms.deltaTime = 1 / 60.0f;
    uniforms.resolution = (packed_float2) { self.drawableSize.width, self.drawableSize.height };

    for (int i = 0; i < STWMaxConcurrentTouches; ++i) {
        if (i < self.touches.count) {
            STWTouch *touch = self.touches[i];
            uniforms.touch[i] = (vector_float4){ touch.point.x, touch.point.y, touch.force, 1 };
        } else {
            uniforms.touch[i] = (vector_float4){ 0, 0, 0, 0 };
        }
    }

    id<MTLDrawable> drawable = self.currentDrawable;
    MTLRenderPassDescriptor *passDescriptor = self.currentRenderPassDescriptor;

    if (drawable != nil && passDescriptor != nil) {

        passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.2, 0.2, 0.2, 1.0);
        id<MTLCommandBuffer> commandBuffer = [self.metalContext.commandQueue commandBuffer];

        id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
        [commandEncoder setRenderPipelineState:self.renderPipelineState];
        [commandEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
        for (int i = 0; i < self.textures.count; ++i) {
            if ([self.textures[i] conformsToProtocol:@protocol(MTLTexture)]) {
                [commandEncoder setFragmentTexture:self.textures[i] atIndex:i];
            }
        }
        [commandEncoder setFragmentBytes:&uniforms length:sizeof(STWUniforms) atIndex:0];
        [commandEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
        [commandEncoder endEncoding];

        [commandBuffer presentDrawable:drawable];

        [commandBuffer commit];
    }
}

- (UIImage *)captureSnapshotAtSize:(CGSize)imageSize {
    return [STWSnapshotter captureSnapshotOfSize:imageSize renderPipelineState:self.renderPipelineState textures:self.textures];
}

@end
