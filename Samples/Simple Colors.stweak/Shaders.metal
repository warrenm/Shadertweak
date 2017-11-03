
fragment half4 fragment_texture(ProjectedVertex in [[stage_in]],
                                constant Uniforms &uniforms [[buffer(0)]],
                                texture2d<float, access::sample> texture0 [[texture(0)]])
{
    return half4(half2(in.texCoords), 0.5 * sin(iGlobalTime) + 0.5, 1);
}
