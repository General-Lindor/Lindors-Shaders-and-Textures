// fins

#include "extractvalues.shader"

struct appdata {
	float3 position    : POSITION;
	float3 normal      : NORMAL;
	float3 tangent     : TANGENT;
	float3 binormal    : BINORMAL;
	float2 texcoord    : TEXCOORD0;
	float2 data        : TEXCOORD1;
};

struct pixdata {
	float4 hposition   : POSITION;
	float4 texcoord0   : TEXCOORD0;
	float4 screenCoord : TEXCOORD1;
};

struct fragout {
	float4 col[2]      : COLOR;
};

pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix,
  uniform float4x4 invWorldMatrix,
  uniform float4   light_pos,
  uniform float4   camera_pos,
  uniform float4   param)
{
	pixdata O;
	
	float4 pos4 = float4(I.position, 1.0);
	float4 nrm4 = float4(I.normal, 0.0);

  // apply displacement
  pos4 += I.data.x * 2.0 * nrm4;

	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);

	// vertex-position in screen space
  O.screenCoord = calcScreenToTexCoord(O.hposition);

  // texcoord
  O.texcoord0 = I.texcoord.xyyy;

	return O;
}

fragout mainPS(pixdata I,
    uniform sampler2D   texture0,
    uniform sampler2D   texture1,
    uniform sampler2D   texture2,
    uniform sampler3D   textureVolume,
    uniform sampler2D   shadow_texture,
    uniform float4      light_col_amb,
    uniform float4      light_col_diff)
{
	fragout O;
  
  //calculate alpha
	float alpha_diff = 0.5f;
	//float alpha_diff = 0.5 * saturate((1.0 - light_col_diff.z) * light_col_diff.w + (1.0 - light_col_amb.z) * light_col_amb.w);
	//float alpha_glow = 0.5f;
	//float alpha_glow = 0.5 * tex1.a * saturate((1.0 - light_col_diff.z) * light_col_diff.w + (1.0 - light_col_amb.z) * light_col_amb.w);

  // out
	O.col[0] = float4(0.0, 0.0, 1.0, alpha_diff);
	O.col[1] = float4(0.0, 0.0, 0.0, 0.0);

	return O;
} 
