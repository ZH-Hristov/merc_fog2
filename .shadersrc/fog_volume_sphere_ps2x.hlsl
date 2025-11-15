#include "common_fxc.h"
#include "common_ps_fxc.h"

sampler SceneSampler : register(s0);
sampler WPDepthSampler : register(s1);

float4 C0 : register(c0);
float4 C1 : register(c1);
float4 C2 : register(c2);
float4 C3 : register(c3);

#define CameraPos C0.xyz
#define EdgeFade C0.w
#define FogColor C1.xyz
#define FogDensity C1.w
#define SphereRadius C2.x
#define FogStart C2.w
#define SphereOrigin C3.xyz
#define FogEnd C3.w

struct PS_INPUT
{
    float2 uv : TEXCOORD0;
};

bool RayIntersectSphere(float3 rayOrigin, float3 rayDir,
                        float3 center, float radius,
                        out float tEnter, out float tExit)
{
    float3 oc = rayOrigin - center;
    float b = dot(oc, rayDir);
    float c = dot(oc, oc) - radius * radius;
    float h = b * b - c;
    if (h < 0.0)
        return false;

    h = sqrt(h);
    tEnter = -b - h;
    tExit  = -b + h;

    return tExit > max(tEnter, 0.0);
}

float SphereEdgeBlend(float3 midPoint, float3 center, float radius, float edgeFade)
{
    float dist = distance(midPoint, center);
    float edgeDist = radius - dist;
    float e = smoothstep(0.0, edgeFade * 0.5, edgeDist);
    return pow(e, 0.8);
}

float4 main(PS_INPUT i) : COLOR
{
    float4 sceneSample = tex2D(SceneSampler, i.uv);
    float3 sceneColor = sceneSample.rgb;
    float4 wpDepth = tex2D(WPDepthSampler, i.uv);

    float3 worldPos = 1.0 / wpDepth.xyz;
    float3 rayDir = normalize(worldPos - CameraPos);

    bool isSky = (wpDepth.a == 0.00025);
    float viewSurfaceDist = distance(worldPos, CameraPos);
    if (isSky)
    {
        // Treat sky as infinitely far so rays cross full fog sphere
        viewSurfaceDist = 1e6;
    }

    float radius = SphereRadius;  // reuse X as radius
    float tEnter, tExit;

    bool intersects = RayIntersectSphere(CameraPos, rayDir, SphereOrigin, radius, tEnter, tExit);
    if (!intersects)
        return float4(0,0,0,0);

    float fogSegStart = max(tEnter, 0.0);
    float fogSegEnd   = min(tExit, viewSurfaceDist);
    float segmentLen  = max(fogSegEnd - fogSegStart, 0.0);

    if (segmentLen <= 0.0)
        return float4(0,0,0,0);

    // Rescale density for more intuitive artistic control
    float scaledDensity = FogDensity * 0.02;
    float fogFactor = 1.0 - exp(-scaledDensity * segmentLen);

    float midT = (fogSegStart + fogSegEnd) * 0.5;
    float3 midPoint = CameraPos + rayDir * midT;

    // sphere fade
    float edgeBlend = SphereEdgeBlend(midPoint, SphereOrigin, radius, EdgeFade);

    float finalVisibility = saturate(fogFactor * edgeBlend);

    float distToMid = distance(midPoint, CameraPos);
    float rangeRamp = saturate((distToMid - FogStart) / max(0.0001, (FogEnd - FogStart)));
    finalVisibility *= rangeRamp;

    // Output fog contribution for additive blending
    float3 fogContribution = FogColor * finalVisibility;
    return float4(fogContribution, finalVisibility);
}
