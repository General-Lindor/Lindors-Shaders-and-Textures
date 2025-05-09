// dr rindenhaut
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
	float4 hposition  : POSITION;
  float4 texcoord   : TEXCOORD0;
};

struct fragout {
	float4 col[2]      : COLOR;
};


pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix)
{
	pixdata O;

  // position
  float4 pos4 = float4(I.position, 1.0);
  
  // transform
  O.hposition = mul(pos4, worldViewProjMatrix);
  // tc's
  O.texcoord = I.texcoord.xyyy;

	return O;
}

fragout mainPS(pixdata I,
  uniform float4 pix_data_array[4],
  uniform float4 param,
  uniform sampler2D texture0,
  uniform sampler3D textureVolume)
{
	fragout O;
	
	// gice usefull names
	float time = pix_data_array[0].x;
	
  s2half4 tex0 = tex2D(texture0, 10.0 * I.texcoord.xy);
	
  // get animated normal
  s2half4 holes = tex3D(textureVolume, float3(I.texcoord.xy, 0.07 * time));
	
	// weg, wenn nicht in hole
	clip(holes.a - 0.3);
	
  // out
  O.col[0] = tex0;
  O.col[1] = float4(0.0, 0.0, 0.0, 0.0);
  
  return O;
} 
