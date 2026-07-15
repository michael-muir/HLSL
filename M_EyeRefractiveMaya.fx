//=============================================================================
// Autodesk Eye Shader
// Optimized for Maya DX11 / HLSL 5.0
// Features: Cornea refraction, iris/pupil, sclera, fake highlight, normals
//=============================================================================

#define NUMBER_OF_MIPMAPS  0
#define PI                 3.14159265359f

#ifndef _MAYA_
    #define _3DSMAX_
    #define _ZUP_
#endif

//-----------------------------------------------------------------------------
// Samplers
//-----------------------------------------------------------------------------
SamplerState LinearClamp  : register(s0)
{
    Filter      = ANISOTROPIC;
    AddressU    = Clamp;
    AddressV    = Clamp;
};

SamplerState LinearWrap   : register(s1)
{
    Filter      = ANISOTROPIC;
    AddressU    = Wrap;
    AddressV    = Wrap;
};

SamplerState ShadowSampler : register(s2)
{
    Filter      = MIN_MAG_MIP_POINT;
    AddressU    = Border;
    AddressV    = Border;
    BorderColor = float4(1,1,1,1);
};

//-----------------------------------------------------------------------------
// Eye Parameters (Grouped UI)
//-----------------------------------------------------------------------------
cbuffer EyeParameters : register(b1)
{
    // Cornea
    float  DepthScale           < string UIGroup="Cornea";    string UIName="Depth Scale";          int UIOrder=100; > = 1.2f;
    float  IOR                  < string UIGroup="Cornea";    string UIName="IOR";                  int UIOrder=101; > = 1.336f;
    float  LimbusDarkScale      < string UIGroup="Cornea";    string UIName="Limbus Dark Scale";    int UIOrder=102; > = 2.15f;
    float  LimbusPow            < string UIGroup="Cornea";    string UIName="Limbus Pow";           int UIOrder=103; > = 8.0f;
    float  LimbusUVWidthColor   < string UIGroup="Cornea";    string UIName="Limbus UV Width Color"; int UIOrder=104; > = 0.035f;
    float  LimbusUVWidthShading < string UIGroup="Cornea";    string UIName="Limbus UV Width Shading"; int UIOrder=105; > = 0.045f;

    // Fake Highlight
    bool   EnableFakeHighlight  < string UIGroup="Fake Highlight"; string UIName="Enable"; int UIOrder=200; > = false;
    float3 FakeLightColor       < string UIGroup="Fake Highlight"; string UIName="Light Color"; int UIOrder=201; > = float3(1,1,1);
    float  FakeLightIntensity   < string UIGroup="Fake Highlight"; string UIName="Intensity"; int UIOrder=202; > = 8.0f;
    float  FakeLightSize        < string UIGroup="Fake Highlight"; string UIName="Size"; int UIOrder=203; > = 100.0f;
    float3 FakeLightLocation    < string UIGroup="Fake Highlight"; string UIName="Location"; int UIOrder=204; > = float3(100,-200,570);
    float3 FakeLightVector      < string UIGroup="Fake Highlight"; string UIName="Vector"; int UIOrder=205; > = float3(-1,5,2);
    bool   MimicDirectional     < string UIGroup="Fake Highlight"; string UIName="Mimic Directional"; int UIOrder=206; > = true;
    bool   UseReflectionVector  < string UIGroup="Fake Highlight"; string UIName="Use Reflection Vector"; int UIOrder=207; > = false;
    bool   UseModifiedNormals   < string UIGroup="Fake Highlight"; string UIName="Use Modified Normals"; int UIOrder=208; > = true;
    float3 FakeNormalBend       < string UIGroup="Fake Highlight"; string UIName="Normal Bend"; int UIOrder=209; > = float3(0,0,0);

    // Iris
    float  RefractionOnOff      < string UIGroup="Iris"; string UIName="Refraction On/Off"; int UIOrder=300; > = 1.0f;
    float  IrisUVRadius         < string UIGroup="Iris"; string UIName="UV Radius"; int UIOrder=301; > = 0.17f;
    float  IrisScaleX           < string UIGroup="Iris"; string UIName="Scale X"; int UIOrder=302; > = 1.0f;
    float  IrisScaleY           < string UIGroup="Iris"; string UIName="Scale Y"; int UIOrder=303; > = 1.0f;
    float  IrisRoughness        < string UIGroup="Iris"; string UIName="Roughness"; int UIOrder=304; > = 0.1f;
    float  SpecularityIris      < string UIGroup="Iris"; string UIName="Specularity"; int UIOrder=305; > = 0.3f;
    float  IrisDispScaleUV      < string UIGroup="Iris"; string UIName="Displacement Scale UV"; int UIOrder=306; > = 0.9f;
    float  IrisDispStrength     < string UIGroup="Iris"; string UIName="Displacement Strength"; int UIOrder=307; > = 0.5f;
    float3 CloudyIrisColor      < string UIGroup="Iris"; string UIName="Cloudy Color"; int UIOrder=308; > = float3(0.037188f, 0.043189f, 0.06f);
    float  IrisConcavityPower   < string UIGroup="Iris"; string UIName="Concavity Power"; int UIOrder=309; > = 0.276744f;
    float  IrisConcavityScale   < string UIGroup="Iris"; string UIName="Concavity Scale"; int UIOrder=310; > = 0.111628f;

    // Pupil
    float  PupilScale           < string UIGroup="Pupil"; string UIName="Scale"; int UIOrder=600; > = 0.7f;
    float  PupilScaleX          < string UIGroup="Pupil"; string UIName="Scale X"; int UIOrder=601; > = 1.0f;
    float  PupilScaleY          < string UIGroup="Pupil"; string UIName="Scale Y"; int UIOrder=602; > = 1.0f;
    float  PupilShiftX          < string UIGroup="Pupil"; string UIName="Shift X"; int UIOrder=603; > = 0.0f;
    float  PupilShiftY          < string UIGroup="Pupil"; string UIName="Shift Y"; int UIOrder=604; > = 0.0f;

    // Sclera
    float3 EyeCornerDarkColor   < string UIGroup="Sclera"; string UIName="Corner Darkness Color"; int UIOrder=700; > = float3(0.23f, 0.083f, 0.032f);
    float  CornerDarkRadius     < string UIGroup="Sclera"; string UIName="Corner Radius"; int UIOrder=701; > = 0.65f;
    float  CornerDarkHardness   < string UIGroup="Sclera"; string UIName="Corner Hardness"; int UIOrder=702; > = 0.345f;
    float  FlattenScleraNormal  < string UIGroup="Sclera"; string UIName="Flatten Normal"; int UIOrder=703; > = 0.7f;
    float  NormalUVScale        < string UIGroup="Sclera"; string UIName="Normal UV Scale"; int UIOrder=704; > = 2.5f;
    float  ScaleByCenter        < string UIGroup="Sclera"; string UIName="Scale By Center"; int UIOrder=705; > = -1.0f;
    float  ScleraRoughness      < string UIGroup="Sclera"; string UIName="Roughness"; int UIOrder=706; > = 0.1f;
    float  SpecularitySclera    < string UIGroup="Sclera"; string UIName="Specularity"; int UIOrder=707; > = 0.3f;
    float  VeinsMix             < string UIGroup="Sclera"; string UIName="Veins Mix"; int UIOrder=708; > = 1.0f;

    // General
    bool   UseEyeBulge          < string UIGroup="General"; string UIName="Use Eye Bulge"; int UIOrder=900; > = true;
    float  Opacity              : OPACITY < string UIGroup="General"; string UIName="Opacity"; int UIOrder=901; > = 1.0f;
};

//-----------------------------------------------------------------------------
// Textures
//-----------------------------------------------------------------------------
Texture2D IrisColorTex          : register(t0);
Texture2D ScleraColorTex        : register(t1);
Texture2D MidPlaneDispTex       : register(t2);
Texture2D EyeBulgeNormalTex     : register(t3);
Texture2D EyeSphereNormalTex    : register(t4);
Texture2D ScleraNormalTex       : register(t5);
Texture2D IrisNormalTex         : register(t6);

//-----------------------------------------------------------------------------
// Input / Output
//-----------------------------------------------------------------------------
struct VertexInput
{
    float3 Position : POSITION;
    float2 UV0      : TEXCOORD0;
    float2 UV1      : TEXCOORD1;
    float2 UV2      : TEXCOORD2;
    float3 Normal   : NORMAL;
    float3 Binormal : BINORMAL;
    float3 Tangent  : TANGENT;
};

struct PixelInput
{
    float4 Position     : SV_Position;
    float2 UV0          : TEXCOORD0;
    float3 WorldNormal  : TEXCOORD1;
    float4 WorldTangent : TEXCOORD2;   // .w = handedness
    float3 WorldView    : TEXCOORD3;
    float3x3 TBN        : TEXCOORD4;   // Tangent -> World matrix
    float3 WorldPos     : TEXCOORD7;
};

//-----------------------------------------------------------------------------
// Helper Functions
//-----------------------------------------------------------------------------
float3 SafeNormalize(float3 v)
{
    float lenSq = dot(v, v);
    return lenSq > 0.000001f ? normalize(v) : float3(0, 0, 1);
}

float2 PickUV(int index, float2 uv0, float2 uv1, float2 uv2)
{
    return index == 1 ? uv1 : (index == 2 ? uv2 : uv0);
}

float3 BlendAngleCorrectedNormals(float3 base, float3 add)
{
    float3 a = float3(base.xy, base.z + 1.0f);
    float3 b = float3(-add.xy, add.z);
    return (a * dot(a, b)) - (base.z + 1.0f) * b;
}

float SphereMask(float2 uv, float radius, float hardness)
{
    float d = length(uv - 0.5f);
    return saturate((1.0f - d / radius) / max(1.0f - hardness * 0.01f, 0.0001f));
}

//-----------------------------------------------------------------------------
// Eye-Specific Functions
//-----------------------------------------------------------------------------
float2 ScaleUVByCenter(float2 uv, float2 scale)
{
    return (uv / scale) + 0.5f - 0.5f / scale;
}

float3 ComputeRefractionDir(float ior, float3 N, float3 V)
{
    float eta = 1.00029f / ior;
    float cosTheta = dot(N, V);
    float k = sqrt(1.0f + (eta * cosTheta - 1.0f) * (eta * cosTheta + 1.0f)); // simplified
    return normalize((eta * cosTheta - k) * N - eta * V);
}

float2 PupilTransform(float2 uv, float scale, float scaleX, float scaleY, float shiftX, float shiftY)
{
    float shiftMask = pow(saturate(2.0f * (0.45f - distance(0.5f, uv))), 0.7f);
    uv += float2(shiftX, shiftY) * shiftMask * float2(-0.1f, 0.1f);

    float2 c = uv - 0.5f;
    float len = length(c);
    float2 edge = normalize(c) * 0.5f;

    float2 scaled = lerp(edge, 0.0f, saturate((1.0f - len * 2.0f) * float2(scale * scaleX, scale * scaleY)));
    return scaled + 0.5f;
}

//-----------------------------------------------------------------------------
// Vertex Shader
//-----------------------------------------------------------------------------
PixelInput VS(VertexInput IN)
{
    PixelInput OUT = (PixelInput)0;

    float4 worldPos = mul(float4(IN.Position, 1.0f), World);
    OUT.WorldPos    = worldPos.xyz;
    OUT.Position    = mul(worldPos, ViewProjection);

    OUT.UV0         = IN.UV0;

    OUT.WorldNormal = SafeNormalize(mul(IN.Normal, (float3x3)WorldInverseTranspose));
    OUT.WorldTangent.xyz = SafeNormalize(mul(IN.Tangent, (float3x3)WorldInverseTranspose));
    OUT.WorldTangent.w   = sign(dot(cross(IN.Normal, IN.Tangent), IN.Binormal));

    float3 binormal = cross(OUT.WorldNormal, OUT.WorldTangent.xyz) * OUT.WorldTangent.w;
    OUT.TBN = float3x3(OUT.WorldTangent.xyz, binormal, OUT.WorldNormal);

    OUT.WorldView = SafeNormalize(viewInv[3].xyz - OUT.WorldPos);

    return OUT;
}

//-----------------------------------------------------------------------------
// Pixel Shader
//-----------------------------------------------------------------------------
float4 PS(PixelInput IN, bool isFrontFace : SV_IsFrontFace) : SV_Target
{
    float gamma = LinearSpaceLighting ? 2.2f : 1.0f;

    // Base normals
    float3 N = IN.WorldNormal;
    float3 V = IN.WorldView;

    // Eye surface normal (bulge or sphere)
    float2 bulgeUV = PickUV(EyeBulgeNormalMapUV ? /* add UV selector if needed */, IN.UV0, IN.UV0, IN.UV0);
    float3 eyeN = UseEyeBulge ?
        EyeBulgeNormalTex.Sample(LinearWrap, bulgeUV).xyz * 2.0f - 1.0f :
        EyeSphereNormalTex.Sample(LinearWrap, bulgeUV).xyz * 2.0f - 1.0f;

    float3 eyeDirWS = mul(eyeN, IN.TBN);

    // ====================== REFRACTION ======================
    float2 irisScale   = float2(IrisScaleX, IrisScaleY);
    float2 irisRadius  = IrisUVRadius * irisScale;
    float2 centerScale = ScaleByCenter * irisScale;

    float2 uvScaled = ScaleUVByCenter(IN.UV0, centerScale);

    float3 refrDir = ComputeRefractionDir(IOR, normalize(eyeN), -V);

    // Depth plane for refraction offset
    float depthPlane = MidPlaneDispTex.Sample(LinearWrap, float2(irisRadius.x * centerScale.x + 0.5f, 0.5f)).r;

    float2 limbusWidth = irisScale * float2(LimbusUVWidthColor, LimbusUVWidthShading);
    float2 irisMask = CalcIrisUVMask(IrisUVRadius, uvScaled, limbusWidth); // reuse helper if defined

    float2 refractedUV = lerp(uvScaled, uvScaled + IrisUVRadius * refrDir.xy * /* depth factor */, irisMask.x * RefractionOnOff);

    // ====================== IRIS & PUPIL ======================
    float2 pupilUV = PupilTransform(refractedUV, PupilScale, PupilScaleX, PupilScaleY, PupilShiftX, PupilShiftY);

    float3 irisColor = pow(IrisColorTex.Sample(LinearClamp, pupilUV).rgb, gamma);
    irisColor *= (1.0f - pow(length((pupilUV - 0.5f) * LimbusDarkScale), LimbusPow));
    irisColor += SphereMask(pupilUV, 0.18f, 0.2f) * CloudyIrisColor;

    // ====================== SCLERA ======================
    float3 scleraColor = lerp(float3(0.416f, 0.379f, 0.376f),
                              pow(ScleraColorTex.Sample(LinearClamp, uvScaled).rgb, gamma), VeinsMix);

    float3 baseColor = lerp(scleraColor, irisColor, irisMask.x) * 2.0f;

    // Corner shadow
    baseColor *= lerp(EyeCornerDarkColor, 1.0f, SphereMask(uvScaled, CornerDarkRadius, CornerDarkHardness));

    // ====================== NORMALS ======================
    float2 scleraNuv = ScaleUVByCenter(IN.UV0, float2(NormalUVScale, NormalUVScale));
    float3 scleraN = ScleraNormalTex.Sample(LinearWrap, scleraNuv).xyz * 2.0f - 1.0f;
    scleraN = FlattenNormal(scleraN, lerp(FlattenScleraNormal, 1.0f, irisMask.y));

    float3 irisBottomN = IrisNormalTex.Sample(LinearWrap, float2(1.0f - pupilUV.x, 1.0f - pupilUV.y)).xyz * 2.0f - 1.0f;
    float3 irisN = BlendAngleCorrectedNormals(eyeN, irisBottomN * float3(IrisDispStrength, IrisDispStrength, 1.0f));

    float3 finalN = lerp(scleraN, irisN, irisMask.y);
    finalN = SafeNormalize(mul(finalN, IN.TBN));

    // ====================== FAKE HIGHLIGHT ======================
    float3 highlight = 0.0f;
    if (EnableFakeHighlight)
    {
        float3 lightVec = MimicDirectional ? FakeLightVector : SafeNormalize(FakeLightLocation - IN.WorldPos);
        float3 surfN = UseModifiedNormals ? mul(SafeNormalize(finalN), IN.TBN) : SafeNormalize(finalN + FakeNormalBend);

        float3 R = UseReflectionVector ? reflect(-V, surfN) : normalize(lightVec + V);
        float intensity = pow(saturate(dot(surfN, R)), FakeLightSize);
        highlight = intensity * FakeLightColor * FakeLightIntensity;
    }

    // ====================== FINAL COMPOSITE ======================
    float3 color = baseColor + highlight;
    float alpha = saturate(Opacity);

    // Gamma correction
    if (!MayaFullScreenGamma)
        color = pow(color, 1.0f / gamma);

    return float4(color, alpha);
}

//-----------------------------------------------------------------------------
// Technique
//-----------------------------------------------------------------------------
technique11 EyeShader
<
    bool overridesDrawState = false;
    int isTransparent = 3;
    string transparencyTest = "Opacity < 1.0";
    bool supportsAdvancedTransparency = true;
>
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, VS()));
        SetPixelShader(CompileShader(ps_5_0, PS()));
    }
};
