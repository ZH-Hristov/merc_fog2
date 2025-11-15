#include "common_fxc.h"
#include "common_ps_fxc.h"

sampler SceneSampler : register(s0);
sampler WorldPosSampler : register(s1);

float4 C0 : register(c0); // x = Start, y = End, z = Max density, w = Sky blend
float4 C1 : register(c1); // RGB = Fog color
float4 C2 : register(c2); // EyePos

struct PS_INPUT
{
    float2 vTexCoord : TEXCOORD0;
};


float4 main(PS_INPUT i) : COLOR
{
    float3 sceneColor = tex2D(SceneSampler, i.vTexCoord).rgb;
    float4 wpDepth = tex2D(WorldPosSampler, i.vTexCoord);
    float3 worldPos = 1/wpDepth.rgb;
    bool isSky = (wpDepth.a == 0.00025);

    float3 dist = distance(worldPos, C2.xyz);
    float len = length(dist);
    float fogFactor = saturate((len - C0.x) / (C0.y - C0.x));
    fogFactor = 1.0 - exp(-fogFactor * C0.z);

    if (isSky)
    {
        fogFactor *= C0.w;
    }

    float3 fogColor = C1.rgb * fogFactor;
    return float4(fogColor, fogFactor);
}