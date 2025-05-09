// fur
//#OptDef:SPASS_G
//#OptDef:S2_FOG
//#OptDef:LAYER_BIT0
#include "extractvalues.shader"

#ifdef ENABLE_VERTEX_LIGHTING
    #undef ENABLE_VERTEX_LIGHTING
#endif
#ifdef VERTEX_LIGHTING_NRM
    #undef VERTEX_LIGHTING_NRM
#endif
#ifdef PHONG
    #undef PHONG
#endif
#ifdef SPECULAR_GLOW
    #undef SPECULAR_GLOW
#endif
#define SOFT_FRESNEL
#define OREN_NAYAR
#define TORRANCE_SPARROW
#include "lightingComplex.shader"

#ifdef SM1_1 // no fog in shader model 1
    #ifdef S2_FOG
        #undef S2_FOG
    #endif
#endif

struct appdata {
	float3 position    : POSITION;
	float3 normal      : NORMAL;
	float3 tangent     : TANGENT;
	float3 binormal    : BINORMAL;
	float2 texcoord    : TEXCOORD0;
	float2 data        : TEXCOORD1;
	float  shell       : TEXCOORD2;
};

struct pixdata {
	float4 hposition   : POSITION;
	float4 texcoord0   : TEXCOORD0;
	float4 camDist     : TEXCOORD1;
	float4 lightDist   : TEXCOORD2;
#ifdef SPASS_G
	float4 depthUV     : TEXCOORD3;
#else
	float4 screenCoord : TEXCOORD3;
	float4 lighting    : TEXCOORD4;
#endif
	float4 camDist_ws  : TEXCOORD5;
	float4 pos_ws      : TEXCOORD6;
	float4 surfNrm_ws   : TEXCOORD7;
};



pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix,
  uniform float4x4 worldViewMatrix,
  uniform float4x4 invWorldMatrix,
  uniform float4x4 worldMatrix,
  uniform float4   light_pos,
  uniform float4   camera_pos,
  uniform float4   param,
  uniform float4   zfrustum_data,
  uniform float4   fog_data )
{
	pixdata O;
	
	
	float3 nrm = normalize(I.normal.xyz);
    
	float4 pos4 = float4(I.position.xyz, 1.0f);
	float4 nrm4 = float4(nrm.xyz, 0.0f);

  // names
	float anz_shells = param.x;
	float lowest_shell_darkness = saturate(param.y);
	float weight = param.w;
	float thickness = param.z;

  // modify thickness?
#if LAYER_BIT0
	thickness *= I.data.y;
#endif

  // shells
	float shell = I.shell.x / anz_shells;
  
  //calculate displacement
	float4 gravity = float4(0.0f, 0.0f, -1.0f, 0.0f);
	float4 gravity_obj = mul(gravity, invWorldMatrix);
	float4 gravity_obj_nrm = float4(normalize(gravity_obj.xyz), gravity_obj.w);
    
    float4 component_linear = thickness * nrm4;
    float4 component_squared = (((1.0f - thickness) * weight) / (max((thickness * (1.0f - weight)), 0.01f))) * gravity_obj_nrm;
    float4 displacement = ((component_squared * shell) + component_linear) * shell;
    
  // apply displacement
	pos4 += displacement;

  // vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);

	float camSpaceZ = pos4.x*worldViewMatrix[0][2] +  
                      pos4.y*worldViewMatrix[1][2] + 
                      pos4.z*worldViewMatrix[2][2] + 
                      worldViewMatrix[3][2];

#ifdef SPASS_G

  // calc texturecoords for rg(b)-depth encoding
    O.depthUV = float4(0,0,0, -camSpaceZ*zfrustum_data.w);

  // texture coords
    O.texcoord0 = float4(I.texcoord.xy, shell, 0.0);

#else

  // vertex-position in screen space
    O.screenCoord = calcScreenToTexCoord(O.hposition);

  // build object-to-tangent space matrix
	float3x3 objToTangentSpace;
	objToTangentSpace[0] = -1.0 * I.tangent;
	objToTangentSpace[1] = -1.0 * I.binormal;
	objToTangentSpace[2] = I.normal;

  // convert light direction vector from worldspace to objectspace
	float4 l_dir_obj = mul(light_pos, invWorldMatrix);
    float3 l_dir_obj_nrm = normalize(l_dir_obj.xyz);

  // convert camera direction vector from worldspace to objectspace
	float4 c_dir_obj = mul(camera_pos, invWorldMatrix);
  // calc direction vector from vertex position to camera-position
	c_dir_obj -= pos4;
    float3 c_dir_obj_nrm = normalize(c_dir_obj.xyz);
  
  //calculate tabgent vector
    float3 curve_tangent = component_linear.xyz + ((2.0f * shell) * component_squared.xyz);
    float3 curve_tangent_nrm = normalize(curve_tangent.xyz);
  
  // calc principal normal vector (actually it's the negative principal unit normal vector)
    float3 nrm_unit_principal = normalize((component_squared.xyz) - ((dot(component_squared.xyz, curve_tangent_nrm.xyz)) * curve_tangent_nrm.xyz));
  
  //calc nrm interpolation - the closer to vertex, the more like original normal vector
    float3 nrm_i = normalize(curve_tangent_nrm.xyz + (shell * (nrm_unit_principal.xyz - curve_tangent_nrm.xyz)));
    
  //apply
    nrm4 = float4(nrm_i.xyz, nrm4.w);
    
  //calc lighting
    complexLightingData l;
    l.nrm = nrm_i.xyz;
    l.c_dir_obj_nrm = c_dir_obj_nrm.xyz;
    l.l_dir_obj_nrm = l_dir_obj_nrm.xyz;
    l.roughness = 0.2f;
    l.albedo = 0.3f;
    l.refr_idx = 1.55f;
    
    lightingLevels lvls = calcLightingLevels(l);

  // calc selfshadowning
	float depth_shadow = shell * (1.0f - lowest_shell_darkness) + lowest_shell_darkness;

  // store
	O.lighting = float4(lvls.ambient, lvls.diffuse, lvls.specular, depth_shadow);

  // texture coords
	float4 pos_ws_inp = mul(pos4, worldMatrix);
	O.texcoord0 = float4(I.texcoord.xy, shell, 1.0f);
	O.surfNrm_ws = mul(nrm4, worldMatrix);
	O.camDist_ws = camera_pos - pos_ws_inp;
	O.pos_ws = pos_ws_inp;
#endif

	return O;
}

#ifdef SM1_1
#else

  #ifdef SPASS_G
    struct fragout {
	    float4 col0      : COLOR;
    };
  #else
    struct fragout {
	    float4 col0      : COLOR0;
	    float4 col1      : COLOR1;
    };
  #endif


  fragout mainPS(pixdata I,
      uniform sampler2D   texture0,
      uniform sampler2D   texture1,
      uniform sampler2D   texture2,
      uniform sampler3D   textureVolume,
      uniform sampler2D   shadow_texture,
      uniform sampler2D   gradient_texture,
      uniform sampler2D   fog_texture,
	  uniform samplerCUBE textureCube,
      uniform float4      fog_color,
      uniform float4      light_col_amb,
      uniform float4      light_col_diff)
	  //uniform float4      system_data)
	  //uniform float       sc_time)
  {
    fragout O;

    #ifdef SPASS_G

      // needed cause of alpha!
        s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);

      // sample from fur texture
        s2half4 fur_mask = tex3D(textureVolume, float3(5.0 * I.texcoord0.xy, I.texcoord0.z));
        clip(fur_mask.a * tex0.a - 0.9f);
        O.col0 = float4(I.depthUV.w, 0, 0, 1);

    #else
          
      //float time_current = system_data.x;
      //float time_startofgame = sc_time;

      //get texture values
        s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);

      //sample from fur texture
        s2half4 fur_mask = tex3D(textureVolume, float3(5.0f * I.texcoord0.xy, I.texcoord0.z));
        clip(fur_mask.a * tex0.a - 0.1f);

        s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
        
        float shadow = saturate(I.lighting.w);
        
        coldata c;
        c.ambient = I.lighting.x;
        c.diffuse = I.lighting.y;
        c.specular = I.lighting.z;
        c.shadow = shadow;
        c.light_col_amb = light_col_amb.xyz;
        c.light_col_diff = light_col_diff.xyz;
        c.texBase = tex0;
        c.texGlow = tex1;
        colors composedColors = calcComposeColors(c);

      // out
        O.col0 = composedColors.col_base.xyzw;
        O.col1 = composedColors.col_glow.xyzw;
        
    #endif

	  return O;
  }

#endif
