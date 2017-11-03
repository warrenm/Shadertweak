static float f(float2 uv, float time)
{
	float dist = length(uv);

	const float pi = 3.14159;
	const float ringIndexMultiplier = 6.0;
	float ang = atan2(uv.y, uv.x) / pi + 1.0;
	float ringIndex = ceil(dist * ringIndexMultiplier);
	float direction = (fmod(ringIndex, 2.0) * 2.0 - 1.0);
	float v = fmod(floor(ang * 20.0 + pow(ringIndex, 1.1) + time * direction), 2.0);
    
    //uv = vec2(pow(abs(uv.x), 1.1), pow(abs(uv.y), 1.1));
	uv = abs(uv);
	float2 dotUV = fract((uv + time * 0.05) * 15.0) - 0.5;
	float dotRadius = 0.25 + 0.1 * sin(time * 0.5 + v * pi * 0.6);
	float dotValue = smoothstep(0.03, 0.05, length(dotUV) - dotRadius);
    
    v = mix(1.0 - dotValue, dotValue, v);
    v *= smoothstep(0.9, 1.0, dist * ringIndexMultiplier);
    v += 1.0 - smoothstep(0.2, 0.21, abs(1.0 - fract(dist * ringIndexMultiplier)));
    return v;
}

fragment half4 fragment_texture(ProjectedVertex in [[stage_in]],
                                constant Uniforms &uniforms [[buffer(0)]])
{
   float aspect = iResolution.x / iResolution.y;
	float2 uv = in.texCoords.xy * 2 - float2(1);
	uv.x *= aspect;

   float a = 27;

	float r = f(uv, iGlobalTime);
	float g = f(uv, iGlobalTime + 0.01 * a);
	float b = f(uv, iGlobalTime - 0.01 * a);

	return half4(r, g, b, 1.0);
}
