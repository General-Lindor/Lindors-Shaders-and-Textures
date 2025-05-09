// fur
//#OptDef:SPASS_G
//#OptDef:S2_FOG
//#OptDef:LAYER_BIT0
#include "extractvalues.shader"
#include "lighting.shader"

#define ENABLE_VERTEX_LIGHTING
#define VERTEX_LIGHTING_NRM
#define OREN_NAYAR
#ifdef PHONG
    #undef PHONG
#endif
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
        float4 hposition        : POSITION;
        float4 texcoord0        : TEXCOORD0;
        float4 camDist          : TEXCOORD1;
        float4 lightDist        : TEXCOORD2;
        float roughness         : TEXCOORD3;
#ifdef SPASS_G
        float4 depthUV          : TEXCOORD4;
#else
        float4 screenCoord      : TEXCOORD4;
#endif
        float3 principal        : TEXCOORD5;
        float3 tangential       : TEXCOORD6;
        //float4 normal           : TEXCOORD5;
        //float4 camDist_ws       : TEXCOORD5;
        //float4 pos_ws           : TEXCOORD6;
        //float4 surfNrm_ws       : TEXCOORD7;
#ifdef ENABLE_VERTEX_LIGHTING
        float4 vlColor          : COLOR0;
    #ifdef VERTEX_LIGHTING_NRM
        float4 vlNormal         : TEXCOORD7;
    #endif
#endif
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
	float shell = I.shell / anz_shells;
  
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
    O.lightDist = float4(l_dir_obj_nrm.xyz, l_dir_obj.w);

  // convert camera direction vector from worldspace to objectspace
	float4 c_dir_obj = mul(camera_pos, invWorldMatrix);
  // calc direction vector from vertex position to camera-position
	c_dir_obj -= pos4;
    float3 c_dir_obj_nrm = normalize(c_dir_obj.xyz);
    O.camDist = float4(c_dir_obj_nrm.xyz, c_dir_obj.w);
  
  //calculate tangent vector (parallel transport)
    float3 curve_tangent  = component_linear.xyz + ((2.0f * shell) * component_squared.xyz);
    float3 nrm_tangential = normalize(curve_tangent.xyz);
  
  // calc principal normal vector (actually it's the negative principal unit normal vector)
    float3 nrm_principal = normalize((component_squared.xyz) - ((dot(component_squared.xyz, nrm_tangential.xyz)) * nrm_tangential.xyz));
  
  //calc nrm interpolation - the closer to vertex, the more like original normal vector
    //float3 nrm_i = normalize(nrm_tangential.xyz + (shell * (nrm_principal.xyz - nrm_tangential.xyz)));
    
  //apply
    //nrm4 = float4(nrm_i.xyz, nrm4.w);
    //O.normal = float4(nrm_i.xyz, nrm4.w);
    O.tangential = nrm_tangential.xyz;
    O.principal  = nrm_principal.xyz;

  // calc selfshadowning
	float depth_shadow = shell * (1.0f - lowest_shell_darkness) + lowest_shell_darkness;

  // store
	//O.lighting = float4(lvls.ambient, lvls.diffuse, lvls.specular, depth_shadow);

  // texture coords
	//float4 pos_ws_inp = mul(pos4, worldMatrix);
	O.texcoord0 = float4(I.texcoord.xy, shell, depth_shadow);
	//O.surfNrm_ws = mul(nrm4, worldMatrix);
	//O.camDist_ws = camera_pos - pos_ws_inp;
	//O.pos_ws = pos_ws_inp;


    #ifdef ENABLE_VERTEX_LIGHTING
        #ifdef VERTEX_LIGHTING_NRM
            computeVertexLightingColorNormal(O.vlColor, O.vlNormal, pos4);
        #else
            float4 dummy;
            computeVertexLightingColorNormal(O.vlColor, dummy, pos4);
        #endif
        //O.vlColor = computeVertexLightingColor(pos4,nrm4);
    #endif
    
    //O.roughness = thickness / (1.0f + (anz_shells / 24.0f));
    float t = saturate(thickness);
    float s = saturate(shell);
    O.roughness = saturate(lerp((t / anz_shells), t, (1.0f - s)));
    //O.roughness = thickness / I.shell;
    //O.roughness = thickness / anz_shells;
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
        
      //shadow
        //float shadow = saturate(I.lighting.w);
        float shadow = saturate(I.texcoord0.w);
        
      //normal vector:
        //step1: use Rodrigues' rotation formula to rotate the principal around the tangential by phi degrees
        //step2: solve for phi so that it minimizes the angle between the rotated normal vector and the halfway vector
        //result is the formula below
        float3 cr = cross(I.tangential.xyz, I.principal.xyz);
        float3 h = normalize(I.camDist.xyz + I.lightDist.xyz);
        
        float d_h_cr = dot(h, cr);
        float d_h_p  = dot(h, I.principal.xyz);
        
        float q_p  = d_h_cr / d_h_p;
        float q_cr = d_h_p  / d_h_cr;
        
        float f_p  = sqrt(1.0f + (q_p  * q_p ));
        float f_cr = sqrt(1.0f + (q_cr * q_cr));
        
        float3 n = ((1.0f / f_p) * I.principal.xyz) + ((1.0f / f_cr) * cr);
        //should already be normalized, but just to be sure...
        float3 nrm = normalize(n);
    
      //calc lighting
        complexLightingData l;
        l.color = tex0.xyz;
        l.nrm = nrm;
        l.c_dir_obj_nrm = I.camDist.xyz;
        l.l_dir_obj_nrm = I.lightDist.xyz;
        l.refr_idx = 3.0f;
        l.roughness = I.roughness;
        //l.albedo = 0.3f;
        #ifdef VERTEX_LIGHTING_NRM
            l.v_dir_obj_nrm = normalize(I.vlNormal.xyz);
        #endif
        
        lightingLevels lvls = calcLightingLevels(l);
    
        coldata c;
        c.ambient = lvls.ambient;
        c.diffuse = lvls.diffuse;
        c.specular = lvls.specular;
        c.shadow = shadow;
        c.light_col_amb = light_col_amb.xyz;
        c.light_col_diff = light_col_diff.xyz;
        c.texBase = tex0;
        c.texGlow = tex1;
        #ifdef ENABLE_VERTEX_LIGHTING
            #ifdef VERTEX_LIGHTING_NRM
                c.diffuse_vertex = lvls.diffuse_vertex;
                c.specular_vertex = lvls.specular_vertex;
            #endif
            c.light_col_vertex = (I.vlColor).xyz;
            c.light_col_hero = (light_calc_heroLight(I.vlColor)).xyz;
        #endif
        colors composedColors = calcComposeColors(c);

      // out
        O.col0 = composedColors.col_base.xyzw;
        O.col1 = composedColors.col_glow.xyzw;
        
    #endif

	  return O;
  }

#endif
