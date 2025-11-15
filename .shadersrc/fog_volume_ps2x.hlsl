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
#define BoxMax C2.xyz
#define FogStart C2.w
#define BoxOrigin C3.xyz
#define FogEnd C3.w

struct PS_INPUT
{
    float2 uv : TEXCOORD0;
};

float4 main(PS_INPUT i) : COLOR
{
    // Sample inputs
    float3 sceneColor = tex2D(SceneSampler, i.uv).rgb;
    float4 wpDepth = tex2D(WPDepthSampler, i.uv);

    // Sky check
    if (wpDepth.a == 0.00025) discard;

    float3 worldPos = 1/wpDepth.xyz;

    float3 boxMin = BoxOrigin - BoxMax;
    float3 boxMax = BoxOrigin + BoxMax;

    // Check if inside box
    float3 inside = step(boxMin, worldPos) * step(worldPos, boxMax);
    float inBox = inside.x * inside.y * inside.z;

    if (inBox <= 0.0) discard;

    // Compute distance from camera
    float dist = distance(worldPos, CameraPos);
    float len = length(dist);

    // Radial fog
    float fogFactor = saturate((len - FogStart) / (FogEnd - FogStart));
    fogFactor = 1.0 - exp(-fogFactor * FogDensity);

    // Apply only inside box
    fogFactor *= inBox;

    // Fade out at edges
    float3 halfSize = BoxMax;
    float3 localPos = abs(worldPos - BoxOrigin);
    float3 edgeDist = halfSize - localPos;
    float finalClosest = min(edgeDist.x, min(edgeDist.y, edgeDist.z));
    float edgeBlend = smoothstep(0.0, EdgeFade * 0.5, finalClosest);
    edgeBlend = pow(edgeBlend, 0.7); // control softness

    fogFactor *= edgeBlend;

    // Fog color contribution
    float3 fogColor = C1.rgb * fogFactor;

    return float4(fogColor, fogFactor);
}
