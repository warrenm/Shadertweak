constexpr sampler sampler2d(coord::normalized, filter::linear, address::repeat);

fragment half4 fragment_texture(
    ProjectedVertex in [[stage_in]],
    constant Uniforms &uniforms [[buffer(0)]],
    texture2d<float, access::sample> texture0 [[texture(0)]],
    texture2d<float, access::sample> texture1 [[texture(1)]],
    texture2d<float, access::sample> texture2 [[texture(2)]],
    texture2d<float, access::sample> texture3 [[texture(3)]])
{
    float2 tc = in.texCoords;
    tc *= 0.035;
    tc.x = tc.x * (iResolution.x / iResolution.y);
    
    tc.x = tc.x + tc.y * sin(iGlobalTime) * 0.3;
    tc.y = tc.y + tc.x * sin(iGlobalTime) * 0.5;
    
    float2 dt = float2(1) / iResolution;
    dt = dt * 0.6;
    float color0 = texture0.sample(sampler2d, 
                                   tc + float2(dt.x, dt.y)).r;
    float color1 = texture0.sample(sampler2d, 
                                   tc + float2(-dt.x, dt.y)).r;
    float color2 = texture0.sample(sampler2d, 
                                   tc + float2(dt.x, -dt.y)).r;
    float color3 = texture0.sample(sampler2d, 
                                   tc + float2(-dt.x, -dt.y)).r;
    
    float sum = color0 + color1 + color2 + color3;
    float avg = sum / 4;
    
    float thr = smoothstep(0, 1, 8 * (avg - 0.3));
    
    float3 back = float3(0, 35, 150) / 255;
    float3 fore = float3(202, 0, 93) / 255;
    
    return half4(half3(mix(back, fore, thr)), 1);
}
