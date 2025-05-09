// effect on sera wings
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
  uniform float4x4 worldViewProjMatrix)
{
	pixdata O;
	
	float4 pos4 = float4(I.position, 1.0);
	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);
	// vertex-position in screen space
    O.screenCoord = calcScreenToTexCoord(O.hposition);
	// pass texture coords
	O.texcoord0 = I.texcoord.xyyy;

	return O;
}

/*
fragout mainPS(pixdata I,
  uniform sampler2D   texture0,
  uniform sampler2D   texture1,
  uniform sampler2D   texture2,
  uniform float4      system_data)
{
	fragout O;
    
    float2 coords = float2(I.texcoord0.xy);
    float dist = length(coords);
    
    float4 tex0 = tex2D(texture0, coords.xy);
    float4 tex2 = tex2D(texture2, coords.xy);
        
    // overlay burst (radial!)
    float4 color_pulse1 = tex2D(texture1, float2(dist - (0.3 * system_data.x), 0.0));
    
    // push_up
    float4 color_pulse2  = (3.0 * color_pulse1) + color_pulse1.wwww;
    
    // compose
    float3 somefactor = float3(tex2.xyz * color_pulse2.xyz);
    float3 color0 = saturate(float3(tex0.xyz + somefactor.xyz + (0.5 * color_pulse1.xyz)));
    float3 color1 = saturate(float3((0.4 * somefactor.xyz) + (0.3 * color_pulse1.xyz)));
	
	O.col[0] = float4(color0.xyz, tex0.a);
	O.col[1] = float4(color1.xyz, tex0.a);

	return O;
}
*/

fragout mainPS(pixdata I,
  uniform sampler2D   texture0,
  uniform sampler2D   texture1,
  uniform sampler2D   texture2,
  uniform sampler3D   textureVolume,
  uniform float4      system_data)
{
	fragout O;
    
    float2 coords = float2(I.texcoord0.xy);
    float dist = length(coords);
    
    float4 tex0 = tex2D(texture0, coords.xy);
    
    sTEnergy te;
    calc_tenergy(te, textureVolume, texture1, texture2, coords, dist, system_data.x);
    
    float3 color_diffuse = colorize3D(tex0.xyz + te.color0.xyz);
    float3 color_glow = te.color1;
	
	O.col[0] = float4(color_diffuse.xyz, tex0.a);
	O.col[1] = float4(color_glow.xyz, tex0.a);

	return O;
}