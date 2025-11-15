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
#define BoxExtent C2.xyz // half-size (was BoxMax)
#define FogStart C2.w
#define BoxOrigin C3.xyz
#define FogEnd C3.w

struct PS_INPUT
{
    float2 uv : TEXCOORD0;
};

bool RayIntersectBox(float3 rayOrigin, float3 rayDir, float3 boxMin, float3 boxMax, out float tEnter, out float tExit)
{
    float3 invDir = 1.0 / rayDir;
    float3 t0s = (boxMin - rayOrigin) * invDir;
    float3 t1s = (boxMax - rayOrigin) * invDir;

    float3 tsmaller = min(t0s, t1s);
    float3 tbigger  = max(t0s, t1s);

    tEnter = max(tsmaller.x, max(tsmaller.y, tsmaller.z));
    tExit  = min(tbigger.x,  min(tbigger.y,  tbigger.z));

    return tExit > max(tEnter, 0.0);
}

float4 main(PS_INPUT i) : COLOR
{
    float4 sceneSample = tex2D(SceneSampler, i.uv);
    float3 sceneColor = sceneSample.rgb;
    float4 wpDepth = tex2D(WPDepthSampler, i.uv);

    float3 worldPos = 1.0 / wpDepth.xyz;

    float3 boxMin = BoxOrigin - BoxExtent;
    float3 boxMax = BoxOrigin + BoxExtent;

    float3 rayDir = normalize(worldPos - CameraPos);

    bool isSky = (wpDepth.a == 0.00025);
    float viewSurfaceDist = distance(worldPos, CameraPos);
    if (isSky)
    {
        // Treat sky as infinitely far so rays cross full fog box
        viewSurfaceDist = 1e6;
    }

    float tEnter, tExit;
    bool intersects = RayIntersectBox(CameraPos, rayDir, boxMin, boxMax, tEnter, tExit);

    if (!intersects)
    {
        return float4(0, 0, 0, 0); // No contribution outside box
    }

    float fogSegStart = max(tEnter, 0.0);
    float fogSegEnd   = min(tExit, viewSurfaceDist);
    float segmentLen  = max(fogSegEnd - fogSegStart, 0.0);

    if (segmentLen <= 0.0)
    {
        return float4(0, 0, 0, 0);
    }

    // Rescale density for more intuitive artistic control
    float scaledDensity = FogDensity * 0.02;
    float fogFactor = 1.0 - exp(-scaledDensity * segmentLen);

    float midT = (fogSegStart + fogSegEnd) * 0.5;
    float3 midPoint = CameraPos + rayDir * midT;
    float3 localPos = abs(midPoint - BoxOrigin);
    float3 edgeDist = BoxExtent - localPos;
    float minEdgeDist = min(edgeDist.x, min(edgeDist.y, edgeDist.z));

    float edgeBlend = smoothstep(0.0, EdgeFade * 0.5, minEdgeDist);
    edgeBlend = pow(edgeBlend, 0.8);

    float finalVisibility = saturate(fogFactor * edgeBlend);

    float distToMid = distance(midPoint, CameraPos);
    float rangeRamp = saturate((distToMid - FogStart) / max(0.0001, (FogEnd - FogStart)));
    finalVisibility *= rangeRamp;

    // Output fog contribution for additive blending
    float3 fogContribution = FogColor * finalVisibility;
    return float4(fogContribution, finalVisibility);
}
