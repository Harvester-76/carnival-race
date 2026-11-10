KARNAVAL SKY ASSETS

Files:
- sky_base_4096x2048.png: equirectangular 2:1 base atmospheric color, no baked star/clouds.
- clouds_far_mask_2048.png: seamless grayscale far-cloud density mask.
- clouds_near_mask_2048.png: seamless grayscale near-cloud density mask.
- atmosphere_noise_1024.png: seamless subtle grayscale atmospheric modulation.
- star_disc_1024.png: warm RGBA stellar disc with soft alpha edge.

Important:
These are procedural starter assets, not physically simulated atmospheric data.
Cloud masks are tileable (opposite edges match by periodic construction).
Use masks as density maps in a Godot 4 `shader_type sky` shader. Animate UV offsets
at different speeds. Evaluate cloud density in the star direction and attenuate
star intensity with that density. Keep the star separate from the base panorama.
The base panorama is equirectangular 2:1 and contains no horizon geometry.
