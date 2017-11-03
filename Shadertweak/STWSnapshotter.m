#import "STWSnapshotter.h"
#import "STWMetalContext.h"
#import "STWUniforms.h"

@implementation STWSnapshotter

+ (UIImage *)captureSnapshotOfSize:(CGSize)size
               renderPipelineState:(id<MTLRenderPipelineState>)renderPipelineState
                          textures:(NSArray *)textures
{
    if (renderPipelineState == nil) {
        NSLog(@"WARN: No render pipeline state; skipping snapshot");
        return nil;
    }

    STWMetalContext *metalContext = [STWMetalContext defaultContext];

    float vertices[] = {
        -1, -1, 0, 1, 
        -1,  1, 0, 0, 
         1, -1, 1, 1,
         1,  1, 1, 0,
    };

    STWUniforms uniforms;
    uniforms.time = 15.0;  // TODO: Parameterize capture time?
    uniforms.deltaTime = 1 / 60.0f;
    uniforms.resolution = (packed_float2) { size.width, size.height };

    MTLTextureDescriptor *textureDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                           width:size.width
                                                                                          height:size.height
                                                                                       mipmapped:NO];
    id<MTLTexture> texture = [metalContext.device newTextureWithDescriptor:textureDesc];

    MTLRenderPassDescriptor *passDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    passDescriptor.colorAttachments[0].texture = texture;
    passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.2, 0.2, 0.2, 1.0);

    id<MTLCommandBuffer> commandBuffer = [metalContext.commandQueue commandBuffer];

    id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
    [commandEncoder setRenderPipelineState:renderPipelineState];
    [commandEncoder setVertexBytes:vertices length:sizeof(vertices) atIndex:0];
    for (int i = 0; i < textures.count; ++i) {
        if ([textures[i] conformsToProtocol:@protocol(MTLTexture)]) {
            [commandEncoder setFragmentTexture:textures[i] atIndex:i];
        }
    }
    [commandEncoder setFragmentBytes:&uniforms length:sizeof(STWUniforms) atIndex:0];
    [commandEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    [commandEncoder endEncoding];

    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];

    return [self imageForTexture:texture size:size];
}

+ (UIImage *)imageForTexture:(id<MTLTexture>)texture size:(CGSize)imageSize {
    NSUInteger width = [texture width];
    NSUInteger height = [texture height];
    NSUInteger bytesPerRow = width * sizeof(uint8_t) * 4;
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL,
                                                 width,
                                                 height,
                                                 8,
                                                 bytesPerRow,
                                                 rgbColorSpace,
                                                 kCGImageAlphaNoneSkipLast);
    [texture getBytes:CGBitmapContextGetData(context)
          bytesPerRow:bytesPerRow
           fromRegion:MTLRegionMake2D(0, 0, width, height)
          mipmapLevel:0];
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGContextRelease(context);
    CGColorSpaceRelease(rgbColorSpace);
    return image;
}

@end
