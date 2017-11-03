////////////////////////////////////////////////////////////////
//
//                           HG_SDF
//
//     GLSL LIBRARY FOR BUILDING SIGNED DISTANCE BOUNDS
//
//     version 2016-01-10
//     Metal version 2016-09-05 (modifications by @warrenm)
//
//     Check http://mercury.sexy/hg_sdf for updates
//     and usage examples. Send feedback to spheretracing@mercury.sexy.
//
//     Brought to you by MERCURY http://mercury.sexy
//
//
//
// Released as Creative Commons Attribution-NonCommercial (CC BY-NC)
//
////////////////////////////////////////////////////////////////
//
// How to use this:
//
// 1. Build some system to #include glsl files in each other.
//   Include this one at the very start. Or just paste everywhere.
// 2. Build a sphere tracer. See those papers:
//   * "Sphere Tracing" http://graphics.cs.illinois.edu/sites/default/files/zeno.pdf
//   * "Enhanced Sphere Tracing" http://lgdv.cs.fau.de/get/2234
//   The Raymnarching Toolbox Thread on pouet can be helpful as well
//   http://www.pouet.net/topic.php?which=7931&page=1
//   and contains links to many more resources.
// 3. Use the tools in this library to build your distance bound f().
// 4. ???
// 5. Win a compo.
//
// (6. Buy us a beer or a good vodka or something, if you like.)
//
////////////////////////////////////////////////////////////////
//
// Table of Contents:
//
// * Helper functions and macros
// * Collection of some primitive objects
// * Domain Manipulation operators
// * Object combination operators
//
////////////////////////////////////////////////////////////////
//
// Why use this?
//
// The point of this lib is that everything is structured according
// to patterns that we ended up using when building geometry.
// It makes it more easy to write code that is reusable and that somebody
// else can actually understand. Especially code on Shadertoy (which seems
// to be what everybody else is looking at for "inspiration") tends to be
// really ugly. So we were forced to do something about the situation and
// release this lib ;)
//
// Everything in here can probably be done in some better way.
// Please experiment. We'd love some feedback, especially if you
// use it in a scene production.
//
// The main patterns for building geometry this way are:
// * Stay Lipschitz continuous. That means: don't have any distance
//   gradient larger than 1. Try to be as close to 1 as possible -
//   Distances are euclidean distances, don't fudge around.
//   Underestimating distances will happen. That's why calling
//   it a "distance bound" is more correct. Don't ever multiply
//   distances by some value to "fix" a Lipschitz continuity
//   violation. The invariant is: each fSomething() function returns
//   a correct distance bound.
// * Use very few primitives and combine them as building blocks
//   using combine opertors that preserve the invariant.
// * Multiply objects by repeating the domain (space).
//   If you are using a loop inside your distance function, you are
//   probably doing it wrong (or you are building boring fractals).
// * At right-angle intersections between objects, build a new local
//   coordinate system from the two distances to combine them in
//   interesting ways.
// * As usual, there are always times when it is best to not follow
//   specific patterns.
//
////////////////////////////////////////////////////////////////
//
// FAQ
//
// Q: Why is there no sphere tracing code in this lib?
// A: Because our system is way too complex and always changing.
//    This is the constant part. Also we'd like everyone to
//    explore for themselves.
//
// Q: This does not work when I paste it into Shadertoy!!!!
// A: Yes. It is GLSL, not GLSL ES. We like real OpenGL
//    because it has way more features and is more likely
//    to work compared to browser-based WebGL. We recommend
//    you consider using OpenGL for your productions. Most
//    of this can be ported easily though.
//
// Q: How do I material?
// A: We recommend something like this:
//    Write a material ID, the distance and the local coordinate
//    p into some global variables whenever an object's distance is
//    smaller than the stored distance. Then, at the end, evaluate
//    the material to get color, roughness, etc., and do the shading.
//
// Q: I found an error. Or I made some function that would fit in
//    in this lib. Or I have some suggestion.
// A: Awesome! Drop us a mail at spheretracing@mercury.sexy.
//
// Q: Why is this not on github?
// A: Because we were too lazy. If we get bugged about it enough,
//    we'll do it.
//
// Q: Your license sucks for me.
// A: Oh. What should we change it to?
//
// Q: I have trouble understanding what is going on with my distances.
// A: Some visualization of the distance field helps. Try drawing a
//    plane that you can sweep through your scene with some color
//    representation of the distance field at each point and/or iso
//    lines at regular intervals. Visualizing the length of the
//    gradient (or better: how much it deviates from being equal to 1)
//    is immensely helpful for understanding which parts of the
//    distance field are broken.
//
////////////////////////////////////////////////////////////////


#include <metal_stdlib>

namespace hg_sdf {

using namespace metal;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-function"

////////////////////////////////////////////////////////////////
//
//             HELPER FUNCTIONS/MACROS
//
////////////////////////////////////////////////////////////////

#define PI 3.14159265
#define TAU (2*PI)
#define PHI (sqrt(5.0f)*0.5 + 0.5)

// Clamp to [0,1] - this operation is free under certain circumstances.
// For further information see
// http://www.humus.name/Articles/Persson_LowLevelThinking.pdf and
// http://www.humus.name/Articles/Persson_LowlevelShaderOptimization.pdf
// #define saturate(x) saturate_is_a_metal_intrinsic

// Sign function that doesn't return 0
static float sign(float x) {
    return (x<0)?-1:1;
}

static float2 sign(float2 v) {
    return float2((v.x<0)?-1:1, (v.y<0)?-1:1);
}

static float square (float x) {
    return x*x;
}

static float2 square (float2 x) {
    return x*x;
}

static float3 square (float3 x) {
    return x*x;
}

static float lengthSqr(float3 x) {
    return dot(x, x);
}


// Maximum/minumum elements of a vector
static float vmax(float2 v) {
    return max(v.x, v.y);
}

static float vmax(float3 v) {
    return max(max(v.x, v.y), v.z);
}

static float vmax(float4 v) {
    return max(max(v.x, v.y), max(v.z, v.w));
}

static float vmin(float2 v) {
    return min(v.x, v.y);
}

static float vmin(float3 v) {
    return min(min(v.x, v.y), v.z);
}

static float vmin(float4 v) {
    return min(min(v.x, v.y), min(v.z, v.w));
}




////////////////////////////////////////////////////////////////
//
//             PRIMITIVE DISTANCE FUNCTIONS
//
////////////////////////////////////////////////////////////////
//
// Conventions:
//
// Everything that is a distance function is called fSomething.
// The first argument is always a point in 2 or 3-space called <p>.
// Unless otherwise noted, (if the object has an intrinsic "up"
// side or direction) the y axis is "up" and the object is
// centered at the origin.
//
////////////////////////////////////////////////////////////////

static float fSphere(float3 p, float r) {
    return length(p) - r;
}

// Plane with normal n (n is normalized) at some distance from the origin
static float fPlane(float3 p, float3 n, float distanceFromOrigin) {
    return dot(p, n) + distanceFromOrigin;
}

// Cheap Box: distance to corners is overestimated
static float fBoxCheap(float3 p, float3 b) { //cheap box
    return vmax(abs(p) - b);
}

// Box: correct distance to corners
static float fBox(float3 p, float3 b) {
    float3 d = abs(p) - b;
    return length(max(d, float3(0))) + vmax(min(d, float3(0)));
}

// Same as above, but in two dimensions (an endless box)
static float fBox2Cheap(float2 p, float2 b) {
    return vmax(abs(p)-b);
}

static float fBox2(float2 p, float2 b) {
    float2 d = abs(p) - b;
    return length(max(d, float2(0))) + vmax(min(d, float2(0)));
}


// Endless "corner"
static float fCorner (float2 p) {
    return length(max(p, float2(0))) + vmax(min(p, float2(0)));
}

// Blobby ball object. You've probably seen it somewhere. This is not a correct distance bound, beware.
static float fBlob(float3 p) {
    p = abs(p);
    if (p.x < max(p.y, p.z)) p = p.yzx;
    if (p.x < max(p.y, p.z)) p = p.yzx;
    float b = max(max(max(
                          dot(p, normalize(float3(1, 1, 1))),
                          dot(p.xz, normalize(float2(PHI+1, 1)))),
                      dot(p.yx, normalize(float2(1, PHI)))),
                  dot(p.xz, normalize(float2(1, PHI))));
    float l = length(p);
    return l - 1.5 - 0.2 * (1.5 / 2)* cos(min(sqrt(1.01 - b / l)*(PI / 0.25), PI));
}

// Cylinder standing upright on the xz plane
static float fCylinder(float3 p, float r, float height) {
    float d = length(p.xz) - r;
    d = max(d, abs(p.y) - height);
    return d;
}

// Capsule: A Cylinder with round caps on both sides
static float fCapsule(float3 p, float r, float c) {
    return mix(length(p.xz) - r, length(float3(p.x, abs(p.y) - c, p.z)) - r, step(c, abs(p.y)));
}

// Distance to line segment between <a> and <b>, used for fCapsule() version 2below
static float fLineSegment(float3 p, float3 a, float3 b) {
    float3 ab = b - a;
    float t = saturate(dot(p - a, ab) / dot(ab, ab));
    return length((ab*t + a) - p);
}

// Capsule version 2: between two end points <a> and <b> with radius r
static float fCapsule(float3 p, float3 a, float3 b, float r) {
    return fLineSegment(p, a, b) - r;
}

// Torus in the XZ-plane
static float fTorus(float3 p, float smallRadius, float largeRadius) {
    return length(float2(length(p.xz) - largeRadius, p.y)) - smallRadius;
}

// A circle line. Can also be used to make a torus by subtracting the smaller radius of the torus.
static float fCircle(float3 p, float r) {
    float l = length(p.xz) - r;
    return length(float2(p.y, l));
}

// A circular disc with no thickness (i.e. a cylinder with no height).
// Subtract some value to make a flat disc with rounded edge.
static float fDisc(float3 p, float r) {
    float l = length(p.xz) - r;
    return l < 0 ? abs(p.y) : length(float2(p.y, l));
}

// Hexagonal prism, circumcircle variant
static float fHexagonCircumcircle(float3 p, float2 h) {
    float3 q = abs(p);
    return max(q.y - h.y, max(q.x*sqrt(3.0f)*0.5 + q.z*0.5, q.z) - h.x);
    //this is mathematically equivalent to this line, but less efficient:
    //return max(q.y - h.y, max(dot(float2(cos(PI/3), sin(PI/3)), q.zx), q.z) - h.x);
}

// Hexagonal prism, incircle variant
static float fHexagonIncircle(float3 p, float2 h) {
    return fHexagonCircumcircle(p, float2(h.x*sqrt(3.0f)*0.5, h.y));
}

// Cone with correct distances to tip and base circle. Y is up, 0 is in the middle of the base.
static float fCone(float3 p, float radius, float height) {
    float2 q = float2(length(p.xz), p.y);
    float2 tip = q - float2(0, height);
    float2 mantleDir = normalize(float2(height, radius));
    float mantle = dot(tip, mantleDir);
    float d = max(mantle, -q.y);
    float projected = dot(tip, float2(mantleDir.y, -mantleDir.x));

    // distance to tip
    if ((q.y > height) && (projected < 0)) {
        d = max(d, length(tip));
    }

    // distance to base ring
    if ((q.x > radius) && (projected > length(float2(height, radius)))) {
        d = max(d, length(q - float2(radius, 0)));
    }
    return d;
}

//
// "Generalized Distance Functions" by Akleman and Chen.
// see the Paper at https://www.viz.tamu.edu/faculty/ergun/research/implicitmodeling/papers/sm99.pdf
//
// This set of constants is used to construct a large variety of geometric primitives.
// Indices are shifted by 1 compared to the paper because we start counting at Zero.
// Some of those are slow whenever a driver decides to not unroll the loop,
// which seems to happen for fIcosahedron und fTruncatedIcosahedron on nvidia 350.12 at least.
// Specialized implementations can well be faster in all cases.
//

constant const float3 GDFVectors[19] = {
    normalize(float3(1, 0, 0)),
    normalize(float3(0, 1, 0)),
    normalize(float3(0, 0, 1)),

    normalize(float3(1, 1, 1 )),
    normalize(float3(-1, 1, 1)),
    normalize(float3(1, -1, 1)),
    normalize(float3(1, 1, -1)),

    normalize(float3(0, 1, PHI+1)),
    normalize(float3(0, -1, PHI+1)),
    normalize(float3(PHI+1, 0, 1)),
    normalize(float3(-PHI-1, 0, 1)),
    normalize(float3(1, PHI+1, 0)),
    normalize(float3(-1, PHI+1, 0)),

    normalize(float3(0, PHI, 1)),
    normalize(float3(0, -PHI, 1)),
    normalize(float3(1, 0, PHI)),
    normalize(float3(-1, 0, PHI)),
    normalize(float3(PHI, 1, 0)),
    normalize(float3(-PHI, 1, 0))
};

// Version with variable exponent.
// This is slow and does not produce correct distances, but allows for bulging of objects.
static float fGDF(float3 p, float r, float e, int begin, int end) {
    float d = 0;
    for (int i = begin; i <= end; ++i)
        d += pow(abs(dot(p, GDFVectors[i])), e);
    return pow(d, 1/e) - r;
}

// Version with without exponent, creates objects with sharp edges and flat faces
static float fGDF(float3 p, float r, int begin, int end) {
    float d = 0;
    for (int i = begin; i <= end; ++i)
        d = max(d, abs(dot(p, GDFVectors[i])));
    return d - r;
}

// Primitives follow:

static float fOctahedron(float3 p, float r, float e) {
    return fGDF(p, r, e, 3, 6);
}

static float fDodecahedron(float3 p, float r, float e) {
    return fGDF(p, r, e, 13, 18);
}

static float fIcosahedron(float3 p, float r, float e) {
    return fGDF(p, r, e, 3, 12);
}

static float fTruncatedOctahedron(float3 p, float r, float e) {
    return fGDF(p, r, e, 0, 6);
}

static float fTruncatedIcosahedron(float3 p, float r, float e) {
    return fGDF(p, r, e, 3, 18);
}

static float fOctahedron(float3 p, float r) {
    return fGDF(p, r, 3, 6);
}

static float fDodecahedron(float3 p, float r) {
    return fGDF(p, r, 13, 18);
}

static float fIcosahedron(float3 p, float r) {
    return fGDF(p, r, 3, 12);
}

static float fTruncatedOctahedron(float3 p, float r) {
    return fGDF(p, r, 0, 6);
}

static float fTruncatedIcosahedron(float3 p, float r) {
    return fGDF(p, r, 3, 18);
}


////////////////////////////////////////////////////////////////
//
//                DOMAIN MANIPULATION OPERATORS
//
////////////////////////////////////////////////////////////////
//
// Conventions:
//
// Everything that modifies the domain is named pSomething.
//
// Many operate only on a subset of the three dimensions. For those,
// you must choose the dimensions that you want manipulated
// by supplying e.g. <p.x> or <p.zx>
//
// <p> is always the first argument and is modified in place.
//
// Many of the operators partition space into cells. An identifier
// or cell index is returned, if possible. This return value is
// intended to be optionally used e.g. as a random seed to change
// parameters of the distance functions inside the cells.
//
// Unless stated otherwise, for cell index 0, <p> is unchanged and cells
// are centered on the origin so objects don't have to be moved to fit.
//
//
////////////////////////////////////////////////////////////////



// Rotate around a coordinate axis (i.e. in a plane perpendicular to that axis) by angle <a>.
// Read like this: R(p.xz, a) rotates "x towards z".
// This is fast if <a> is a compile-time constant and slower (but still practical) if not.
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

// Same, but mirror every second cell so they match at the boundaries
static float pmodMirror1(thread float &p, float size) {
    float halfsize = size*0.5;
    float c = floor((p + halfsize)/size);
    p = fmod(p + halfsize,size) - halfsize;
    p *= fmod(c, 2.0)*2 - 1;
    return c;
}

// Repeat the domain only in positive direction. Everything in the negative half-space is unchanged.
static float pmodSingle1(thread float &p, float size) {
    float halfsize = size*0.5;
    float c = floor((p + halfsize)/size);
    if (p >= 0)
        p = fmod(p + halfsize, size) - halfsize;
    return c;
}

// Repeat only a few times: from indices <start> to <stop> (similar to above, but more flexible)
static float pmodInterval1(thread float &p, float size, float start, float stop) {
    float halfsize = size*0.5;
    float c = floor((p + halfsize)/size);
    p = fmod(p+halfsize, size) - halfsize;
    if (c > stop) { //yes, this might not be the best thing numerically.
        p += size*(c - stop);
        c = stop;
    }
    if (c <start) {
        p += size*(c - start);
        c = start;
    }
    return c;
}


// Repeat around the origin by a fixed angle.
// For easier use, num of repetitions is use to specify the angle.
static float pmodPolar(thread float2 &p, float repetitions) {
    float angle = 2*PI/repetitions;
    float a = atan2(p.y, p.x) + angle/2.;
    float r = length(p);
    float c = floor(a/angle);
    a = fmod(a,angle) - angle/2.;
    p = float2(cos(a), sin(a))*r;
    // For an odd number of repetitions, fix cell index of the cell in -x direction
    // (cell index would be e.g. -5 and 5 in the two halves of the cell):
    if (abs(c) >= (repetitions/2)) c = abs(c);
    return c;
}

// Repeat in two dimensions
static float2 pmod2(thread float2 &p, float2 size) {
    float2 c = floor((p + size*0.5)/size);
    p = fmod(p + size*0.5,size) - size*0.5;
    return c;
}

// Same, but mirror every second cell so all boundaries match
static float2 pmodMirror2(thread float2 &p, float2 size) {
    float2 halfsize = size*0.5;
    float2 c = floor((p + halfsize)/size);
    p = fmod(p + halfsize, size) - halfsize;
    p *= fmod(c,float2(2))*2 - float2(1);
    return c;
}

// Same, but mirror every second cell at the diagonal as well
static float2 pmodGrid2(thread float2 &p, float2 size) {
    float2 c = floor((p + size*0.5)/size);
    p = fmod(p + size*0.5, size) - size*0.5;
    p *= fmod(c,float2(2))*2 - float2(1);
    p -= size/2;
    if (p.x > p.y) p.xy = p.yx;
    return floor(c/2);
}

// Repeat in three dimensions
static float3 pmod3(thread float3 &p, float3 size) {
    float3 c = floor((p + size*0.5)/size);
    p = fmod(p + size*0.5, size) - size*0.5;
    return c;
}

// Mirror at an axis-aligned plane which is at a specified distance <dist> from the origin.
static float pMirror (thread float &p, float dist) {
    float s = sign(p);
    p = abs(p)-dist;
    return s;
}

// Mirror in both dimensions and at the diagonal, yielding one eighth of the space.
// translate by dist before mirroring.
static float2 pMirrorOctant (thread float2 &p, float2 dist) {
    float2 s = sign(p);
    float px = p.x;
    float py = p.y;
    pMirror(px, dist.x);
    pMirror(py, dist.y);
    p.x = px;
    p.y = py;
    if (p.y > p.x)
        p.xy = p.yx;
    return s;
}

// Reflect space at a plane
static float pReflect(thread float3 &p, float3 planeNormal, float offset) {
    float t = dot(p, planeNormal)+offset;
    if (t < 0) {
        p = p - (2*t)*planeNormal;
    }
    return sign(t);
}


////////////////////////////////////////////////////////////////
//
//             OBJECT COMBINATION OPERATORS
//
////////////////////////////////////////////////////////////////
//
// We usually need the following boolean operators to combine two objects:
// Union: OR(a,b)
// Intersection: AND(a,b)
// Difference: AND(a,!b)
// (a and b being the distances to the objects).
//
// The trivial implementations are min(a,b) for union, max(a,b) for intersection
// and max(a,-b) for difference. To combine objects in more interesting ways to
// produce rounded edges, chamfers, stairs, etc. instead of plain sharp edges we
// can use combination operators. It is common to use some kind of "smooth minimum"
// instead of min(), but we don't like that because it does not preserve Lipschitz
// continuity in many cases.
//
// Naming convention: since they return a distance, they are called fOpSomething.
// The different flavours usually implement all the boolean operators above
// and are called fOpUnionRound, fOpIntersectionRound, etc.
//
// The basic idea: Assume the object surfaces intersect at a right angle. The two
// distances <a> and <b> constitute a new local two-dimensional coordinate system
// with the actual intersection as the origin. In this coordinate system, we can
// evaluate any 2D distance function we want in order to shape the edge.
//
// The operators below are just those that we found useful or interesting and should
// be seen as examples. There are infinitely more possible operators.
//
// They are designed to actually produce correct distances or distance bounds, unlike
// popular "smooth minimum" operators, on the condition that the gradients of the two
// SDFs are at right angles. When they are off by more than 30 degrees or so, the
// Lipschitz condition will no longer hold (i.e. you might get artifacts). The worst
// case is parallel surfaces that are close to each other.
//
// Most have a float argument <r> to specify the radius of the feature they represent.
// This should be much smaller than the object size.
//
// Some of them have checks like "if ((-a < r) && (-b < r))" that restrict
// their influence (and computation cost) to a certain area. You might
// want to lift that restriction or enforce it. We have left it as comments
// in some cases.
//
// usage example:
//
// float fTwoBoxes(float3 p) {
//   float box0 = fBox(p, float3(1));
//   float box1 = fBox(p-float3(1), float3(1));
//   return fOpUnionChamfer(box0, box1, 0.2);
// }
//
////////////////////////////////////////////////////////////////


// The "Chamfer" flavour makes a 45-degree chamfered edge (the diagonal of a square of size <r>):
static float fOpUnionChamfer(float a, float b, float r) {
    return min(min(a, b), (a - r + b)*sqrt(0.5));
}

// Intersection has to deal with what is normally the inside of the resulting object
// when using union, which we normally don't care about too much. Thus, intersection
// implementations sometimes differ from union implementations.
static float fOpIntersectionChamfer(float a, float b, float r) {
    return max(max(a, b), (a + r + b)*sqrt(0.5));
}

// Difference can be built from Intersection or Union:
static float fOpDifferenceChamfer (float a, float b, float r) {
    return fOpIntersectionChamfer(a, -b, r);
}

// The "Round" variant uses a quarter-circle to join the two objects smoothly:
static float fOpUnionRound(float a, float b, float r) {
    float2 u = max(float2(r - a,r - b), float2(0));
    return max(r, min (a, b)) - length(u);
}

static float fOpIntersectionRound(float a, float b, float r) {
    float2 u = max(float2(r + a,r + b), float2(0));
    return min(-r, max (a, b)) + length(u);
}

static float fOpDifferenceRound (float a, float b, float r) {
    return fOpIntersectionRound(a, -b, r);
}


// The "Columns" flavour makes n-1 circular columns at a 45 degree angle:
static float fOpUnionColumns(float a, float b, float r, float n) {
    if ((a < r) && (b < r)) {
        float2 p = float2(a, b);
        float columnradius = r*sqrt(2.0f)/((n-1)*2+sqrt(2.0f));
        pR45(p);
        p.x -= sqrt(2.0f)/2*r;
        p.x += columnradius*sqrt(2.0f);
        if (fmod(n,2) == 1) {
            p.y += columnradius;
        }
        // At this point, we have turned 45 degrees and moved at a point on the
        // diagonal that we want to place the columns on.
        // Now, repeat the domain along this direction and place a circle.
        float py = p.y;
        pmod1(py, columnradius*2);
        p.y = py;
        float result = length(p) - columnradius;
        result = min(result, p.x);
        result = min(result, a);
        return min(result, b);
    } else {
        return min(a, b);
    }
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

// The "Stairs" flavour produces n-1 steps of a staircase:
// much less stupid version by paniq
static float fOpUnionStairs(float a, float b, float r, float n) {
    float s = r/n;
    float u = b-r;
    return min(min(a,b), 0.5 * (u + a + abs ((fmod (u - a + s, 2 * s)) - s)));
}

// We can just call Union since stairs are symmetric.
static float fOpIntersectionStairs(float a, float b, float r, float n) {
    return -fOpUnionStairs(-a, -b, r, n);
}

static float fOpDifferenceStairs(float a, float b, float r, float n) {
    return -fOpUnionStairs(-a, b, r, n);
}


// Similar to fOpUnionRound, but more lipschitz-y at acute angles
// (and less so at 90 degrees). Useful when fudging around too much
// by MediaMolecule, from Alex Evans' siggraph slides
static float fOpUnionSoft(float a, float b, float r) {
    float e = max(r - abs(a - b), 0.0f);
    return min(a, b) - e*e*0.25/r;
}


// produces a cylindical pipe that runs along the intersection.
// No objects remain, only the pipe. This is not a boolean operator.
static float fOpPipe(float a, float b, float r) {
    return length(float2(a, b)) - r;
}

// first object gets a v-shaped engraving where it intersect the second
static float fOpEngrave(float a, float b, float r) {
    return max(a, (a + r - abs(b))*sqrt(0.5));
}

// first object gets a capenter-style groove cut out
static float fOpGroove(float a, float b, float ra, float rb) {
    return max(a, min(a + ra, rb - abs(b)));
}

// first object gets a capenter-style tongue attached
static float fOpTongue(float a, float b, float ra, float rb) {
    return min(a, max(a - ra, abs(b) - rb));
}

#pragma clang diagnostic pop // -Wunused-function

} // namespace hg_sdf

using namespace hg_sdf;
