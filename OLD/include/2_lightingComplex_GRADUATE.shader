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

// Globals
uniform float const_pi = 3.14159265f;
uniform float const_e = 2.71828183f;
#ifdef SMOOTH_COMPOSE
    uniform float3 univec = float3(1.0f, 1.0f, 1.0f);
#endif

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// DIFFUSE ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Diffuse Model: Lambertian
float calcLambertian(float3 camera_vector_normal, float3 normal) {
    float c_cos = dot(camera_vector_normal, normal);
    float diffuse = saturate(c_cos);
    return diffuse;
};

// Diffuse Model: Oren-Nayar
float calcOrenNayar(float3 camera_vector_normal, float3 light_vector_normal, float3 normal, float roughness, float albedo) {
    
    // camera vector
    float c_dot = dot(normal, camera_vector_normal);
    float3 c_cross = cross(normal, camera_vector_normal);
    
    float c_sin = sqrt(dot(c_cross, c_cross));
    float c_cos = c_dot;
    float c_tan = c_sin / c_cos;
        
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
    diffuse = saturate(diffuse);
    
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
float calcPhong(float3 camera_vector_normal, float3 light_vector_normal, float3 normal, float roughness) {
    float l_cos = dot(light_vector_normal, normal);
    float basis = dot(camera_vector_normal, ((2.0f * l_cos * normal) - light_vector_normal));
    
    float alpha = roughness * roughness;
    float beta = alpha * alpha;
    float exponent = (2.0f / beta) - 2.0f;
    
    basis = abs(basis);
    exponent = abs(exponent);
    
    float specular = saturate(pow(basis, exponent));
    return specular;
};

//////////////
// TORRANCE //
//////////////

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// CALCULATION CONTROLLER /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct complexLightingData {
    float3 nrm;
#ifdef VERTEX_LIGHTING_NRM
    float3 nrm_vertex;
#endif
    float3 c_dir_obj_nrm;
    float3 l_dir_obj_nrm;
    float roughness;
    float albedo;
    float refr_idx;
};

struct lightingLevels {
    float ambient;
    float diffuse;
    float specular;
#ifdef ENABLE_VERTEX_LIGHTING
    float diffuse_vertex;
    float specular_vertex;
#endif
};

lightingLevels calcLightingLevels(complexLightingData I) {
    //Out setup
        lightingLevels O;
        
    //Vectors setup
        //extract
        float3 nrm = I.nrm;
        float3 c_dir_obj_nrm = I.c_dir_obj_nrm;
        float3 l_dir_obj_nrm = I.l_dir_obj_nrm;
        //float roughness = lerp((1.0f / sqrt(const_pi)), 1.0f, I.roughness);
        float roughness = (((1.0f - (2.0f * I.roughness)) / sqrt(const_pi)) + I.roughness) / (1.0f - I.roughness);
        float albedo = I.albedo;
        float refr_idx = I.refr_idx;
        
        //light vector
        float l_dot = dot(nrm, l_dir_obj_nrm);
        float3 l_cross = cross(nrm, l_dir_obj_nrm);
      
        float l_sin = sqrt(dot(l_cross, l_cross));
        float l_cos = l_dot;
        float l_tan = l_sin / l_cos;
        
        //camera vector
        float c_dot = dot(nrm, c_dir_obj_nrm);
        float3 c_cross = cross(nrm, c_dir_obj_nrm);
        
        float c_sin = sqrt(dot(c_cross, c_cross));
        float c_cos = c_dot;
        float c_tan = c_sin / c_cos;
        
        //cos of half angle between light and camera
            //formula: cos(x/2) = sqrt((cos(x) + 1) / 2)
        float c_l_cos = dot(c_dir_obj_nrm, l_dir_obj_nrm);
        float c_l_cos_half = sqrt((c_l_cos + 1.0f) * 0.5f);
        
        //halfway vector
        float3 h_nrm = normalize(l_dir_obj_nrm.xyz + c_dir_obj_nrm.xyz);
        
        float h_dot = dot(nrm, h_nrm);
        float3 h_cross = cross(nrm, h_nrm);
        
        float h_sin = sqrt(dot(h_cross, h_cross));
        float h_cos = h_dot;
        float h_tan = h_sin / h_cos;
        
        float lambertian = calcLambertian(c_dir_obj_nrm, nrm);

#ifdef VERTEX_LIGHTING_NRM
        //light vector - vertex
        float3 nrm_vertex = I.nrm_vertex;
        float v_dot = dot(nrm, nrm_vertex);
        float3 v_cross = cross(nrm, nrm_vertex);
      
        float v_sin = sqrt(dot(v_cross, v_cross));
        float v_cos = v_dot;
        float v_tan = v_sin / v_cos;
        
        //halfway vector - vertex
        float3 h_vertex_nrm = normalize(nrm_vertex.xyz + c_dir_obj_nrm.xyz);
        
        float h_vertex_dot = dot(nrm, h_vertex_nrm);
        float3 h_vertex_cross = cross(nrm, h_vertex_nrm);
        
        float h_vertex_sin = sqrt(dot(h_vertex_cross, h_vertex_cross));
        float h_vertex_cos = h_vertex_dot;
        float h_vertex_tan = h_vertex_sin / h_vertex_cos;
#endif
    
    //Ambient
    float out_ambient = lambertian;

    //Diffuse Model
#ifdef OREN_NAYAR
        float out_diffuse = calcOrenNayar(c_dir_obj_nrm, l_dir_obj_nrm, nrm, I.roughness, albedo);
    #ifdef VERTEX_LIGHTING_NRM
        float out_diffuse_vertex = calcOrenNayar(c_dir_obj_nrm, nrm_vertex, nrm, I.roughness, albedo);
    #else
        float out_diffuse_vertex = lambertian;
    #endif
#else
        float out_diffuse = lambertian;
        float out_diffuse_vertex = lambertian;
#endif
#ifdef SOFT_FRESNEL
    //Fake Fresnel, but looks better imho. More specular, softer transitions.
        float r_theta = (1.0f - refr_idx) / (1.0f + refr_idx);
        r_theta *= r_theta;
        float fresnel = r_theta + ((1.0f - r_theta) * c_sin);
#else
    //Fresnel (Schlick's Approximation)
        float r_theta = (1.0f - refr_idx) / (1.0f + refr_idx);
        r_theta *= r_theta;
        float fresnel = r_theta + ((1.0f - r_theta) * pow((1.0f - c_l_cos_half), 5));
#endif
#ifdef TORRANCE_SPARROW
    //Specular Model: Torrance-Sparrow / Cook-Torrance
        
        //Numerator
            //Geometric Attenuation
                float factor = ((2.0f * h_cos) / (dot(c_dir_obj_nrm, h_nrm)));
                float g_a = min(1.0f, min((factor * l_cos), (factor * c_cos)));
            
            float numerator = fresnel * g_a;
        
        //Denominator
            //Beckmann Distribution (note that b_d_inv actually calculates the inverse of the beckmann distribution)
                float n = (h_tan / roughness);
                n *= n;
                float d = roughness * h_cos * h_cos;
                d *= d;
                float b_d_inv = const_pi * ((pow(const_e, n)) * d);
            
            float denominator = const_pi * b_d_inv * c_cos * l_cos;
        
        float out_specular = numerator / denominator;
    #ifdef VERTEX_LIGHTING_NRM
    //Specular Model: Torrance-Sparrow / Cook-Torrance - vertex
        
        //Numerator
            //Geometric Attenuation
                float factor_vertex = ((2.0f * h_vertex_cos) / (dot(c_dir_obj_nrm, h_vertex_nrm)));
                float g_a_vertex = min(1.0f, min((factor_vertex * v_cos), (factor_vertex * c_cos)));
            
            float numerator_vertex = fresnel * g_a_vertex;
        
        //Denominator
            //Beckmann Distribution (note that b_d_vertex_inv actually calculates the inverse of the beckmann distribution)
                float n_vertex = (h_vertex_tan / roughness);
                n_vertex *= n_vertex;
                float d_vertex = roughness * h_vertex_cos * h_vertex_cos;
                d_vertex *= d_vertex;
                float b_d_vertex_inv = const_pi * ((pow(const_e, n_vertex)) * d_vertex);
            
            float denominator_vertex = const_pi * b_d_vertex_inv * c_cos * v_cos;
        
        float out_specular_vertex = numerator_vertex / denominator_vertex;
    #else
        //vertex diffuse: Just Fresnel
        float out_specular_vertex = lambertian;
    #endif
#elif defined(PHONG)
        float out_specular = calcPhong(c_dir_obj_nrm, l_dir_obj_nrm, nrm, I.roughness);
    #ifdef VERTEX_LIGHTING_NRM
        float out_specular_vertex = calcPhong(c_dir_obj_nrm, nrm_vertex, nrm, I.roughness);
    #else
        //vertex diffuse: Just Fresnel
        float out_specular_vertex = lambertian;
    #endif
#else
    //Specular Model: Just Fresnel
        float out_specular = lambertian;
        float out_specular_vertex = lambertian;
#endif
    
    //Out
        O.ambient = saturate(out_ambient);
        O.diffuse = saturate(out_diffuse);
        O.specular = saturate(out_specular);
#ifdef ENABLE_VERTEX_LIGHTING
        O.diffuse_vertex = saturate(out_diffuse_vertex);
        O.specular_vertex = saturate(out_specular_vertex);
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

colors calcComposeColors(coldata I) {
    // define out
    colors O;
    
    // setup components
    float3 col_amb  = saturate(I.ambient * I.shadow * I.light_col_amb.xyz * I.texBase.xyz);
#ifdef ENABLE_VERTEX_LIGHTING
    float3 col_hero  = saturate(I.ambient * I.light_col_hero.xyz * I.texBase.xyz);
    float3 col_diff_vertex = saturate(I.diffuse_vertex * I.light_col_vertex.xyz * I.texBase.xyz);
    float3 col_spec_vertex = saturate(I.specular_vertex * I.light_col_vertex.xyz * I.texBase.xyz);
#endif
    float3 col_diff = saturate(I.diffuse * I.shadow * I.light_col_diff.xyz * I.texBase.xyz);
    float3 col_spec = saturate(I.specular * I.shadow * I.light_col_diff.xyz * I.texBase.xyz);
    
    float alpha_base = I.texBase.w;
#ifdef SPECULAR_GLOW
    float3 gamma_correction = float3(0.2126f, 0.7152f, 0.0722f);
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