shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

vec3 palette_shift(vec3 c) {
    float g = dot(c, vec3(0.299, 0.587, 0.114));
    vec3 inv = vec3(1.0) - c;
    return mix(inv, vec3(g) * 1.1, 0.25);
}

void fragment() {
    vec4 col = texture(screen_tex, SCREEN_UV);
    vec3 shifted = palette_shift(col.rgb);
    col.rgb = mix(col.rgb, shifted, strength);
    COLOR = col;
}
