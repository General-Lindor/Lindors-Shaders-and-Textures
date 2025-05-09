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
	float4 texcoord1   : TEXCOORD1;
	float4 screenCoord : TEXCOORD2;
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
    
    // only works for the original endijan GR2 mesh
	//O.texcoord1 = I.data.xyyy;

	return O;
}

fragout mainPS(pixdata I,
  uniform sampler2D   texture0,
  uniform sampler2D   texture1,
  uniform float4      system_data)
{
	fragout O;

    // color
        s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);

    // move noise entry coords
        float2 noise_coords = I.texcoord0.xy;
    
    // calc plasma intensity
        // p is the y-coord at the start of the wings, at the seraphim's back. Image is 256 pixels wide, start is at pixel 95.
        float p = 95.0 / 256.0;
        // are we at the left or at the right of p?
        float l = 0.5 + ((I.texcoord0.y - p) / (2.0 * abs(I.texcoord0.y - p)));
        // linear interpolation
        float intensity = 0.5 + ((I.texcoord0.y - l) / (2.0 * (p - l)));

    // calc noise
            float2 lup = float2(0.13, 0.13) * noise_coords;
            float2 lup1 = lup + 0.005 * system_data.xx;
            float2 lup2 = lup - 0.005 * system_data.xx;
            float4 noi1 = tex2D(texture1, lup1);
            float4 noi2 = tex2D(texture1, lup2);
        // halfspace
            float noi = abs((noi1.x + noi2.x) - 1);
        // make slimmer
            float pl = pow((1.0 - noi), 10.0 * (1.0 - intensity));

        // pulse factor pulsing between 0.6 and 1.0
            float pulse_factor = 0.8 + 0.2 * sin(6.283185 * frac(0.35 * system_data.x));

    // get plasma color from tex0
        float3 plasma_col_a = pow(intensity, 0.8) * pl * tex0.xyz + 2.0 * pow(intensity, pulse_factor * 5.0) * tex0.xyz;
        float3 plasma_col_g = 0.5 * pow(intensity, pulse_factor * 5.0) * tex0.xyz;
	
	O.col[0] = float4(plasma_col_a, tex0.a);
	O.col[1] = float4(plasma_col_g, tex0.a);

	return O;
} 






