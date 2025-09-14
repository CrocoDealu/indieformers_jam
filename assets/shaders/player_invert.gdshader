shader_type canvas_item;

uniform float active : hint_range(0.0,1.0) = 0.0;        // Toggle (0 = normal, 1 = inverted effect)
uniform float blend  : hint_range(0.0,1.0) = 0.6;        // Base strength of inversion
uniform float flash_speed : hint_range(0.0,20.0) = 6.0;  // Mild pulsation speed

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    if (tex.a < 0.01) {
        discard;
    }

    // Simple color invert
    vec3 inv = 1.0 - tex.rgb;

    // Gentle pulse (not too distracting)
    float pulse = 0.5 + 0.5 * sin(TIME * flash_speed);
    float dynamic = mix(blend * 0.5, blend, pulse);

    vec3 mixed = mix(tex.rgb, inv, active * dynamic);
    COLOR = vec4(mixed, tex.a);
}