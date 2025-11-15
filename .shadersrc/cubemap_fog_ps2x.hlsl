#include "common_fxc.h"
#include "common_ps_fxc.h"

sampler SceneSampler : register(s0);
sampler WorldPosSampler : register(s1);
sampler CubemapSampler : register(s2);

float4 C0 : register(c0); // x = Start, y = End, z = Max density, w = Blur radius
float4 C1 : register(c1); // RGB = Fog color
float4 C2 : register(c2); // EyePos
float4 C3 : register(c3);

struct PS_INPUT
{
    float2 vTexCoord : TEXCOORD0;
};

float3 BlurRT9(sampler2D tex, float2 uv, float2 texelSize, float radius)
{
    // Gaussian weights (3x3)
    float w[3] = {0.25, 0.125, 0.0625}; // center, adjacents, diagonals
    float3 c = 0;

    // Center
    c += tex2D(tex, uv) * w[0];

    // Adjacent pixels (N, S, E, W)
    c += tex2D(tex, uv + float2(texelSize.x * radius, 0)) * w[1];
    c += tex2D(tex, uv - float2(texelSize.x * radius, 0)) * w[1];
    c += tex2D(tex, uv + float2(0, texelSize.y * radius)) * w[1];
    c += tex2D(tex, uv - float2(0, texelSize.y * radius)) * w[1];

    // Diagonal pixels (NE, NW, SE, SW)
    c += tex2D(tex, uv + float2(texelSize.x * radius, texelSize.y * radius)) * w[2];
    c += tex2D(tex, uv + float2(texelSize.x * radius, -texelSize.y * radius)) * w[2];
    c += tex2D(tex, uv + float2(-texelSize.x * radius, texelSize.y * radius)) * w[2];
    c += tex2D(tex, uv - float2(texelSize.x * radius, texelSize.y * radius)) * w[2];

    // Normalize
    float totalW = w[0] + 4*w[1] + 4*w[2];
    return c / totalW;
}

float4 main(PS_INPUT i) : COLOR
{
    float SkyboxWidth = C3.x;
    float SkyboxHeight = C3.y;
    float SkyBlend = C3.z;

    float3 sceneColor = tex2D(SceneSampler, i.vTexCoord).rgb;
    float4 wpDepth = tex2D(WorldPosSampler, i.vTexCoord);
    float3 worldPos = 1/wpDepth.rgb;
    float2 texelSize = float2(1.0 / SkyboxWidth, 1.0 / SkyboxHeight);
    float radius = C0.w; // constant blur radius
    bool isSky = (wpDepth.a == 0.00025);

    float3 CubemapColor = BlurRT9(CubemapSampler, i.vTexCoord, texelSize, radius);

    float3 dist = distance(worldPos, C2.xyz);
    float len = length(dist);
    float fogFactor = saturate((len - C0.x) / (C0.y - C0.x));
    fogFactor = 1.0 - exp(-fogFactor * C0.z);

    if (isSky)
    {
        // Reduce fog effect on skybox based on blend factor
        fogFactor *= SkyBlend;
    }

    float3 fogColor = CubemapColor * C1.rgb * fogFactor;
    return float4(fogColor, fogFactor);
}