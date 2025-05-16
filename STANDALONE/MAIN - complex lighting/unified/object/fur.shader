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

// #ifdef OREN_NAYAR
    // #undef OREN_NAYAR
// #endif
// #ifdef TORRANCE_SPARROW
    // #undef TORRANCE_SPARROW
// #endif
// #define PHONG


#include "lightingComplex.shader"

// no fog in shader model 1
#ifdef SM1_1
    #ifdef S2_FOG
        #undef S2_FOG
    #endif
#endif

struct appdata {
    float3 position : POSITION;
    float3 normal   : NORMAL;
    float3 tangent  : TANGENT;
    float3 binormal : BINORMAL;
    float2 texcoord : TEXCOORD0;
    float2 data     : TEXCOORD1;
    float  shell    : TEXCOORD2;
};

struct pixdata {
    float4 hposition        : POSITION;
    float4 texcoord0        : TEXCOORD0;
    float4 camDist          : TEXCOORD1;
    float4 lightDist        : TEXCOORD2;
    float roughness         : TEXCOORD3;
    #ifdef SPASS_G
        float4 depthUV      : TEXCOORD4;
    #else
        float4 screenCoord  : TEXCOORD4;
    #endif
    float3 principal        : TEXCOORD5;
    float3 tangential       : TEXCOORD6;
    #ifdef ENABLE_VERTEX_LIGHTING
        float4 vlColor      : COLOR0;
        #ifdef VERTEX_LIGHTING_NRM
            float4 vlNormal : TEXCOORD7;
        #endif
    #endif
};

pixdata mainVS(
            appdata  I,
    uniform float4x4 worldViewProjMatrix,
    uniform float4x4 worldViewMatrix,
    uniform float4x4 invWorldMatrix,
    uniform float4x4 worldMatrix,
    uniform float4   light_pos,
    uniform float4   camera_pos,
    uniform float4   param,
    uniform float4   zfrustum_data,
    uniform float4   fog_data
) {
	pixdata O;
	
	//vertex propeties
	float3 nrm  = normalize(I.normal.xyz);
	float4 pos4 = float4(I.position.xyz, 1.0f);
	float4 nrm4 = float4(nrm.xyz, 0.0f);

    //general hair properties
	float anz_shells = max(param.x, 0);
	float lowest_shell_darkness = saturate(param.y);
	float weight = saturate(param.w);
	float thickness = param.z;

    //modify thickness?
    #if LAYER_BIT0
        thickness *= I.data.y;
    #endif
    thickness = saturate(thickness);
    
    //curve & shell properties
    float M     = 3.14159265f * pow(thickness, 4) / 32; //the "second polar moment of area" of a filled circle
    float F     = 9.81f * weight;                       //newton force
    float E     = 6;                                    //Young's modulus (stiffness); value range for human hair ~ 3.727 - 6.0
    float U     = 0.1f;                                 //length per unit (arbitrary parameter)
    float L     = anz_shells * U;                       //total length
    float S     = I.shell * U;                          //current length
    float shell = saturate(I.shell / anz_shells);       //current percentage length
  
    //calculate displacement
    float4 gravity         = float4(0.0f, 0.0f, -1.0f, 0.0f);
    float4 gravity_obj     = mul(gravity, invWorldMatrix);
    float4 gravity_obj_nrm = gravity_obj / sqrt(dot(gravity_obj.xyz, gravity_obj.xyz));

    float fac = F / (24 * E * M);
    float4 f1 = nrm4;
    float4 f2 = fac * 6 * L * L * gravity_obj_nrm;
    float4 f3 = (0.0f - fac) * 4 * L * gravity_obj_nrm;
    float4 f4 = fac * gravity_obj_nrm;
    
    float4 v1 = f1 * S;
    float4 v2 = f2 * S * S;
    float4 v3 = f3 * S * S * S;
    float4 v4 = f4 * S * S * S * S;
    
    float4 displacement = v1 + v2 + v3 + v4;
    
    //apply displacement
    pos4 += displacement;

    //vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);

	float camSpaceZ = pos4.x * worldViewMatrix[0][2] +  
                      pos4.y * worldViewMatrix[1][2] + 
                      pos4.z * worldViewMatrix[2][2] + 
                               worldViewMatrix[3][2];

    #ifdef SPASS_G
        //calc texturecoords for rg(b)-depth encoding
        O.depthUV = float4(0, 0, 0, -camSpaceZ * zfrustum_data.w);

        //texture coords
        O.texcoord0 = float4(I.texcoord.xy, shell, 0.0);
    #else
        //vertex-position in screen space
        O.screenCoord = calcScreenToTexCoord(O.hposition);

        //build object-to-tangent space matrix
        float3x3 objToTangentSpace;
        objToTangentSpace[0] = -1.0f * I.tangent;
        objToTangentSpace[1] = -1.0f * I.binormal;
        objToTangentSpace[2] =         I.normal;

        //convert light direction vector from worldspace to objectspace
        float4 l_dir_obj     = mul(light_pos, invWorldMatrix);
        float4 l_dir_obj_nrm = l_dir_obj / sqrt(dot(l_dir_obj.xyz, l_dir_obj.xyz));
        O.lightDist          = l_dir_obj_nrm;

        //convert camera direction vector from worldspace to objectspace
        float4 c_dir_obj     = mul(camera_pos, invWorldMatrix) - pos4;
        float4 c_dir_obj_nrm = c_dir_obj / sqrt(dot(c_dir_obj.xyz, c_dir_obj.xyz));
        O.camDist            = c_dir_obj_nrm;

        //calculate tangential normal vector (parallel transport the vertex normal along the hair curve)
        float3 dv1 =     f1.xyz;
        float3 dv2 = 2 * f2.xyz * S;
        float3 dv3 = 3 * f3.xyz * S * S;
        float3 dv4 = 4 * f4.xyz * S * S * S;

        float3 tangent_vec = dv1 + dv2 + dv3 + dv4;
        float  tangent_dot = dot(tangent_vec, tangent_vec);
        float  tangent_len = sqrt(tangent_dot);
        O.tangential       = normalize(tangent_vec);

        //calc principal normal vector
        float3 ddv1 =  2 * f2.xyz;
        float3 ddv2 =  6 * f3.xyz * S;
        float3 ddv3 = 12 * f4.xyz * S * S;

        float3 tangent_prime     = ddv1 + ddv2 + ddv3;
        float  tangent_len_prime = dot(tangent_vec, tangent_prime) / tangent_len;
        float3 principal_vec     = ((tangent_len * tangent_prime) - (tangent_len_prime * tangent_vec)) / tangent_dot;
        O.principal              = normalize(principal_vec);

        //calc selfshadowning
        float depth_shadow = lerp(lowest_shell_darkness, 1.0f, shell);

        //texture coords
        O.texcoord0 = float4(I.texcoord.xy, shell, depth_shadow);
        
        //vertex lighting
        #ifdef ENABLE_VERTEX_LIGHTING
            #ifdef VERTEX_LIGHTING_NRM
                computeVertexLightingColorNormal(O.vlColor, O.vlNormal, pos4);
            #else
                float4 dummy;
                computeVertexLightingColorNormal(O.vlColor, dummy, pos4);
            #endif
        #endif

        //roughness
        
        float roughness = abs(thickness) / (1 + abs(S));
        O.roughness = saturate(roughness);
    #endif
    
    //out
	return O;
};

#ifdef SM1_1
#else
    #ifdef SPASS_G
        struct fragout {
            float4 col0 : COLOR;
        };
    #else
        struct fragout {
            float4 col0 : COLOR0;
            float4 col1 : COLOR1;
        };
    #endif

    fragout mainPS(
                pixdata     I,
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
        uniform float4      light_col_diff
    ) {
        fragout O;

        #ifdef SPASS_G
            //needed cause of alpha!
            s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);

            //sample from fur texture
            s2half4 fur_mask = tex3D(textureVolume, float3(5.0 * I.texcoord0.xy, I.texcoord0.z));
            clip(fur_mask.a * tex0.a - 0.9f);
            O.col0 = float4(I.depthUV.w, 0, 0, 1);
        #else
            //get standard texture values
            s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);

            //sample from fur texture
            s2half4 fur_mask = tex3D(textureVolume, float3(5.0f * I.texcoord0.xy, I.texcoord0.z));
            clip(fur_mask.a * tex0.a - 0.1f);
            
            //get glow texture values
            s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);

            //shadow
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

            //calc lighting levels
            complexLightingData l;
            l.color = tex0.xyz;
            l.nrm = nrm;
            l.c_dir_obj_nrm = I.camDist.xyz;
            l.l_dir_obj_nrm = I.lightDist.xyz;
            l.refr_idx = 3.0f;
            l.roughness = I.roughness;
            #ifdef VERTEX_LIGHTING_NRM
                l.v_dir_obj_nrm = normalize(I.vlNormal.xyz);
            #endif
            lightingLevels lvls = calcLightingLevels(l);

            //compose to colors
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

            //out
            O.col0 = composedColors.col_base.xyzw;
            O.col1 = composedColors.col_glow.xyzw;
        #endif

        return O;
    };
#endif
