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
	
	// lighting
		O.camDist_ws = camera_pos - mul(pos4, worldMatrix);
		
		float c_dist_ws = sqrt(dot(O.camDist_ws.xyz, O.camDist_ws.xyz));
	
	// pass texture coords. This is where the magic happens: transform from object space into screen space!
		float4 halfway = calcScreenToTexCoord(O.hposition);
		O.screenCoord = halfway;
		float resolution = 0.05f * c_dist_ws;
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

	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy + 0.03f * time * float2(1.0f, 0.7f));
	s2half4 shadow = tex2Dproj(shadow_texture, I.screenCoord);

  //take the wobbly effect from the fx6 shader (it's called "fx6" in surface.txt, but the shader is called "ambDiffFx5.shader")
	float4 sum_color = float4(0.0f, 0.0f, 0.0f, 0.0f);
	float i = 0, sum_num = 6;
	for(i = 0; i < sum_num; i++)
	{
	  //calc horizontal offset
		float2 offsetUV = I.texcoord0.xy / 5.0f;
	  //make it a little bit slower than in fx6
		offsetUV.y += frac(0.55f + 0.3375f * i * time / sum_num + 0.15f + i / sum_num);
		s2half4 wave_offset = tex2D(texture2, offsetUV);
		float h_offs = (i / sum_num) + (0.1f + 0.03f * i / sum_num) * (wave_offset.x - 0.5f);
		
	  //calc vertical offset
		offsetUV = I.texcoord0.xy / 5.0f;
		wave_offset = tex2D(texture2, offsetUV);
		float v_offs = (0.3f * i / sum_num) * wave_offset.z * (wave_offset.y - 0.5f);

	  //calc lookup
		float2 newUV = I.texcoord0.xy / 5.0f;
	  //increase range of wobblyness compared to fx6 through multiplying by 2
		newUV += 2.0f * float2(h_offs, v_offs);

	  //fx base color
		s2half4 base_color = tex2D(texture1, newUV);
		base_color = pow(base_color, 1.0f + 2.0f * wave_offset.x + 2.0f * wave_offset.y);
		
	  //fx sum color
		sum_color += base_color;
	}

	sum_color /= sum_num;
	
  //end of fx6's wobbly effect calculation
	  
  //HSL color room's Lightness and Saturation from RGB color room
		float a_val = 0.2126f;
		float b_val = 0.7152f;
		float c_val = 0.0722f;
		float3 corr_vector = float3(a_val, b_val, c_val);
		float normalizer = 1.05077738841f;
	  //sum_color
		float lightness_gamma_corrected_sum = dot(sum_color.xyz, corr_vector);
	  //tex0
		float lightness_gamma_corrected_tex0 = dot(tex0.xyz, corr_vector);
		float3 s_vector = tex0.xyz - float3(lightness_gamma_corrected_tex0, lightness_gamma_corrected_tex0, lightness_gamma_corrected_tex0);
		float saturation_tex0 = sqrt(dot(s_vector.xyz, s_vector.xyz) / normalizer);
		
  //compose wobbly+starry. saturation is necessary so that the stars don't get overlayed with the wobbly.
	float3 final_col = float3(0.0f, 0.0f, 0.0f);
	float3 final_glow = float3(0.0f, 0.0f, 0.0f);
	float glow_intensity = 0.0f;
  //star
	if ((1.0f - saturation_tex0) * lightness_gamma_corrected_tex0 > 0.27f) {
		final_col = tex0.xyz;
		final_glow = tex0.xyz;
        glow_intensity = lightness_gamma_corrected_tex0;
	}
  //no_star
	else {
	  //high_nebula
		if (lightness_gamma_corrected_sum > 0.05f) {
		//aimed effect: nebula replaces everything that is not a star and glows a little bit
		
			final_col = sum_color.xyz;
			final_glow = sum_color.xyz;
			glow_intensity = 0.35f;
		}
	  //low_nebula
		else {
		//aimed effect: smooth fade-off of nebula diffuse and glow into starry background
		
		  //multiply by 20.0 because (0.0 < lightness_gamma_corrected_sum < 0.05) and (20.0 * 0.05 = 1)
			float lerpval =  20.0f * lightness_gamma_corrected_sum;
			
		  //calc diffuse, glow and glow_intensity for starry and nebula
		  
			//copy code from star\low_nebula
			  float dimm_min = 0.5f;
			  float dimm_max = 1.0f;
			  float dimm = lerp(dimm_min, dimm_max, sqrt(saturation_tex0 * (1.0f - lightness_gamma_corrected_tex0)));
			  float glow_min = lightness_gamma_corrected_tex0 * dimm;
			  float glow_max = lightness_gamma_corrected_sum;
			  
			//diffuse
			  float3 diffuse_starry = tex0.xyz * dimm;
			  float3 diffuse_nebula = sum_color.xyz;
			  
			//glow
			  float3 glow_starry = tex0.xyz * dimm;
			  float3 glow_nebula = sum_color.xyz;
			  
			//intensity
			  float glow_intensity_starry = lerp(glow_min, glow_max, lerpval);
			  float glow_intensity_nebula = 0.35f;
			  
		  //compose
			final_col = lerp(diffuse_starry, diffuse_nebula, lerpval);
			final_glow = lerp(glow_starry, glow_nebula, lerpval);
			glow_intensity = lerp(glow_intensity_starry, glow_intensity_nebula, lerpval);
		}
	}

  //apply intensity
	final_glow *= glow_intensity;

  //and ready to go
	O.col[0] = float4(final_col, tex0.w);
	O.col[1] = float4(final_glow, tex0.w);
#endif

	return O;
}