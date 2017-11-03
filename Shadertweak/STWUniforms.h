
@import simd;

static const NSInteger STWMaxConcurrentTouches = 10;

typedef struct  {
    vector_float2 resolution;
    float time;
    float deltaTime;
    int frameIndex;
    vector_float4 touch[STWMaxConcurrentTouches];
} STWUniforms;

