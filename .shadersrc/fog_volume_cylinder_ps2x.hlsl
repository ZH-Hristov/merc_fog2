#include "common_fxc.h"
#include "common_ps_fxc.h"

sampler SceneSampler : register(s0);
sampler WPDepthSampler : register(s1);

float4 C0 : register(c0);
float4 C1 : register(c1);
float4 C2 : register(c2);
float4 C3 : register(c3);
float4x4 C11 : register(c11);

#define CameraPos C0.xyz
#define EdgeFade C0.w
#define FogColor C1.xyz
#define FogDensity C1.w
#define CylinderAxis C2.xyz
#define FogStart C2.w
#define CylinderOrigin C3.xyz
#define FogEnd C3.w
#define CylinderStartRadius C11[0][0]
#define CylinderEndRadius C11[1][0]
#define CylinderLength C11[2][0]

struct PS_INPUT
{
    float2 uv : TEXCOORD0;
};

// Transform a point into cylinder local space: Z along axis
void ToCylinderSpace(float3 P, out float3 Plocal, out float3 raylocal,
                     float3 rayOrigin, float3 rayDir)
{
    // Build orthonormal basis: axis = z
    float3 z = CylinderAxis;
    float3 up = abs(z.y) < 0.99 ? float3(0,1,0) : float3(1,0,0);
    float3 x = normalize(cross(up, z));
    float3 y = cross(z, x);

    float3 O = P - CylinderOrigin;

    Plocal = float3(dot(O, x), dot(O, y), dot(O, z));
    raylocal = float3(dot(rayDir, x), dot(rayDir, y), dot(rayDir, z));
}

bool RayIntersectCylinderVolume(float3 rayOrigin, float3 rayDir,
                                out float tEnter, out float tExit)
{
    float3 P0, Rd;
    ToCylinderSpace(rayOrigin, P0, Rd, rayOrigin, rayDir);

    float r0 = CylinderStartRadius;
    float r1 = CylinderEndRadius;
    float L  = CylinderLength;
    float k  = (r1 - r0) / L;

    float A = Rd.x*Rd.x + Rd.y*Rd.y - (k*k) * Rd.z*Rd.z;
    float B = 2.0 * (P0.x*Rd.x + P0.y*Rd.y)
            - 2.0 * k * (r0 + k*P0.z) * Rd.z;
    float C = P0.x*P0.x + P0.y*P0.y
            - (r0 + k*P0.z)*(r0 + k*P0.z);

    // Manually stored hits (no dynamic arrays)
    float tHit0 = 0, tHit1 = 0, tHit2 = 0, tHit3 = 0;
    int hitCount = 0;

    float eps = 1e-9;

    // ---- Side intersections ----
    float disc = B*B - 4*A*C;
    if (disc >= 0 && abs(A) > eps)
    {
        float s = sqrt(disc);
        float inv = 0.5 / A;

        float ta = (-B - s) * inv;
        float tb = (-B + s) * inv;

        if (ta > tb) { float tt = ta; ta = tb; tb = tt; }

        float za = P0.z + Rd.z*ta;
        float zb = P0.z + Rd.z*tb;

        if (za >= 0.0 && za <= L) { if (hitCount == 0) tHit0 = ta; else if (hitCount == 1) tHit1 = ta; else if (hitCount == 2) tHit2 = ta; else tHit3 = ta; hitCount++; }
        if (zb >= 0.0 && zb <= L) { if (hitCount == 0) tHit0 = tb; else if (hitCount == 1) tHit1 = tb; else if (hitCount == 2) tHit2 = tb; else tHit3 = tb; hitCount++; }
    }

    // ---- Cap intersections ----
    if (abs(Rd.z) > eps)
    {
        float tc0 = (0.0 - P0.z) / Rd.z;
        float3 hit0 = P0 + Rd * tc0;
        if (hit0.x*hit0.x + hit0.y*hit0.y <= r0*r0)
        {
            if (hitCount == 0) tHit0 = tc0;
            else if (hitCount == 1) tHit1 = tc0;
            else if (hitCount == 2) tHit2 = tc0;
            else tHit3 = tc0;
            hitCount++;
        }

        float tc1 = (L - P0.z) / Rd.z;
        float3 hit1 = P0 + Rd * tc1;
        if (hit1.x*hit1.x + hit1.y*hit1.y <= r1*r1)
        {
            if (hitCount == 0) tHit0 = tc1;
            else if (hitCount == 1) tHit1 = tc1;
            else if (hitCount == 2) tHit2 = tc1;
            else tHit3 = tc1;
            hitCount++;
        }
    }

    if (hitCount == 0)
        return false;

    // Compute tmin/tmax manually
    float tmin = tHit0;
    float tmax = tHit0;

    if (hitCount > 1) { tmin = min(tmin, tHit1); tmax = max(tmax, tHit1); }
    if (hitCount > 2) { tmin = min(tmin, tHit2); tmax = max(tmax, tHit2); }
    if (hitCount > 3) { tmin = min(tmin, tHit3); tmax = max(tmax, tHit3); }

    // Entire volume behind camera
    if (tmax <= 0.0)
        return false;

    // Camera inside volume
    if (tmin < 0.0)
        tmin = 0.0;

    tEnter = tmin;
    tExit  = tmax;
    return true;
}

float CylinderEdgeBlend(float3 worldPoint)
{
    float3 P0, Rd; // local temp, not used
    ToCylinderSpace(worldPoint, P0, Rd, CameraPos, float3(0,0,1));

    float t = saturate(P0.z / CylinderLength);
    float radiusAtZ = lerp(CylinderStartRadius, CylinderEndRadius, t);

    float radialDist = length(P0.xy);
    float edgeDist = radiusAtZ - radialDist;

    float e = smoothstep(0.0, EdgeFade * 0.5, edgeDist);
    return pow(e, 0.8);
}

float4 main(PS_INPUT i) : COLOR
{
    float4 sceneSample = tex2D(SceneSampler, i.uv);
    float3 sceneColor  = sceneSample.rgb;
    float4 wpDepth     = tex2D(WPDepthSampler, i.uv);

    float3 worldPos = 1.0 / wpDepth.xyz;
    float3 rayDir = normalize(worldPos - CameraPos);

    bool isSky = (wpDepth.a == 0.00025);
    float viewSurfaceDist = isSky ? 1e6 : distance(worldPos, CameraPos);

    float tEnter, tExit;

    bool intersects = RayIntersectCylinderVolume(CameraPos, rayDir, tEnter, tExit);
    if (!intersects)
        return float4(0,0,0,0);

    float fogSegStart = max(tEnter, 0.0);
    float fogSegEnd   = min(tExit, viewSurfaceDist);
    float segmentLen  = max(fogSegEnd - fogSegStart, 0.0);

    if (segmentLen <= 0.0)
        return float4(0,0,0,0);

    float scaledDensity = FogDensity * 0.02;
    float fogFactor = 1.0 - exp(-scaledDensity * segmentLen);

    float midT = (fogSegStart + fogSegEnd) * 0.5;
    float3 midPoint = CameraPos + rayDir * midT;

    float edgeBlend = CylinderEdgeBlend(midPoint);

    float finalVisibility = saturate(fogFactor * edgeBlend);

    float distToMid = distance(midPoint, CameraPos);
    float rangeRamp = saturate((distToMid - FogStart) /
                               max(0.0001, FogEnd - FogStart));

    finalVisibility *= rangeRamp;

    float3 fogContribution = FogColor * finalVisibility;
    return float4(fogContribution, finalVisibility);
}