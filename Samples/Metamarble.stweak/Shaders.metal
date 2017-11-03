constant const float kMinDist = 0;
constant const float kMaxDist = 50;
constant const float kTiny = 0.001;
constant const int kMaxMarchingSteps = 200;

float fSphere(float r, float3 pos)
{
    return length(pos) - r;
}

static void pR(thread float2 &p, float a) {
    p = cos(a)*p + sin(a)*float2(p.y, -p.x);
}

// Shortcut for 45-degrees rotation
static void pR45(thread float2 &p) {
    p = (p + float2(p.y, -p.x))*sqrt(0.5);
}

static float sceneSDF(float3 pos, float t) {
    float r = 1.4 * abs(cos(t)) + 0.3;
    float s = 4.5;
    float s1 = fSphere(r, pos + s*float3( -0.30,  0.2*cos(1.4*t), -0.25));
    float s2 = fSphere(r, pos + s*float3(     0,  0.23*cos(t),  0.25));
    float s3 = fSphere(r, pos + s*float3(  0.25, 0.19*cos(0.7*t), -0.33));
    float s4 = fSphere(r, pos + s*float3(  0.60,    0,  0.25));
    float s5 = fSphere(r, pos + s*float3( -0.70,  0.7, -0.50));
    float s6 = fSphere(r, pos + s*float3( -0.25,  0.7,  0.25));
    float s7 = fSphere(r, pos + s*float3(  0.60, -0.7,  0.50));
    float s8 = fSphere(r, pos + s*float3( -0.33, -0.7, -0.25));
    float s9 = fSphere(r, pos + s*float3( -0.75, -0.7,  0.50));
    float k = 2.8;
    return -log(exp(-k*s1) + exp(-k*s2) + exp(-k*s3) +
                exp(-k*s4) + exp(-k*s5) + exp(-k*s6) +
                exp(-k*s7) + exp(-k*s8) + exp(-k*s9)) / k;
}

float3 estimatedNormal(float3 pos, float time) {
    return normalize(float3(
         sceneSDF(float3(pos.x + kTiny, pos.y, pos.z), time) - sceneSDF(float3(pos.x - kTiny, pos.y, pos.z), time),
         sceneSDF(float3(pos.x, pos.y + kTiny, pos.z), time) - sceneSDF(float3(pos.x, pos.y - kTiny, pos.z), time),
         sceneSDF(float3(pos.x, pos.y, pos.z + kTiny), time) - sceneSDF(float3(pos.x, pos.y, pos.z - kTiny), time)));
}

float raymarch(float3 rayOrigin, float3 rayDir, float min, float max, float time) {
    float param = min;
    for (int i = 0; i < kMaxMarchingSteps; ++i) {
        float dist = sceneSDF(rayOrigin + param * rayDir, time);
        if (dist < kTiny) {
            return param;
        }
        param += dist;
        if (param >= max) {
            return max;
        }
    }
    return max;
}

float3 brdf(float3 pos, float3 norm, float3 eye) {
    float ambient = 0.2;
    float specPow = 120;
    float3 specColor(0.8, 0.8, 0.8);
    float gray = 0.1 + 0.85*smoothstep(0.45, 0.55, fmod(abs(pos.y * 2), 1));
    if (gray < 0.5) specPow = 500;
    float3 surfColor(gray);

    float3 light1Color(0.6, 0.6, 0.5);
    float3 light1Dir = normalize(float3(-2, -2, -1));
    float3 halfway = normalize(-light1Dir + normalize(eye - pos));
    float intens1 = saturate(dot(-light1Dir, norm));
    float hdotn = saturate(dot(halfway, norm));
    float specIntens1 = powr(hdotn, specPow);

    float3 light2Color(0.5, 0.5, 0.6);
    float3 light2Dir = normalize(float3(2, -2, -1));

    halfway = normalize(-light2Dir + normalize(eye - pos));
    float intens2 = saturate(dot(-light2Dir, norm));
    hdotn = saturate(dot(halfway, norm));
    float specIntens2 = powr(hdotn, specPow);

    return intens1 * light1Color * surfColor + 
           specIntens1 * specColor + 
           intens2 * light2Color * surfColor + 
           specIntens2 * specColor + 
           ambient * surfColor;
}

static float4x4 rotateY(float theta) {
    float c = cos(theta);
    float s = sin(theta);

    return float4x4(
        float4(c, 0, s, 0),
        float4(0, 1, 0, 0),
        float4(-s, 0, c, 0),
        float4(0, 0, 0, 1));
}

static float4x4 viewMatrix(float3 eye, float3 center, float3 up) {
    auto f = normalize(center - eye);
    auto s = cross(f, up);
    auto u = cross(s, f);
    return float4x4(
        float4(s, 0.0),
        float4(u, 0.0),
        float4(-f, 0.0),
        float4(0.0, 0.0, 0.0, 1)
    );
}

float radians(float deg) { return deg * (3.14159 / 180); }

float3 rayDirection(float fov, float2 dims, float2 coords) {
    float2 uv = coords - 0.5 * dims;
    float z = dims.y / tan(radians(fov) * 0.5);
    return normalize(float3(uv.x, -uv.y, -z));
}

fragment half4 fragment_texture(ProjectedVertex in [[stage_in]],
                                constant Uniforms &uniforms [[buffer(0)]])
{
    float rad = 3 * sin(2 * iGlobalTime * 0) + 10;
    //float3 eye(rad * cos(iGlobalTime), 0, rad * sin(iGlobalTime));
    float3 eye(5, 8, -32);
	 float3 at(0, 0, 0);
    float3 up(0, 1, 0);

    float3 dir = rayDirection(45.0, iResolution.xy, in.position.xy);
    dir = (viewMatrix(eye, at, up) * float4(dir, 1)).xyz;
    float dist = raymarch(eye, dir, kMinDist, kMaxDist, iGlobalTime);
    if (dist > kMaxDist - kTiny) {
        return half4(0.98, 0.9, 0.9, 1);
    }
    float3 intersect = eye + dist * dir;
    float3 normal = estimatedNormal(eye + dist * dir, iGlobalTime);
    float3 color = brdf(intersect, normal, eye);
    return half4(half3(color), 1);
}
