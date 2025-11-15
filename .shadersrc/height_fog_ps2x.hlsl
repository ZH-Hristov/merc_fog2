#include "common_fxc.h"
#include "common_ps_fxc.h"

sampler SceneSampler : register(s0);
sampler WPDepthSampler : register(s1);

float4 C0 : register(c0); // x = Start Height, y = End Height, z = Max density, w = Depth fade
float4 C1 : register(c1); // RGB = Fog color

struct PS_INPUT
{
    float2 vTexCoord : TEXCOORD0;
};

float4 main(PS_INPUT i) : COLOR
{
    float4 wpDepth = tex2D(WPDepthSampler, i.vTexCoord);
    float worldZ = 1.0 / wpDepth.z;

    // Sky check
    if (wpDepth.a == 0.00025) discard;

    // Height-based fog density
    float fogFactor = saturate((worldZ - C0.x) / (C0.y - C0.x));
    fogFactor = 1.0 - exp(-fogFactor);
    fogFactor *= C0.z;

    // Fade fog near camera
    float depth = wpDepth.w;
    depth = saturate(1.0 - (depth * C0.w));
    fogFactor *= depth;

    // Fog color contribution
    float3 fogColor = C1.rgb * fogFactor;

    // Premultiplied alpha output — this allows stacking via standard alpha blending:
    //   BlendOp = ADD
    //   SrcBlend = ONE
    //   DestBlend = INV_SRC_ALPHA
    // so the result accumulates correctly.
    return float4(fogColor, fogFactor);
}
