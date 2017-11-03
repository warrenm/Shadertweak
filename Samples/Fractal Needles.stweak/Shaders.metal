constant float BASE_ANGLE = 3.5;
constant float ANGLE_DELTA = 0.02;
constant float XOFF = 0.7;

static float2x2 mm2(float a){
	float c = cos(a), s = sin(a);
   float2x2 m;
   m[0].x = c;
   m[0].y = -s;
   m[1].x = s;
   m[1].y = c;
   return m;//float2x2(c,-s,s,c);
}

static float fun(float2 p, float t, float featureSize)
{
	p.x = sin(p.x*1.0+t*1.2)*sin(t+p.x*0.1) * 2;	
   p += float2(sin(p.x * 1.5) * 0.1);
   
   return smoothstep(0.0, featureSize, abs(p.y));
}

fragment half4 fragment_texture(ProjectedVertex in [[stage_in]],
                       constant Uniforms &uniforms [[buffer(0)]])
{
	float aspect = iResolution.x/iResolution.y;
	float featureSize = 120./((iResolution.x*aspect+iResolution.y));

	float2 p = in.texCoords.xy * 6.5 - 2.3;
	p.x *= aspect;
   p.y = abs(p.y);

	float3 col( 0, 0, 0);

	for(float i=0.;i<26.;i++)
	{
		 float3 col2;
       col2  = (sin(float3(3.3,2.5,2.2) + float3(i) * 0.15) * 0.5 + 0.54) * (1 - fun(p, iGlobalTime, featureSize));
		  col = max(col,col2);
		
        p.x -= XOFF;
        p.y -= sin(iGlobalTime*0.11+1.5)*1.5+1.5;
		  p*= mm2(i*ANGLE_DELTA+BASE_ANGLE);
		
        float2 pa = float2(abs(p.x-.9),abs(p.y));
        float2 pb = float2(p.x,abs(p.y));
        
        p = mix(pa,pb,smoothstep(-.07,.07,sin(iGlobalTime*0.24)+.1));
	}

	return half4(half3(col), 1.0);

}
