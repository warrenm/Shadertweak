constexpr sampler sampler2d(coord::normalized, filter::linear, address::repeat);

fragment half4 fragment_texture(ProjectedVertex in [[stage_in]],
                                constant Uniforms &uniforms [[buffer(0)]],
                                texture2d<float, access::sample> texture0 [[texture(0)]])
{
    float4 c = texture0.sample(sampler2d, in.texCoords / 1);
    return half4(c);
}
