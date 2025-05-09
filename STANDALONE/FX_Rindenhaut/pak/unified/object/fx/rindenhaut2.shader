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
	
  // get animated hole-edge-detecetion texture
  s2half4 holes = tex3D(textureVolume, float3(I.texcoord.xy, 0.07 * time));
  
  // get animated overlay texture
  s2half4 border_color = tex2D(texture0, 10.0 * I.texcoord.xy);
  
  //volume map's alpha min and max for border
  //float alphamin = 0.05f;
  //float alphamax = 0.7f;
  
  //sinus
  //s2half border_glow = sin(((holes.a - alphamin) * 3.14159265) / (alphamax - alphamin));
  //positive slope
  //s2half border_glow = (holes.a - alphamin) / (alphamax - alphamin);
  //negative slope
  //s2half border_glow = (alphamax - holes.a) / (alphamax - alphamin);
  
  s2half border_glow = 5 * holes.a - 0.5;
  
  // compose
  s2half4 border = border_glow * border_color;
	
	clip(holes.a - 0.1);
	clip(0.3 - holes.a);
	
  // out
  O.col[0] = float4(border.xyz, border_color.a) + float4(0.01, 0.01, 0.01, 0.01);
  O.col[1] = float4(border.xyz, border_color.a);
  
  return O;
} 
