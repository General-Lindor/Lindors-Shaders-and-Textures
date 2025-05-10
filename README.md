# Lindors Shaders
Shader Pack for Sacred 2

## Standalone
Contains finished shaders and images, if required
    
### Cosmic Wings
Enables a 2-d-effect inspired by the cosmic wings of Diablo 3.
Contains Images and Shaders, but they need to be applied in surface.txt first.
Initially made for the Inquisitors Deylen Set.
Curently i'm experimenting to make it for his Mutation Set instead.
    
### FX_Rindenhaut
Fixes the Devs programming mistakes to make it look as intended.
    
### MAIN - complex lighting
Contains:
- functions for calculating various lighting models
    - ambient: albedo
    - diffuse: lambertian, Oren-Nayar
    - specular: phong, phong-blinn, torrance-sparrow (which fixes a mistake in the original cook-torrance model)
- a new, vastly improved fur shader using the above models. Enables Vertex lighting.
- a new, vastly improved tree, leaves & vegetation shader using the above models. Enables Vertex lighting where appropriate.
- some changes in extractvalues.shader
    
### Sera Ancient Set Wing FX for Mystique Set Wings
Does what it says.
    
### Sera Mystique Set Wing FX Fix
Does what it says.
    
### Skorpionshield to fireskin
Changes the Garganthropod Boss's shield FX to look like actual fireskin.
Intended to get used by High Elf.
Needs to be enabled in spells.txt.
    
## EXPERIMENTAL
Contains Work-in-progress stuff
    
## OLD
Contains old scrapped shaders, mostly for documentation.

# LITERATURE

## Real Time Rendering Fur (What are shells and fins?):
- [Scientific Paper](https://www.researchgate.net/publication/277296247_Real-Time_Rendering_of_Fur_i)

## Maths

### Tangential, Principal and Binormal Vector:
- [Definition](https://web.ma.utexas.edu/users/m408m/Display13-4-2.shtml)
- [3D Plot](https://www.desmos.com/3d/gznomzuuxv) (HIGHLY REGOMMENDED! Go check it out!)

### Cantilever Beam (What is the curve of a hair under its own weight?)
- [Definition and Formula](https://en.wikipedia.org/wiki/Deflection_(engineering)#Cantilever_beams)
- [2D Plot](https://www.desmos.com/calculator/vspssoash6) (Worth to check it out!)

### Rotating Vectors
- [Rodrigues' rotation formula](https://en.wikipedia.org/wiki/Rodrigues%27_rotation_formula)

## Phong Reflection Model
- [Wikipedia Page](https://en.wikipedia.org/wiki/Phong_reflection_model)

### Diffuse Reflection Models
- [Lambertian](https://en.wikipedia.org/wiki/Lambertian_reflectance)
- [Oren-Nayar](https://en.wikipedia.org/wiki/Oren%E2%80%93Nayar_reflectance_model)

### Specular Reflection Models
- [Phong](https://en.wikipedia.org/wiki/Phong_shading)
- [Phon-Blinn](https://en.wikipedia.org/wiki/Blinn%E2%80%93Phong_reflection_model)
- [General, including Torrance-Sparrow](https://en.wikipedia.org/wiki/Specular_highlight)
- [Clear Torrance Sparrow Confusion](https://computergraphics.stackexchange.com/questions/3946/correct-specular-term-of-the-cook-torrance-torrance-sparrow-model)
- [Several Formulae](https://graphicrants.blogspot.com/2013/08/specular-brdf-reference.html)
- [Schlick's Approximation](https://en.wikipedia.org/wiki/Schlick%27s_approximation)
- [Phong & Beckmann Distributions - 2D Plot](https://www.desmos.com/calculator/svanpzsptg)

## Plots (duplicates from above, just for QOL)
- [3D Plot: Unit Vectors](https://www.desmos.com/3d/gznomzuuxv)
- [2D Plot: Cantilever Beam](https://www.desmos.com/calculator/vspssoash6)
- [2D Plot: Phong & Beckmann Distribution](https://www.desmos.com/calculator/svanpzsptg)
