fragment half4 fragment_texture(ProjectedVertex in [[stage_in]],
                                constant Uniforms &uniforms [[buffer(0)]])
{
    float rad = 50;
    float2 p = in.position.xy * 0.5 + 1;

    float usd = 100;
    for (int i = 0; i < 10; ++i) {
        if (iTouches[i].w) {
            float2 center = iTouches[i].xy;
            float sdf = length(center - p) - rad;
            usd = min(usd, sdf);
        }
    }

    float4 inc(1, 1, 1, 1);
    float4 outc(0, 0, 0, 1);
    float mx = smoothstep(0, 1, usd / 100);
    float4 color = mix(inc, outc, mx);

    return half4(color);
}
