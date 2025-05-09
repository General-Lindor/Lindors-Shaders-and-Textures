/*

Refractive Index

Air:                1.0
Water:              1.0
Ice:                1.31
Tree Leaf:          1.35  - 1.47
Tree trunk:         1.4   - 1.6
glass               1.45  - 2.14
Animal Fur Hair:    1.54  - 1.56
Human Hair:         1.54  - 1.56
Quartz Crystal:     1.54
diamond             2.42
steel               2.757 - 3.792
chromium            3.136 - 3.312

*/

/*

Albedo

Water:      0.05
Forest:     0.15 - 0.18
Grass:      0.25
Sand:       0.4
Ice:        0.5
Snow:       0.8
Aluminium:  0.85

*/

/*
Literature:
    General:
        https://en.wikipedia.org/wiki/List_of_common_shading_algorithms
        https://en.wikipedia.org/wiki/Refractive_index
        https://en.wikipedia.org/wiki/Albedo
    Diffuse:
        Lambertian:
            https://en.wikipedia.org/wiki/Lambertian_reflectance
        Oren-Nayar:
            https://en.wikipedia.org/wiki/Oren%E2%80%93Nayar_reflectance_model
            https://mimosa-pudica.net/improved-oren-nayar.html
    Specular:
        Phong and Blinn-Phong:
            https://en.wikipedia.org/wiki/Phong_shading
            https://en.wikipedia.org/wiki/Blinn%E2%80%93Phong_reflection_model
        Torrance-Sparrow / Cook-Torrance:
            https://en.wikipedia.org/wiki/Specular_highlight#Cook%E2%80%93Torrance_model
            https://en.wikipedia.org/wiki/Specular_highlight#Beckmann_distribution
            https://en.wikipedia.org/wiki/Schlick%27s_approximation
*/

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// SETUP //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#ifndef ENABLE_VERTEX_LIGHTING
    #ifdef VERTEX_LIGHTING_NRM
        #undef VERTEX_LIGHTING_NRM
    #endif
#endif

#ifdef TORRANCE_SPARROW
    #ifdef PHONG
        #undef PHONG
    #endif
#endif

// Global Singleton (not actually, but treat it as one)
struct shaderContext {
    // READ
    float PI;
    float E;
    
    // READ - WRITE
    float3 NORMAL;
    float3 CAMERA;
    float C_SIN;
    float C_COS;
    float C_TAN;
    float ROUGHNESS;
    float ALBEDO;
    float REFR_IDX;
};

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// DIFFUSE ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////////
// LAMBERTIAN (DEFAULT) //
//////////////////////////

//Diffuse Model: Lambertian
float calcLambertian(shaderContext context, float3 light_normal) {
    //calc
    float l_cos = dot(context.NORMAL, light_normal);
    float diffuse = context.ALBEDO * l_cos;
    
    //out
    return diffuse;
};

////////////////
// OREN-NAYAR //
////////////////

//Diffuse Model: Oren-Nayar
float calcOrenNayar(shaderContext context, float3 light_normal) {
    //light vector
    float l_dot = dot(context.NORMAL, light_normal);
    float3 l_cross = cross(context.NORMAL, light_normal);
    
    float l_sin = sqrt(dot(l_cross, l_cross));
    float l_cos = l_dot;
    float l_tan = l_sin / l_cos;
    
    //calculation
    float3 a_vec = l_cross / l_sin;
    float3 b_vec = cross(context.NORMAL, a_vec);
    float3 l_proj = dot(b_vec, light_normal) * b_vec;
    float3 c_proj = (dot(a_vec, context.CAMERA) * a_vec) + (dot(b_vec, context.CAMERA) * b_vec);
    
    float both_cos = dot(l_proj, c_proj) / (sqrt(dot(l_proj, l_proj) * dot(c_proj, c_proj)));
    
    float r_scal = context.ROUGHNESS * context.ROUGHNESS;
    float A_scal = 1.0f - (0.5f * (r_scal / (r_scal + 0.33f)));
    float B_scal = 0.45f * (r_scal / (r_scal + 0.09f));
    
    float diffuse = (context.ALBEDO / context.PI) * l_cos * (A_scal + (B_scal * max(0.0f, both_cos) * max(l_sin, context.C_SIN) * min(l_tan, context.C_TAN)));
    
    //out
    return diffuse;
};

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// SPECULAR ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////
// PHONG-BLINN (DEFAULT) //
///////////////////////////

//Specular Model: Phong-Blinn
float calcPhongBlinn(shaderContext context, float3 light_normal) {
            
    //half angle vector
    float3 half_normal = normalize(context.CAMERA + light_normal);
    float h_cos = dot(half_normal, context.NORMAL);
    
    float basis = h_cos;
    float exponent = (1.0f - context.ROUGHNESS) / context.ROUGHNESS;
    float normalization = (exponent + 2.0f) / (2.0f * context.PI);
    
    basis = abs(basis);
    
    //calc
    float specular = normalization * (pow(basis, exponent));
    
    //out
    return specular;
};

///////////
// PHONG //
///////////

//Specular Model: Phong
float calcPhong(shaderContext context, float3 light_normal) {
    // setup
    float l_cos = dot(light_normal, context.NORMAL);
    
    float basis = dot(context.CAMERA, ((2.0f * l_cos * context.NORMAL) - light_normal));
    float exponent = (1.0f - context.ROUGHNESS) / context.ROUGHNESS;
    float normalization = (exponent + 2.0f) / (2.0f * context.PI);
    
    basis = abs(basis);
    
    // calc
    float specular = normalization * (pow(basis, exponent));
    
    // out
    return specular;
};

//////////////////////
// TORRANCE-SPARROW //
//////////////////////

//Fresnel (Schlick's Approximation)
float calcFresnel(shaderContext context, float c_h_cos) {
    //The refractive index of air approximately equals 1.0f. The refraction is the minimum amount of reflection happening when the light vector equals the viewing vector.
    float refraction = (1.0f - context.REFR_IDX) / (1.0f + context.REFR_IDX);
    refraction *= refraction;
    
    //calc
    float basis = abs(1.0f - c_h_cos);
    float value = pow(basis, 5);
    float fresnel = lerp(refraction, 1.0f, value);
    
    //out
    return fresnel;
};

//Inverse of the Beckmann Distribution
float calcBeckmannInverse(shaderContext context, float h_cos) {
    //setup
    float m = (2.0f * context.ROUGHNESS) / (1.0f + context.ROUGHNESS);
    
    float h_cos_sq = h_cos * h_cos;
    float h_cos_sq_sq = h_cos_sq * h_cos_sq;
    
    //calcuation
    float exponent = (1.0f - h_cos_sq) / (h_cos_sq * m);
    float beckmannInverse = context.PI * m * h_cos_sq_sq * (pow(context.E, exponent));
    
    //out
    return beckmannInverse;
};

//Geometric Attenuation
float calcGeometricAttenuation(shaderContext context, float l_cos, float h_cos, float c_h_cos) {
    float factor = (2.0f * h_cos) / c_h_cos;
    float geometricAttenuation = min(1.0f, min((factor * l_cos), (factor * context.C_COS)));
    
    //out
    return geometricAttenuation;
};

//Specular Model: Torrance-Sparrow / Cook-Torrance
float calcTorranceSparrow(shaderContext context, float3 light_normal) {
    //setup
    float l_cos = dot(light_normal, context.NORMAL);
    float3 half_normal = normalize(light_normal + context.CAMERA);
    float h_cos = dot(half_normal, context.NORMAL);
    float c_h_cos = dot(half_normal, context.CAMERA);
    
    //Numerator
    float fresnel = calcFresnel(context, c_h_cos);
    float geometricAttenuation = calcGeometricAttenuation(context, l_cos, h_cos, c_h_cos);
    float numerator = fresnel * geometricAttenuation;
    
    //Denominator
    float beckmannInverse = calcBeckmannInverse(context, h_cos);
    float denominator = 4.0f * beckmannInverse * context.C_COS * l_cos;
    
    //result
    float specular = numerator / denominator;
    
    //out
    return specular;
};

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// CALCULATION CONTROLLER /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

///////////
// SETUP //
///////////

//Input
struct complexLightingData {
    float3 nrm;
    float3 c_dir_obj_nrm;
    float3 l_dir_obj_nrm;
    #ifdef VERTEX_LIGHTING_NRM
        float3 v_dir_obj_nrm;
    #endif
    float roughness;
    float albedo;
    float refr_idx;
};

//Output
struct lightingLevels {
    float diffuse;
    float specular;
    #ifdef VERTEX_LIGHTING_NRM
        float diffuse_vertex;
        float specular_vertex;
    #endif
};

//Setup Global Variables
shaderContext constructContext(complexLightingData I) {
    //init
    shaderContext context;
    
    //constant
    context.PI = 3.14159265f;
    context.E = 2.71828183f;
    
    //vector
    context.NORMAL = I.nrm;
    context.CAMERA = I.c_dir_obj_nrm;
    
    //camera angles
    float c_dot = dot(context.NORMAL, context.CAMERA);
    float c_cross = cross(context.NORMAL, context.CAMERA);
    context.C_SIN = sqrt(dot(c_cross, c_cross));
    context.C_COS = c_dot;
    context.C_TAN = context.C_SIN / context.C_COS;
    
    //material properties
    context.ROUGHNESS = I.roughness * I.roughness;
    context.ALBEDO = I.albedo;
    context.REFR_IDX = I.refr_idx;
    
    return context;
};

////////////////
// CONTROLLER //
////////////////

lightingLevels calcLightingLevels(complexLightingData I) {
    //Setup
    lightingLevels O;
    shaderContext context = constructContext(I);
    float3 light_normal = I.l_dir_obj_nrm;
    #ifdef VERTEX_LIGHTING_NRM
        float3 light_vertex_normal = I.v_dir_obj_nrm;
    #endif

    //Diffuse
    #ifdef OREN_NAYAR
        float out_diffuse = calcOrenNayar(context, light_normal);
        #ifdef VERTEX_LIGHTING_NRM
            float out_diffuse_vertex = calcOrenNayar(context, light_vertex_normal);
        #endif
    #else
        float out_diffuse = calcLambertian(context, light_normal);
        #ifdef VERTEX_LIGHTING_NRM
            float out_diffuse_vertex = calcLambertian(context, light_vertex_normal);
        #endif
    #endif

    //Specular
    #ifdef TORRANCE_SPARROW
        float out_specular = calcTorranceSparrow(context, light_normal);
        #ifdef VERTEX_LIGHTING_NRM
            float out_specular_vertex = calcTorranceSparrow(context, light_vertex_normal);
        #endif
    #elif defined(PHONG)
        float out_specular = calcPhong(context, light_normal);
        #ifdef VERTEX_LIGHTING_NRM
            float out_specular_vertex = calcPhong(context, light_vertex_normal);
        #endif
    #else
        float out_specular = calcPhongBlinn(context, light_normal);
        #ifdef VERTEX_LIGHTING_NRM
            float out_specular_vertex = calcPhongBlinn(context, light_vertex_normal);
        #endif
    #endif
    
    //Out
    O.diffuse = saturate(abs(out_diffuse));
    O.specular = saturate(abs(out_specular));
    #ifdef VERTEX_LIGHTING_NRM
        O.diffuse_vertex = saturate(abs(out_diffuse_vertex));
        O.specular_vertex = saturate(abs(out_specular_vertex));
    #endif
    return O;
        
};

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// COMPOSITION CONTROLLER /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//Input
struct coldata {
    float diffuse;
    float specular;
    float shadow;
    #ifdef ENABLE_VERTEX_LIGHTING
        #ifdef VERTEX_LIGHTING_NRM
            float diffuse_vertex;
            float specular_vertex;
        #endif
        float3 light_col_hero;
        float3 light_col_vertex;
    #endif
    float3 light_col_amb;
    float3 light_col_diff;
    float4 texBase;
    float4 texGlow;
};

//Output
struct colors {
    float4 col_base;
    float4 col_glow;
};

colors calcComposeColors(coldata I) {
    //define out
    colors O;
    
    //setup components
    float3 col_amb  = saturate(abs(I.shadow * I.light_col_amb * I.texBase.xyz));
    float3 col_diff = saturate(abs(I.diffuse * I.shadow * I.light_col_diff * I.texBase.xyz));
    float3 col_spec = saturate(abs(I.specular * I.shadow * I.light_col_diff * I.texBase.xyz));
    
    #ifdef ENABLE_VERTEX_LIGHTING
        float3 col_amb_hero  = saturate(abs(I.light_col_hero * I.texBase.xyz));
        #ifdef VERTEX_LIGHTING_NRM
            float3 col_diff_hero  = saturate(abs(I.diffuse_vertex * I.light_col_hero * I.texBase.xyz));
            float3 col_spec_hero  = saturate(abs(I.specular_vertex * I.light_col_hero * I.texBase.xyz));
        #endif
    #endif
        
    #ifdef ENABLE_VERTEX_LIGHTING
        float3 col_amb_vertex  = saturate(abs(I.light_col_vertex * I.texBase.xyz));
        #ifdef VERTEX_LIGHTING_NRM
            float3 col_diff_vertex = saturate(abs(I.diffuse_vertex * I.light_col_vertex * I.texBase.xyz));
            float3 col_spec_vertex = saturate(abs(I.specular_vertex * I.light_col_vertex * I.texBase.xyz));
        #endif
    #endif
    
    //compose base colors
    float3 univec = float3(1.0f, 1.0f, 1.0f);
    
    float3 rgb_light = univec;
    rgb_light *= (univec - col_amb);
    rgb_light *= (univec - col_diff);
    rgb_light *= (univec - col_spec);
    rgb_light = univec - rgb_light;
    
    float red = rgb_light.x;
    float green = rgb_light.y;
    float blue = rgb_light.z;
    
    #ifdef ENABLE_VERTEX_LIGHTING
        float3 rgb_hero = univec;
        rgb_hero *= (univec - col_amb_hero);
        #ifdef VERTEX_LIGHTING_NRM
            rgb_hero *= (univec - col_diff_hero);
            rgb_hero *= (univec - col_spec_hero);
        #endif
        rgb_hero = univec - rgb_hero;
        red = max(red, rgb_hero.x);
        green = max(green, rgb_hero.y);
        blue = max(blue, rgb_hero.z);
    #endif
    
    #ifdef ENABLE_VERTEX_LIGHTING
        float3 rgb_vertex = univec;
        rgb_vertex *= (univec - col_amb_vertex);
        #ifdef VERTEX_LIGHTING_NRM
            rgb_vertex *= (univec - col_diff_vertex);
            rgb_vertex *= (univec - col_spec_vertex);
        #endif
        rgb_vertex = univec - rgb_vertex;
        red = max(red, rgb_vertex.x);
        green = max(green, rgb_vertex.y);
        blue = max(blue, rgb_vertex.z);
    #endif
    
    //colors
    float3 rgb_base = float3(red, green, blue);
    float3 rgb_glow = I.texGlow.xyz;
    
    //alpha
    float alpha_base = I.texBase.w;
    float alpha_glow = I.texGlow.w;
    
    //clamp
    rgb_base = saturate(abs(rgb_base));
    rgb_glow = saturate(abs(rgb_glow));
    alpha_base = saturate(abs(alpha_base));
    alpha_glow = saturate(abs(alpha_glow));
    
    //out
    O.col_base = float4(rgb_base.xyz, alpha_base);
    O.col_glow = float4(rgb_glow.xyz, alpha_glow);
    return O;
};