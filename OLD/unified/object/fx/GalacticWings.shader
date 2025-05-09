// ambient
#include "extractvalues.shader"

struct appdata {
	float3 position     : POSITION;
	float3 normal       : NORMAL;
	float3 tangent      : TANGENT;
	float3 binormal     : BINORMAL;
	float2 texcoord     : TEXCOORD0;
	float2 data         : TEXCOORD1;
};

struct pixdata {
	float4 hposition    : POSITION;
	float4 texcoord0    : TEXCOORD0;
	float4 camDist_ws   : TEXCOORD1;
	float4 screenCoord  : TEXCOORD2;
};

#ifdef SM1_1
struct fragout {
	float4 col         : COLOR;
};
#else
struct fragout {
	float4 col[2]      : COLOR;
};
#endif

pixdata mainVS(appdata I,
	uniform float4x4 worldViewProjMatrix,
	uniform float4x4 worldMatrix,
	uniform float4   camera_pos)
{
	pixdata O;
	
	// vertex pos
		float4 pos4 = float4(I.position.xyz, 1.0f);
		float4 nrm4 = float4(I.normal, 0.0f);
		O.hposition = mul(pos4, worldViewProjMatrix);
	
	// camera distance
		O.camDist_ws = camera_pos - mul(pos4, worldMatrix);
		float c_dist_ws = sqrt(dot(O.camDist_ws.xyz, O.camDist_ws.xyz));
	
	// pass texture coords. This is where the magic happens: transform from object space into screen space!
		float4 halfway = calcScreenToTexCoord(O.hposition);
		O.screenCoord = halfway;
		float resolution = 0.01f * c_dist_ws;
		O.texcoord0 = float4(((halfway.x / halfway.w) - 0.5f) * resolution, ((halfway.y / halfway.w) - 0.5f) * resolution, halfway.z * resolution, halfway.w * resolution);

	return O;
}

fragout mainPS(pixdata I,
	uniform sampler2D   texture0,
	uniform sampler2D   texture1,
	uniform sampler2D   texture2,
    uniform sampler2D   shadow_texture,
	uniform samplerCUBE textureCube,
	uniform float4      system_data)
{
	fragout O;

#ifdef SM1_1
	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	O.col = float4(tex0.xyz, 1.0f);
#else
	float time = system_data.x;
  //background
	float4 tex0 = tex2D(texture0, I.texcoord0.xy);
  //pulsating glow
	float4 tex1 = tex2D(texture1, I.texcoord0.xy * 5.0f);
	//float lightness_tex1 = 0.2126f * tex1.x + 0.7152f * tex1.y + 0.0722f * tex1.z;
  //stars/supernovae
	float4 tex2 = tex2D(texture2, (I.texcoord0.xy + 0.03f * time * float2(1.0f, 0.7f)));
  //shadow
	s2half4 shadow = tex2Dproj(shadow_texture, I.screenCoord);
	
	float3 final_col = tex0.xyz + tex2.xyz * tex2.w;
	float3 final_glow = (0.5f + 0.5f * cos(time)) * tex1.xyz * pow(abs(tex1.w), 3.0f) + tex2.xyz * pow(abs(tex2.w), 10.0f);

  //and ready to go
	O.col[0] = float4(final_col, tex0.w);
	O.col[1] = float4(final_glow, tex0.w);
#endif

	return O;
}