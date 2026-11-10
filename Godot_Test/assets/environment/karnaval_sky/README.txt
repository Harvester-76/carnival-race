KARNAVAL SKY ASSETS

Files:
- sky_base_4096x2048.png: equirectangular 2:1 base atmospheric color, no baked star/clouds.
- clouds_far_mask_2048.png: seamless grayscale far-cloud density mask.
- clouds_near_mask_2048.png: seamless grayscale near-cloud density mask.
- atmosphere_noise_1024.png: seamless subtle grayscale atmospheric modulation.
- star_disc_1024.png: warm RGBA stellar disc with soft alpha edge.
- cloud_ring_cumulus_static_v3.png: low-height, 3:1 RGBA cumulus ribbon used as a static layer near the horizon.

Important:
These are procedural starter assets, not physically simulated atmospheric data.
Cloud masks are tileable (opposite edges match by periodic construction).
Use masks as density maps in a Godot 4 `shader_type sky` shader. Animate UV offsets
at different speeds. Evaluate cloud density in the star direction and attenuate
star intensity with that density. Keep the star separate from the base panorama.
The base panorama is equirectangular 2:1 and contains no horizon geometry.
The static cumulus bank is a separate painted layer. It turns very slowly along
the horizon (default: about one full turn every 5.6 hours); adjust
`cloud_ring_rotation_speed` (UV turns per second) in
`environment/materials/karnaval_planet_sky.tres`. Its longitude edge is softly
blended in the sky shader, and its height is controlled by
`cloud_ring_vertical_zoom` and `cloud_ring_top_elevation`.
