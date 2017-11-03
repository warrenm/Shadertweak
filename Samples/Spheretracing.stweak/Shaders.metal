constant const float kMinDist = 0;
constant const float kMaxDist = 1000;
constant const float kTiny = 0.001;
constant const int kMaxMarchingSteps = 500;

static float vmax(float2 v) {
    return max(v.x, v.y);
}

static float vmax(float3 v) {
    return max(max(v.x, v.y), v.z);
}

static float fBox(float3 p, float3 b) {
    float3 d = abs(p) - b;
    return length(max(d, float3(0))) + vmax(min(d, float3(0)));
}

float fSphere(float r, float3 pos)
{
    return length(pos) - r;
}

float fPlane(float3 norm, float dist, float3 pos) {
    return dot(pos, norm) + dist;
}

static float fCylinder(float3 p, float r, float height) {
    float d = length(p.xy) - r;
    d = max(d, abs(p.z) - height);
    return d;
}

// Capsule: A Cylinder with round caps on both sides
static float fCapsule(float3 p, float r, float c) {
    return mix(length(p.xz) - r, length(float3(p.x, abs(p.y) - c, p.z)) - r, step(c, abs(p.y)));
}

static void pR(thread float2 &p, float a) {
    p = cos(a)*p + sin(a)*float2(p.y, -p.x);
}

// Shortcut for 45-degrees rotation
static void pR45(thread float2 &p) {
    p = (p + float2(p.y, -p.x))*sqrt(0.5);
}

// Repeat space along one axis. Use like this to repeat along the x axis:
// <float cell = pmod1(p.x,5);> - using the return value is optional.
static float pmod1(thread float &p, float size) {
    float halfsize = size*0.5;
    float c = floor((p + halfsize)/size);
    p = fmod(p + halfsize, size) - halfsize;
    return c;
}

static float fOpUnionChamfer(float a, float b, float r) {
    return min(min(a, b), (a - r + b)*sqrt(0.5));
}

static float fOpIntersectionChamfer(float a, float b, float r) {
    return max(max(a, b), (a + r + b)*sqrt(0.5));
}

static float fOpDifferenceColumns(float a, float b, float r, float n) {
    a = -a;
    float m = min(a, b);
    //avoid the expensive computation where not needed (produces discontinuity though)
    if ((a < r) && (b < r)) {
        float2 p = float2(a, b);
        float columnradius = r*sqrt(2.0f)/n/2.0;
        columnradius = r*sqrt(2.0f)/((n-1)*2+sqrt(2.0f));

        pR45(p);
        p.y += columnradius;
        p.x -= sqrt(2.0f)/2*r;
        p.x += -columnradius*sqrt(2.0f)/2;

        if (fmod(n,2) == 1) {
            p.y += columnradius;
        }
        float py = p.y;
        pmod1(py,columnradius*2);
        p.y = py;

        float result = -length(p) + columnradius;
        result = max(result, p.x);
        result = min(result, a);
        return -min(result, b);
    } else {
        return -m;
    }
}

static float fOpIntersectionColumns(float a, float b, float r, float n) {
    return fOpDifferenceColumns(a,-b,r, n);
}


float sceneSDF(float3 pos) {
    float cyl = fCylinder(pos, 0.2, 0.9);

    float box = fBox(pos, float3(1, 1, 1));
    float sphere = fSphere(1.1, pos);
    return fOpIntersectionColumns(-cyl, max(box, sphere), 0.3, 3);
}

float3 estimatedNormal(float3 pos, float time) {
    return normalize(float3(
         sceneSDF(float3(pos.x + kTiny, pos.y, pos.z)) - sceneSDF(float3(pos.x - kTiny, pos.y, pos.z)),
         sceneSDF(float3(pos.x, pos.y + kTiny, pos.z)) - sceneSDF(float3(pos.x, pos.y - kTiny, pos.z)),
         sceneSDF(float3(pos.x, pos.y, pos.z + kTiny)) - sceneSDF(float3(pos.x, pos.y, pos.z - kTiny))));
}

float raymarch(float3 rayOrigin, float3 rayDir, float min, float max, float time) {
    float param = min;
    for (int i = 0; i < kMaxMarchingSteps; ++i) {
        float dist = sceneSDF(rayOrigin + param * rayDir);
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
    float specPow = 100;
    float3 specColor(0.8, 0.8, 1);
    float3 lightDir = normalize(float3(-2, -2, -1));
    float3 halfway = normalize(-lightDir + normalize(eye - pos));
    float3 surfColor = float3(0.15, 0.6, 1);
    float intens = saturate(dot(-lightDir, norm)) + ambient;
    float hdotn = saturate(dot(halfway, norm));
    float specIntens = powr(hdotn, specPow);
    return float3(intens) * surfColor + float3(specIntens) * specColor;
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
    float rad = 3 * sin(2 * iGlobalTime) + 10;
    float3 eye(rad * cos(iGlobalTime), 0, rad * sin(iGlobalTime));
	 float3 at(0, 0, 0);
    float3 up(0, 1, 0);

    float3 dir = rayDirection(45.0, iResolution.xy, in.position.xy);
    dir = (viewMatrix(eye, at, up) * float4(dir, 1)).xyz;
    float dist = raymarch(eye, dir, kMinDist, kMaxDist, iGlobalTime);
    if (dist > kMaxDist - kTiny) {
        return half4(0);
    }
    float3 intersect = eye + dist * dir;
    float3 normal = estimatedNormal(eye + dist * dir, iGlobalTime);
    float3 color = brdf(intersect, normal, eye);
    return half4(half3(color), 1);
}
