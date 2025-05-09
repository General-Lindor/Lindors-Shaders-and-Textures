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
            https://computergraphics.stackexchange.com/questions/3946/correct-specular-term-of-the-cook-torrance-torrance-sparrow-model
*/

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// SETUP //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// EnsurePrecompilation Consistency
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

// Global Constants
uniform float const_pi = 3.14159265f;
uniform float const_e = 2.71828183f;
#ifdef SMOOTH_COMPOSE
    uniform float3 univec = float3(1.0f, 1.0f, 1.0f);
#endif
uniform float3 gamma_correction = float3(0.2126f, 0.7152f, 0.0722f);

// Global Variables
    // normal vector
    float3 normal;

    // camera vector
    float3 camera_vector_normal;

    float c_sin;
    float c_cos;
    float c_tan;

    // material properties
    float roughness;
    float albedo;
    float refr_idx;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// DIFFUSE ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Diffuse Model: Lambertian
float calcLambertian() {
    float diffuse = saturate(c_cos);
    return diffuse;
};

// Diffuse Model: Oren-Nayar
float calcOrenNayar(float3 light_vector_normal) {
        
    // light vector
    float l_dot = dot(normal, light_vector_normal);
    float3 l_cross = cross(normal, light_vector_normal);
  
    float l_sin = sqrt(dot(l_cross, l_cross));
    float l_cos = l_dot;
    float l_tan = l_sin / l_cos;
    
    // calculation
    float3 a_vec = l_cross / l_sin;
    float3 b_vec = cross(normal, a_vec);
    float3 l_proj = dot(b_vec, light_vector_normal) * b_vec;
    float3 c_proj = (dot(a_vec, camera_vector_normal) * a_vec) + (dot(b_vec, camera_vector_normal) * b_vec);
  
    float both_cos = dot(l_proj, c_proj) / (sqrt(dot(l_proj, l_proj) * dot(c_proj, c_proj)));
  
    float r_scal = roughness * roughness;
    float A_scal = 1.0f - (0.5f * (r_scal / (r_scal + 0.33f)));
    float B_scal = 0.45f * (r_scal / (r_scal + 0.09f));
  
    float diffuse = (albedo / const_pi) * l_cos * (A_scal + (B_scal * max(0.0f, both_cos) * max(l_sin, c_sin) * min(l_tan, c_tan)));
    //diffuse = saturate(diffuse);
    
    // out
    return diffuse;
};

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// SPECULAR ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

///////////
// PHONG //
///////////

// Specular Model: Phong
float calcPhong(float3 light_vector_normal) {
    // setup
    float l_cos = dot(light_vector_normal, normal);
    
    float basis = dot(camera_vector_normal, ((2.0f * l_cos * normal) - light_vector_normal));
    float exponent = (1 - roughness) * roughness;
    float normalization = (exponent + 2.0f) / (2.0f * const_pi);
    
    basis = abs(basis);
    exponent = abs(exponent);
    normalization = abs(normalization);
    
    // calc
    float specular = normalization * (pow(basis, exponent));
    
    // out
    //specular = saturate(specular);
    return specular;
};

/////////////////
// PHONG-BLINN //
/////////////////

// Specular Model: Phong-Blinn
float calcPhongBlinn(float3 light_vector_normal) {
            
    //half angle vector
    float3 half_vector_normal = normalize(camera_vector_normal + light_vector_normal);
    float h_cos = dot(half_vector_normal, normal);
    
    float basis = h_cos;
    float exponent = (1 - roughness) * roughness;
    float normalization = (exponent + 2.0f) / (2.0f * const_pi);
    
    basis = abs(basis);
    exponent = abs(exponent);
    normalization = abs(normalization);
    
    // calc
    float specular = normalization * (pow(basis, exponent));
    
    // out
    //specular = saturate(specular);
    return specular;
};

//////////////
// TORRANCE //
//////////////

// Fresnel (Schlick's Approximation)
float calcFresnel(float c_l_h_cos) {
    
    // //cos of angle between light and camera
    // float cos_theta = dot(camera_vector_normal, light_vector_normal);
    // //formula: cos(x/2) = sqrt((cos(x) + 1) / 2) for -pi <= x <= pi
    // float c_l_h_cos = sqrt((cos_theta + 1.0f) * 0.5f);
    
    // The refractive index of air approximately equals 1.0f
    float r_theta = (1.0f - refr_idx) / (1.0f + refr_idx);
    r_theta *= r_theta;
    float fresnel = r_theta + ((1.0f - r_theta) * pow((1.0f - c_l_h_cos), 5));
    
    // out
    //fresnel = saturate(fresnel);
    return fresnel;
};

// Inverse of the Beckmann Distribution
float calcBeckmannInverse(float h_cos) {
    // Constants setup
    float m = (2.0f * roughness) / (1.0f + roughness);
    
    float h_cos_sq = h_cos * h_cos;
    float h_cos_sq_sq = h_cos_sq * h_cos_sq;
    
    // calcuation
    float exponent = (1.0f - h_cos_sq) / (h_cos_sq * m);
    float beckmannInverse = const_pi * m * h_cos_sq_sq * (pow(const_e, exponent));
    
    // out
    //beckmannInverse = saturate(beckmannInverse);
    return beckmannInverse;
};

// Geometric Attenuation
float calcGeometricAttenuation(float l_cos, float h_cos, float c_l_h_cos) {
    float factor = (2.0f * h_cos) / c_l_h_cos;
    float geometricAttenuation = min(1.0f, min((factor * l_cos), (factor * c_cos)));
    
    // out
    //geometricAttenuation = saturate(geometricAttenuation);
    return geometricAttenuation;
};

// Specular Model: Torrance-Sparrow / Cook-Torrance
float calcTorranceSparrow(float3 light_vector_normal) {
    //setup
        
        //light vector
        float l_cos = dot(light_vector_normal, normal);
            
        //half angle vector
        float3 half_vector_normal = normalize(camera_vector_normal + light_vector_normal);
        float h_cos = dot(half_vector_normal, normal);
        
        //half angle between light and camera; doesn't matter wether to dot with camera or light
        //float c_l_h_cos = dot(half_vector_normal, light_vector_normal);
        float c_l_h_cos = dot(half_vector_normal, camera_vector_normal);
        
        
    //Numerator
    float fresnel = calcFresnel(c_l_h_cos);
    float geometricAttenuation = calcGeometricAttenuation(l_cos, h_cos, c_l_h_cos);
    float numerator = fresnel * geometricAttenuation;
    
    //Denominator
    float beckmannInverse = calcBeckmannInverse(h_cos);
    float denominator = 4.0f * beckmannInverse * c_cos * l_cos;
    
    // calc
    float specular = numerator / denominator;
    
    //out
    //specular = saturate(specular);
    return specular;
};

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// CALCULATION CONTROLLER /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

///////////
// SETUP //
///////////

// Calculation Input
struct complexLightingData {
    float3 nrm;
    #ifdef ENABLE_VERTEX_LIGHTING
        float3 nrm_vertex;
    #endif
    float3 c_dir_obj_nrm;
    float3 l_dir_obj_nrm;
    float roughness;
    float albedo;
    float refr_idx;
};

// Calculation Output
struct lightingLevels {
    float ambient;
    float diffuse;
    float specular;
    #ifdef ENABLE_VERTEX_LIGHTING
        float diffuse_vertex;
        float specular_vertex;
    #endif
};

// Setup Global Variables
float initGlobals(complexLightingData I) {
    // normal vector
    normal = I.nrm;
    
    // camera vector
    camera_vector_normal = I.c_dir_obj_nrm;
    
    float c_dot   = dot(normal, camera_vector_normal);
    float c_cross = cross(normal, camera_vector_normal);
    
    c_sin = sqrt(dot(c_cross, c_cross));
    c_cos = c_dot;
    c_tan = c_sin / c_cos;
    
    // material properties
    roughness = I.roughness;
    albedo    = I.albedo;
    refr_idx  = I.refr_idx;
};

//////////
// CALC //
//////////

lightingLevels calcLightingLevels(complexLightingData I) {
    // Out setup
    lightingLevels O;
    
    // extract
    initGlobals(I);
    float3 light_vector_normal = I.l_dir_obj_nrm;
    #ifdef VERTEX_LIGHTING_NRM
        float3 light_vector_vertex_normal = I.nrm_vertex;
    #endif
    
    // Always the same
    float lambertian = calcLambertian();
    
    // Ambient
    float out_ambient = lambertian;
    
    // Diffuse
    #ifdef OREN_NAYAR
        float out_diffuse = calcOrenNayar(light_vector_normal);
        #ifdef ENABLE_VERTEX_LIGHTING
            #ifdef VERTEX_LIGHTING_NRM
                float out_diffuse_vertex = calcOrenNayar(light_vector_vertex_normal);
            #else
                float out_diffuse_vertex = lambertian;
            #endif
        #endif
    #else
        float out_diffuse = lambertian;
        #ifdef ENABLE_VERTEX_LIGHTING
            float out_diffuse_vertex = lambertian;
        #endif
    #endif
    
    // Specular
    #ifdef TORRANCE_SPARROW
        float out_specular = calcTorranceSparrow(light_vector_normal);
        #ifdef ENABLE_VERTEX_LIGHTING
            #ifdef VERTEX_LIGHTING_NRM
                float out_specular_vertex = calcTorranceSparrow(light_vector_vertex_normal);
            #else
                float out_specular_vertex = lambertian;
            #endif
        #endif
    #elif defined(PHONG)
        float out_specular = calcPhong(light_vector_normal);
        #ifdef ENABLE_VERTEX_LIGHTING
            #ifdef VERTEX_LIGHTING_NRM
                float out_specular_vertex = calcPhong(light_vector_vertex_normal);
            #else
                float out_specular_vertex = lambertian;
            #endif
        #endif
    #else
        float out_specular = lambertian;
        #ifdef ENABLE_VERTEX_LIGHTING
            float out_specular_vertex = lambertian;
        #endif
    #endif
    
    // Out
    O.ambient = out_ambient;
    O.diffuse = out_diffuse;
    O.specular = out_specular;
    #ifdef ENABLE_VERTEX_LIGHTING
        O.diffuse_vertex = out_diffuse_vertex;
        O.specular_vertex = out_specular_vertex;
    #endif
    return O;
};

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// COMPOSITION CONTROLLER /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct colors {
    float4 col_base;
    float4 col_glow;
};

struct coldata {
    float ambient;
    float diffuse;
    float specular;
    float shadow;
#ifdef ENABLE_VERTEX_LIGHTING
    float diffuse_vertex;
    float specular_vertex;
    float3 light_col_vertex;
    float3 light_col_hero;
#endif
    float3 light_col_amb;
    float3 light_col_diff;
    float4 texBase;
    float4 texGlow;
};

// float3 composeVectors(int count, float3 args[]) {
    // float3 first = args[0];
    // #ifdef SMOOTH_COMPOSE
        // float3 sub = univec - first;
        // for (int i = 1; i < count; i++) {
            // sub = sub * (univec - args[i])
        // }
        // float3 result = univec - sub;
    // #else
        // float x = first.x;
        // float y = first.y;
        // float z = first.z;
        // for (int i = 1; i < count; i++) {
            // float3 curr = args[i];
            // x = max(x, curr.x);
            // y = max(y, curr.y);
            // z = max(z, curr.z);
        // }
        // float3 result = float3(x, y, z);
    // #endif
    // return result;
// }

// float composeFloats(int count, float args[]) {
    // float3 first = args[0];
    // #ifdef SMOOTH_COMPOSE
        // float sub = 1.0f - first;
        // for (int i = 1; i < count; i++) {
            // sub = sub * (1.0f - args[i])
        // }
        // float result = 1.0f - sub;
    // #else
        // float result = first;
        // for (int i = 1; i < count; i++) {
            // result = max(result, args[i]);
        // }
    // #endif
    // return result;
// }

colors calcComposeColors(coldata I) {
    // define out
    colors O;
    
    // setup components
    float3 col_amb  = saturate(I.ambient * I.shadow * I.light_col_amb.xyz * I.texBase.xyz);
    float3 col_diff = saturate(I.diffuse * I.shadow * I.light_col_diff.xyz * I.texBase.xyz);
    float3 col_spec = saturate(I.specular * I.shadow * I.light_col_diff.xyz * I.texBase.xyz);
    #ifdef ENABLE_VERTEX_LIGHTING
        float3 col_hero  = saturate(I.ambient * I.light_col_hero.xyz * I.texBase.xyz);
        float3 col_diff_vertex = saturate(I.diffuse_vertex * I.light_col_vertex.xyz * I.texBase.xyz);
        float3 col_spec_vertex = saturate(I.specular_vertex * I.light_col_vertex.xyz * I.texBase.xyz);
    #endif
    
    // compose
    float alpha_base = I.texBase.w;
#ifdef SPECULAR_GLOW
    #ifdef ENABLE_VERTEX_LIGHTING
        #ifdef SMOOTH_COMPOSE
            float3 rgb_base = univec.xyz - ((univec.xyz - col_amb.xyz) * (univec.xyz - col_diff_vertex.xyz) * (univec.xyz - col_diff.xyz) * (univec.xyz - col_hero.xyz));
            float3 rgb_glow = univec.xyz - ((univec.xyz - col_spec.xyz) * (univec.xyz - col_spec_vertex.xyz) * (univec.xyz - I.texGlow.xyz));
            
            float alpha_glow = 1.0f - ((1.0f - I.texGlow.w) * (1.0f - dot(gamma_correction.xyz, col_spec.xyz)) * (1.0f - dot(gamma_correction.xyz, col_spec_vertex.xyz)));
        #else
            float3 rgb_base = float3(
                max(max(max(col_amb.x, col_diff_vertex.x), col_diff.x), col_hero.x),
                max(max(max(col_amb.y, col_diff_vertex.y), col_diff.y), col_hero.y),
                max(max(max(col_amb.z, col_diff_vertex.z), col_diff.z), col_hero.z)
            );
            float3 rgb_glow = float3(
                max(max(col_spec.x, I.col_spec_vertex.x), I.texGlow.x),
                max(max(col_spec.y, I.col_spec_vertex.y), I.texGlow.y),
                max(max(col_spec.z, I.col_spec_vertex.z), I.texGlow.z)
            );
            float alpha_glow = max(max(I.texGlow.w, dot(gamma_correction.xyz, col_spec.xyz)), dot(gamma_correction.xyz, col_spec_vertex.xyz));
        #endif
    #else
        #ifdef SMOOTH_COMPOSE
            float3 rgb_base = univec.xyz - ((univec.xyz - col_amb.xyz) * (univec.xyz - col_diff.xyz));
            float3 rgb_glow = univec.xyz - ((univec.xyz - col_spec.xyz) * (univec.xyz - I.texGlow.xyz));
            
            float alpha_glow = 1.0f - ((1.0f - I.texGlow.w) * (1.0f - dot(gamma_correction.xyz, col_spec.xyz)));
        #else
            float3 rgb_base = float3(
                max(col_amb.x, col_diff.x),
                max(col_amb.y, col_diff.y),
                max(col_amb.z, col_diff.z)
            );
            float3 rgb_glow = float3(
                max(col_spec.x, I.texGlow.x),
                max(col_spec.y, I.texGlow.y),
                max(col_spec.z, I.texGlow.z)
            );
            float alpha_glow = max(I.texGlow.w, dot(gamma_correction.xyz, col_spec.xyz));
        #endif
    #endif
#else
    #ifdef ENABLE_VERTEX_LIGHTING
        #ifdef SMOOTH_COMPOSE
            float3 rgb_base = univec.xyz - ((univec.xyz - col_amb.xyz) * (univec.xyz - col_diff_vertex.xyz) * (univec.xyz - col_spec_vertex.xyz) * (univec.xyz - col_diff.xyz) * (univec.xyz - col_spec.xyz) * (univec.xyz - col_hero.xyz));
        #else
            float3 rgb_base = float3(
                max(max(max(max(max(col_amb.x, col_diff_vertex.x), col_spec_vertex.x), col_diff.x), col_spec.x), col_hero.x),
                max(max(max(max(max(col_amb.y, col_diff_vertex.y), col_spec_vertex.y), col_diff.y), col_spec.y), col_hero.y),
                max(max(max(max(max(col_amb.z, col_diff_vertex.z), col_spec_vertex.z), col_diff.z), col_spec.z), col_hero.z)
            );
        #endif
    #else
        #ifdef SMOOTH_COMPOSE
            float3 rgb_base = univec.xyz - ((univec.xyz - col_amb.xyz) * (univec.xyz - col_diff.xyz) * (univec.xyz - col_spec.xyz));
        #else
            float3 rgb_base = float3(
                max(max(col_amb.x, col_diff.x), col_spec.x),
                max(max(col_amb.y, col_diff.y), col_spec.y),
                max(max(col_amb.z, col_diff.z), col_spec.z)
            );
        #endif
    #endif
    float3 rgb_glow = I.texGlow.xyz;
    
    float alpha_glow = I.texGlow.w;
#endif
    
    // out
    O.col_base = float4(rgb_base.xyz, alpha_base);
    O.col_glow = float4(rgb_glow.xyz, alpha_glow);
    return O;
};