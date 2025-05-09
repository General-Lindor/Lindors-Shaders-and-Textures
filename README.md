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
 