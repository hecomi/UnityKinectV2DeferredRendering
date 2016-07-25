Shader "Hidden/KinectDepth"
{

Properties
{
    _MainTex ("Main Texture", 2D) = "" {}
    _LineIntensity ("Line Intensity", Range(0, 30)) = 1.0
    _LineResolution ("Line Resolution", Range(0, 100)) = 10.0
}

SubShader
{

Tags { "RenderType" = "Opaque" "DisableBatching" = "True" "Queue" = "Geometry+10" }
Cull Off

Pass
{
    Tags { "LightMode" = "Deferred" }

    Stencil 
    {
        Comp Always
        Pass Replace
        Ref 128
    }

    CGPROGRAM
    #pragma vertex vert
    #pragma fragment frag
    #pragma target 3.0
    #pragma multi_compile ___ UNITY_HDR_ON

    #include "UnityCG.cginc"

    struct VertInput
    {
        float4 vertex : POSITION;
    };

    struct VertOutput
    {
        float4 vertex    : SV_POSITION;
        float4 screenPos : TEXCOORD0;
    };

    struct GBufferOut
    {
        half4 diffuse  : SV_Target0; // rgb: diffuse,  a: occlusion
        half4 specular : SV_Target1; // rgb: specular, a: smoothness
        half4 normal   : SV_Target2; // rgb: normal,   a: unused
        half4 emission : SV_Target3; // rgb: emission, a: unused
        float depth    : SV_Depth;
    };

    sampler2D _MainTex;
    sampler2D _KinectDepthTexture;
    float4 _KinectDepthTexture_TexelSize;
    float _LineIntensity;
    float _LineResolution;

    float GetDepth(float2 uv)
    {
        uv.y *= -1.0;
        uv.x = 1.0 - uv.x;
        float3 v = tex2D(_KinectDepthTexture, uv);
        return (v.r * 65536 + v.g * 256) * 0.001 /* mm -> m */;
    }

    float3 GetPosition(float2 uv)
    {
        float z = GetDepth(uv);
        float u = 2.0 * (uv.x - 0.5);
        float v = 2.0 * (uv.y - 0.5);
        float xHalf = z * 0.70803946712; // tan(35.3 deg), fov_x = 70.6 (deg).
        float yHalf = z * 0.57735026919; // tan(30.0 deg), fov_y = 60.0 (deg).
        float x = u * xHalf; 
        float y = v * yHalf;

        return float3(x, y, z);
    }

    float3 GetNormal(float2 uv)
    {
        float2 uvX = uv - float2(_KinectDepthTexture_TexelSize.x, 0);
        float2 uvY = uv - float2(0, _KinectDepthTexture_TexelSize.y);

        float3 pos0 = GetPosition(uv);
        float3 posX = GetPosition(uvX);
        float3 posY = GetPosition(uvY);

        float3 dirX = normalize(posX - pos0);
        float3 dirY = normalize(posY - pos0);

        return 0.5 + 0.5 * cross(dirY, dirX);
    }

    float GetDepthForBuffer(float2 uv)
    {
        float4 vpPos = mul(UNITY_MATRIX_VP, float4(GetPosition(uv), 1.0));
        return vpPos.z / vpPos.w;
    }

    VertOutput vert(VertInput v)
    {
        VertOutput o;
        o.vertex = v.vertex;
        o.screenPos = ComputeScreenPos(v.vertex);
        return o;
    }
    
    GBufferOut frag(VertOutput i)
    {
        float2 uv = i.screenPos.xy / i.screenPos.w;

        float depth = GetDepthForBuffer(uv);
        float3 pos = GetPosition(uv);
        float4 normal = float4(GetNormal(uv), 1.0);

        float u = fmod(pos.x, 1.0) * _LineResolution;
        float v = fmod(pos.y, 1.0) * _LineResolution;
        float w = fmod(pos.z, 1.0) * _LineResolution;

        GBufferOut o;
        o.diffuse = normal;
        o.specular = float4(0.0, 0.0, 0.0, 0.0);
        o.emission = _LineIntensity * float4(
            tex2D(_MainTex, float2(w, 0)).r, 
            tex2D(_MainTex, float2(v, 0)).r, 
            tex2D(_MainTex, float2(u, 0)).r, 
            1.0);
        o.depth = depth;
        o.normal = normal;

#ifndef UNITY_HDR_ON
        o.emission = exp2(-o.emission);
#endif

        return o;
    }

    ENDCG
}

}

Fallback Off
}