#include "common_fxc.h"
#include "common_ps_fxc.h"

sampler SceneSampler : register(s0);
sampler WPDepthSampler : register(s1);
sampler3D NoiseSampler : register(s2);

float4 C0 : register(c0);
float4 C1 : register(c1);
float4 C2 : register(c2);
float4 C3 : register(c3);
float4x4 C11: register(c11);

#define CameraPos        C0.xyz
#define EdgeFade         C0.w
#define FogColor         C1.xyz
#define FogDensity       C1.w
#define BoxExtent        C2.xyz
#define FogStart         C2.w
#define BoxOrigin        C3.xyz
#define FogEnd           C3.w

#define Time             C11[0][0]
#define NoiseSize        C11[1][0]
#define NoiseMinInfluence C11[2][0]
#define NoiseMaxInfluence C11[3][0]
#define ScrollX          C11[0][1]
#define ScrollY          C11[1][1]
#define ScrollZ          C11[2][1]

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
    float4 wpDepth = tex2D(WPDepthSampler, i.uv);

    float3 worldPos = 1.0 / wpDepth.xyz;

    float3 boxMin = BoxOrigin - BoxExtent;
    float3 boxMax = BoxOrigin + BoxExtent;

    float3 rayDir = normalize(worldPos - CameraPos);

    bool isSky = (wpDepth.a == 0.00025);
    float viewSurfaceDist = distance(worldPos, CameraPos);
    if (isSky)
        viewSurfaceDist = 1e6;

    float tEnter, tExit;
    bool intersects = RayIntersectBox(CameraPos, rayDir, boxMin, boxMax, tEnter, tExit);
    if (!intersects)
        return float4(0, 0, 0, 0);

    float fogSegStart = max(tEnter, 0.0);
    float fogSegEnd   = min(tExit, viewSurfaceDist);
    float segmentLen  = max(fogSegEnd - fogSegStart, 0.0);
    if (segmentLen <= 0.0)
        return float4(0, 0, 0, 0);

    // === Multi-sample integration parameters ===
    const int steps = 8; // increase to 8 for better fidelity
    float stepSize = segmentLen / steps;

    float3 NoiseScroll = Time * float3(ScrollX, ScrollY, ScrollZ);

    // global extinction/scattering scale you can tweak
    // (user FogDensity still available; map it to an extinction coefficient)
    float extinctionScale = saturate(FogDensity * 0.01); // tweak this to taste
    float scatteringFraction = 0.8; // fraction of extinction that is scattering vs pure absorption

    // Accumulators:
    float3 accumColor = 0.0;    // accumulated in-scattered radiance (premultiplied)
    float  transmittance = 1.0; // current T (starts fully transparent)

    // Small epsilon to avoid log issues
    const float EPS = 1e-6;

    // Front-to-back integration along ray
    [unroll]
    for (int s = 0; s < steps; ++s)
    {
        // sample position at center of the step
        float t = fogSegStart + (s + 0.5) * stepSize;
        float3 p = CameraPos + rayDir * t;

        // Noise-based density
        float3 noiseCoord = frac(p / NoiseSize + NoiseScroll);
        float n = tex3D(NoiseSampler, noiseCoord).r;
        n = clamp(n, NoiseMinInfluence, NoiseMaxInfluence);

        // Local extinction coefficient sigma_t (per unit length)
        // scale by extinctionScale and noise; ensure non-negative
        float sigma_t = max(extinctionScale * n, 0.0);

        // approximate transmittance decrement over this step:
        // exact: dT = exp(-sigma_t * stepSize) ; we will compute as exp() once
        float deltaTau = sigma_t * stepSize;
        float localTransmittance = exp(-deltaTau); // fraction transmissible after this step

        // Scattering coefficient (how much of sigma_t produces scattered light)
        float sigma_s = sigma_t * scatteringFraction;

        // Phase / incident lighting:
        // For a simple shaded fog that uses FogColor as the scattered light color:
        // radiance contributed at this sample (assume ambient white light scaled by FogColor)
        // Each sample contributes: dL = T * sigma_s * stepSize * (in-scattered radiance)
        // We approximate incoming radiance as FogColor (you can replace with environment sampling)
        float3 sampleInScattered = FogColor; // could be multiplied by other lighting

        float3 dL = transmittance * (sigma_s * stepSize) * sampleInScattered;

        accumColor += dL;

        // Update transmittance for next sample
        transmittance *= localTransmittance;

        // Early out if fully opaque
        if (transmittance <= 0.001)
            break;
    }

    // Edge fade (unchanged from your code)
    float3 midPoint = CameraPos + rayDir * ((fogSegStart + fogSegEnd) * 0.5);
    float3 localPosAbs = abs(midPoint - BoxOrigin);
    float3 edgeDist = BoxExtent - localPosAbs;
    float minEdgeDist = min(edgeDist.x, min(edgeDist.y, edgeDist.z));

    float edgeBlend = smoothstep(0.0, EdgeFade * 0.5, minEdgeDist);
    edgeBlend = pow(edgeBlend, 0.8);

    // Distance-based fade (unchanged)
    float distToMid = distance(midPoint, CameraPos);
    float rangeRamp = saturate((distToMid - FogStart) / max(0.0001, (FogEnd - FogStart)));

    // Apply fades to accumulated color and alpha (premultiplied)
    float finalAlpha = saturate((1.0 - transmittance) * edgeBlend * rangeRamp);
    float3 finalColorPremult = accumColor * edgeBlend * rangeRamp; // already premultiplied style

    // Clamp safety
    finalColorPremult = saturate(finalColorPremult);
    finalAlpha = saturate(finalAlpha);

    // Output premultiplied color and alpha
    return float4(finalColorPremult, finalAlpha);
}