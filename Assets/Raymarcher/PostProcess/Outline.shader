Shader "Custom/Outline"
{
    Properties {}
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"
        }
        LOD 100
        ZWrite Off Cull Off
        Pass
        {
            Name "BlitColor"

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // The Blit.hlsl file provides the vertex shader (Vert),
            // input structure (Attributes) and output strucutre (Varyings)
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            #pragma vertex VertNoScaleBias
            #pragma fragment frag

            // Copied from Blit.hlsl, but edited to remove _BlitScaleBias to make sure result fits screen properly
            // ... why do I need to do this??
            Varyings VertNoScaleBias(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                #if SHADER_API_GLES
                float4 pos = input.positionOS;
                float2 uv  = input.uv;
                #else
                float4 pos = GetFullScreenTriangleVertexPosition(input.vertexID);
                float2 uv = GetFullScreenTriangleTexCoord(input.vertexID);
                #endif

                output.positionCS = pos;
                output.texcoord = uv; // * _BlitScaleBias.xy + _BlitScaleBias.zw;
                return output;
            }

            static float2 samplePoints[9] = {
                float2(-1, 1), float2(0, 1), float2(1, 1),
                float2(-1, 0), float2(0, 0), float2(1, 1),
                float2(-1, -1), float2(0, -1), float2(1, -1),
            };

            static float sobelXMatrix[9] = {
                1, 0, -1,
                2, 0, -2,
                1, 0, -1
            };

            static float sobelYMatrix[9] = {
                1, 2, 1,
                0, 0, 0,
                -1, -2, -1
            };

            float _Thickness;

            float SobelColorEdgeDetect(float2 uv, float thickness)
            {
                float2 sobelValue = 0;

                [unroll] for (int i = 0; i < 9; i++)
                {
                    float grayscale = dot(
                        SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_PointClamp, uv + samplePoints[i] * thickness),
                        float3(0.2126, 0.7152, 0.0722));
                    sobelValue += grayscale * float2(sobelXMatrix[i], sobelYMatrix[i]);
                }

                return length(sobelValue);
            }

        

            float4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                float edgeMask = SobelColorEdgeDetect(input.texcoord,_Thickness);
                float3 color = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_PointClamp, input.texcoord);
                return float4(lerp(color, edgeMask, edgeMask), 0);
            }
            ENDHLSL
        }
    }
}