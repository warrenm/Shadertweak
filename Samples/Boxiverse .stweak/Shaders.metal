static float sphere( float3 p, float radius )
{
    return length( p ) - radius;
}

static float vmax(float3 v) {
    return max(max(v.x, v.y), v.z);
}

static float box(float3 p, float3 b) {
    return vmax(abs(p) - b);
}

static float mod(float x, float y) {
    return x - y * floor(x / y);
}

static float map(float3 p)
{
    p -= float3(2, 2, 4);
    p.x=mod(p.x + 5.0, 10.0) - 5.0;
    p.y=mod(p.y + 5.0, 10.0) - 5.0;
    p.z=mod(p.z + 5.0, 10.0) - 5.0;
    return box( p, float3(3, 3, 1) );
}

static float3 getNormal( float3 p )
{
    float3 e = float3( 0.001, 0.00, 0.00 );

    float deltaX = map( p + e.xyy ) - map( p - e.xyy );
    float deltaY = map( p + e.yxy ) - map( p - e.yxy );
    float deltaZ = map( p + e.yyx ) - map( p - e.yyx );

    return normalize( float3( deltaX, deltaY, deltaZ ) );
}

static float trace( float3 origin, float3 direction, thread float3 &p)
{
    float totalDistanceTraveled = 0.0;

    for( int i=0; i < 500; ++i)
    {
        p = origin + direction * totalDistanceTraveled * .95;

        float distanceFromPointOnRayToClosestObjectInScene = map( p );
        totalDistanceTraveled += distanceFromPointOnRayToClosestObjectInScene;

        if( distanceFromPointOnRayToClosestObjectInScene < 0.0001 )
        {
            break;
        }

        if( totalDistanceTraveled > 10000.0 )
        {
            totalDistanceTraveled = 0.0000;
            break;
        }
    }

    return totalDistanceTraveled;
}

static float3 calculateLighting(float3 pointOnSurface, float3 surfaceNormal, float3 lightPosition, float3 cameraPosition)
{
    float3 fromPointToLight = normalize(lightPosition - pointOnSurface);
    float diffuseStrength = clamp( dot( surfaceNormal, fromPointToLight ), 0.0, 1.0 );

    float3 diffuseColor = diffuseStrength * float3( 1.0, 0.0, 0.0 );
    float3 reflectedLightVector = normalize( reflect( -fromPointToLight, surfaceNormal ) );

    float3 fromPointToCamera = normalize( cameraPosition - pointOnSurface );
    float specularStrength = pow( clamp( dot(reflectedLightVector, fromPointToCamera), 0.0, 1.0 ), 10.0 );

    specularStrength = min( diffuseStrength, specularStrength );
    float3 specularColor = specularStrength * float3( 1.0 );

    float3 finalColor = diffuseColor + specularColor;

    return finalColor;
}

fragment half4 fragment_texture(ProjectedVertex in [[stage_in]],
                       constant Uniforms &uniforms [[buffer(0)]])
{
    float2 uv = in.texCoords.xy * 2.0 - 1.0;

    uv.x *= (iResolution.x / iResolution.y);

    float2 mouse = (iTouches[0].xy / iResolution.xy) + float2(0.7);
    mouse *= 0.2;

    float3 cameraPosition = float3(-mouse.x * 20.0 - 10.0, -mouse.y * 20.0 - 10.0, -5 );

    float3 cameraDirection = normalize( float3( uv.x, uv.y, 1.0) );

    float3 pointOnSurface;
    float distanceToClosestPointInScene = trace( cameraPosition, cameraDirection, pointOnSurface );

    float3 finalColor = float3(0.0);
    if( distanceToClosestPointInScene > 0.0 )
    {
        float3 lightPosition = float3( 0.0, 4.5, -10.0 );
        float3 surfaceNormal = getNormal( pointOnSurface );
        finalColor = calculateLighting( pointOnSurface, surfaceNormal, lightPosition, cameraPosition );
    }

    return half4(float4( finalColor, 1.0));
}
