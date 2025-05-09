
#ifdef PS_TRUNK_SPASS_AMBDIF_20
  #define VS_OUT_hposition
  #define VS_OUT_screenCoord
  #define VS_OUT_hpos
  #define VS_OUT_camDist
  #define VS_OUT_lightDist
  #define VS_OUT_posInLight
  #define VS_OUT_depthFog
  #ifdef ENABLE_VERTEXLIGHTING
    //#define VS_OUT_vertexLightData
    #define VS_OUT_vertexLightData_nonrm
  #endif

  struct pixdata {
    float4 hposition   : POSITION;
    float4 texcoord0   : TEXCOORD0;
    float4 camDist     : TEXCOORD1;
    float4 lightDist   : TEXCOORD2;
    float4 screenCoord : TEXCOORD3;
    float4 hpos        : TEXCOORD4;
    float4 posInLight  : TEXCOORD5;
    float2 depthFog    : TEXCOORD6;
    #ifdef VS_OUT_vertexLightData
      float4 vlColor           : COLOR0;
      float4 vlNormal          : TEXCOORD7;
    #endif
    #ifdef VS_OUT_vertexLightData_nonrm
      float4 vlColor           : COLOR0;
    #endif
  };

  fragout2 mainPS(pixdata I,
                  float2 vPos : VPOS,
                  uniform sampler2D texture0,
                  uniform sampler2D texture1,
                  uniform sampler2D texture2,
                  uniform sampler2D texture3,
                  uniform sampler2D shadow_texture,
                  uniform sampler3D textureVolume,
                  uniform sampler2D fog_texture,
                  uniform sampler2D shadow_map,
                  uniform sampler3D noise_map,
                  uniform float4    shadow_data,
                  uniform float4    fog_color,
                  uniform float4    system_data,
                  uniform float4    light_col_amb,
                  uniform float4    light_col_diff,
                  uniform float4    param)
  {
	  fragout2 O;
  //get texture values
	  s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	  s2half4 tex1 = decode_normal(tex2D(texture1, I.texcoord0.xy));
	  float3 nrm  = normalize(tex1.xyz);
	  //float3 nrm  = normalize(I.normal.xyz);
      //nrm = normalize(nrm + normalize(I.normal.xyz));
    
    float3 c_dir_obj_nrm = normalize(I.camDist.xyz);
    float3 l_dir_obj_nrm = normalize(I.lightDist.xyz);
      
  

	float3 light_hero = float3(0.0f, 0.0f, 0.0f);
#ifdef VS_OUT_vertexLightData
	light_hero += light_calc_heroLight(I.vlColor).xyz + light_calc_vertexlighting(nrm, I.vlColor, normalize(I.vlNormal.xyz)).xyz;
    light_hero = saturate(light_hero);
#endif
#ifdef VS_OUT_vertexLightData_nonrm
	light_hero += light_calc_heroLight(I.vlColor).xyz + I.vlColor.xyz;
    light_hero = saturate(light_hero);
#endif
    
    float3 light_col_amb_composed = saturate(light_col_amb.xyz + light_hero.xyz);

#ifdef NO_SHADOWS
    float shadow = 1.0f;
#else  
  #ifdef TREE_HOLE
	float shadow = calcShadowSimple(shadow_map, textureVolume, I.posInLight, vPos, shadow_data.y, shadow_data.x);
  #else
	s2half4 shadowTex = tex2Dproj(shadow_texture, I.screenCoord);
    float shadow = min(shadowTex.x, min(shadowTex.y, shadowTex.z);
  #endif
  shadow = saturate(shadow);
#endif
/*
    lightingLevels lvls = calcLightingLevels(
        nrm.xyz,
        c_dir_obj_nrm.xyz,
        l_dir_obj_nrm.xyz,
        0.75f,
        0.165f,
        1.5f
    );
*/
    float3 col_composed = calcFinalColorNoGlow(
        0.0f,
        1.0f,
        0.0f,
        light_col_amb_composed.xyz,
        light_col_diff.xyz,
        shadow,
        tex0.xyz
    );

  //TEnergy
    sTEnergy tenergy;
    calc_tenergy(tenergy,noise_map,texture2,texture3,I.texcoord0.xy,-I.texcoord0.y,system_data.x);

  //calc fog
#ifdef S2_FOG
    fogDiffuse( col_composed, fog_texture, I.depthFog, fog_color );
#endif

  //set output color
	O.col[0] = float4(col_composed.xyz, tex0.a);
#if TREE_HOLE
      O.col[0].a = calcHoleAlpha(I.hpos,param.x);
#endif  
	  O.col[1] = float4(0.0, 0.0, 0.0, 0.0);
	  
#ifdef USE_TENERGY
//    float tescale = pow(tex0.a,3);
    float tescale = tex0.a * tex0.a;
    O.col[0].xyz += tenergy.color0 * tescale;
    O.col[1].xyz += tenergy.color1 * tescale;
#endif
 
  //calc to-face-lightning
#ifdef SPASS_LIGHTNING
	float is2Lightning = saturate(step(0.2, dot(nrm, I.lightDist.xyz)) + (dot(light_hero.xyz, light_hero.xyz) / sqrt(3.0f)));
	O.col[0] = float4(is2Lightning * light_col_amb.w * float3(1.0, 1.0, 1.0), 1.0);
	O.col[1] = float4(is2Lightning * light_col_amb.w * (light_col_amb.xyz + light_hero.xyz), 0.0);
#endif
#ifdef SIMPLECOLOR
	O.col[0] = float4(1,1,1,1);
#endif

	return O; 
 } 
#endif