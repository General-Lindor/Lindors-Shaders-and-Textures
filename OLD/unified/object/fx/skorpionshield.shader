// skorpionshield

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
	float2 texcoord     : TEXCOORD0;
	float4 screenCoord  : TEXCOORD1;
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

	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);
	
	// vertex-position in screen space
	O.screenCoord = calcScreenToTexCoord(O.hposition);
	
	// pass texture coords (pre multi here!)
	O.texcoord = I.texcoord.xy;

	return O;
}

fragout mainPS(pixdata I,
  uniform sampler2D   texture0,
  uniform float4      param,
  uniform float4      system_data)
{
	fragout O;

  // names
  float elapsedTime = param.w;
  float depthscroll = param.x;
  float time = system_data.x;
    
    // lightness independent flow anim
    s2half4 tex0 = tex2D(texture0, I.texcoord.xy + (time * float2(0.05f, 0.05f)));
    
    // lightness independent flow anim
    s2half4 tex1 = tex2D(texture0, I.texcoord.xy + ((time + 3.14159265f) * float2(0.05f, 0.0f - 0.05f)));
    
    // compose
    float l_tex0 = max(tex0.x, max(tex0.y, tex0.z)) * tex0.w;
    float l_tex1 = max(tex1.x, max(tex1.y, tex1.z)) * tex1.w;
    s2half4 texComposed = s2half4(lerp(tex0.xyz, tex1.xyz, 0.5f * (1.0f - l_tex0 + l_tex1)), max(tex0.w, tex1.w));
    
    /*
    // glow
    float glow = max(tex1.x, max(tex1.y, tex1.z));
    
    // glow
    //float intensity = sin(I.texcoord.x * 0.05f) * sin((I.texcoord.y + time) * 0.05f);
    //intensity *= intensity;
    //intensity = pow(intensity, 20.0f);
    //float glow = max(tex0.x, max(tex0.y, tex0.z));
    //glow = lerp(1.0f, 1.0f / glow, intensity);

  // out
	O.col[0] = float4(tex1.xyz, tex1.w);
	//O.col[1] =  float4(tex1.xyz * (0.5f + 0.5f * cos(time)), tex1.w);
	O.col[1] =  float4(tex1.xyz * glow, tex1.w);
	
	return O;
    */
    
    
    //calc glow noise
	    float fnoise;
	    float rnd = 0.0f;
	    float f = 1.0f;
        float slowTime = time * 0.15f;
	    float2 coord = I.texcoord.xy + float2(slowTime, slowTime);
	    for(int i = 0; i < 4; i++)
	    {
		    fnoise = tex2D(texture0, coord * 0.2f * f).w;
		    fnoise -= 0.5f;
		    fnoise *= 4.0f;
		    rnd += fnoise / f;
		    f *= 4.17f;	
	    }
	    coord = I.texcoord.xy - float2(slowTime, slowTime);
	    coord -= rnd * 0.02f;
	    float4 tex_lava_noise = tex2D(texture0, coord);
    	
      float3 lava_noise = tex_lava_noise.xyz * texComposed.xyz * (rnd + 1.0f);
      // make sure nothing's greater than 1.0f
      lava_noise = lava_noise.xyz / max(lava_noise.x, max(lava_noise.y, max(lava_noise.z, 1.0f)));
      
      // add terms to get final lava color
      float l_composed = max(texComposed.x, max(texComposed.y, texComposed.z)) * texComposed.w;
      float l_noise = max(lava_noise.x, max(lava_noise.y, lava_noise.z));
      l_noise = l_noise < 0.5f ? l_noise : 1.0f;
      float3 lava_color = lerp(texComposed.xyz, lava_noise.xyz, 0.5f * (1.0f - l_composed + l_noise));
      
      // calc glow
      float l = max(lava_color.x, max(lava_color.y, lava_color.z));
      float3 lava_glow = lava_color.xyz * max(0.5f * l_composed, max(l_noise, cos(time)));

  // out
	O.col[0] = float4(lava_color.xyz, max(texComposed.w, l_noise));
	O.col[1] =  float4(lava_glow.xyz, max(texComposed.w, l_noise));
	return O;
} 

