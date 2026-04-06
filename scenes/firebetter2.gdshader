shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha, blend_add, fog_disabled;

uniform sampler2D noise_vertex;
uniform sampler2D noise_big;
uniform sampler2D noise_small;

/* ================== VERTEX ================== */
/* ---- Турбулентность вершин ---- */

uniform float vt_bend_strength = 0.4;     // Общая сила изгиба
uniform float vt_sway_speed    = 0.6;     // Скорость синусного колыхания
uniform float vt_sway_amount   = 0.2;     // Амплитуда синуса
uniform float vt_noise_scale   = 0.5;     // Масштаб шума
uniform float vt_noise_speed   = 0.2;     // Скорость шума
uniform float vt_height_power  = 3.0;     // Усиление кверху

void vertex() {
    float h = clamp(VERTEX.y, 0.0, 1.0);

    vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

    // Синусное колыхание
    float sway = sin(TIME * vt_sway_speed + world.y * 2.0) * vt_sway_amount;

    // Шумовая турбулентность
    vec2 n_uv = world.xz * vt_noise_scale + TIME * vt_noise_speed;
    float n = texture(noise_vertex, n_uv).r - 0.5;

    // Усиление по высоте
    float strength = pow(h, vt_height_power);

    VERTEX.x += (sway + n) * vt_bend_strength * strength;
    VERTEX.z += (n - sway) * vt_bend_strength * strength;
}

/* ================== FRAGMENT ================== */

uniform float rise_speed = 0.7;
uniform float flame_scale = 2.5;
uniform float edge_softness = 0.3;


uniform vec3 color_bottom  : source_color = vec3(1.1, 0.35, 0.08);
uniform vec3 color_mid     : source_color = vec3(0.4, 0.08, 0.02);
uniform vec3 color_top     : source_color = vec3(0.6, 0.18, 0.05);
uniform vec3 color_sparks  : source_color = vec3(1.2, 0.7, 0.15);

uniform float mid_start     = 0.15;
uniform float mid_peak      = 0.35;
uniform float mid_end       = 0.6;
uniform float mid_intensity = 0.5;

uniform float sparks_start  = 0.78;
uniform float sparks_end    = 0.9;
uniform float sparks_intensity = 0.3;


void fragment() {
    vec2 uv = UV;
    uv.y += TIME * rise_speed;
    uv.y = 1.0 - uv.y;

    float uvy = 1.0 - UV.y;

    // Вертикальная форма
    float vertical = pow(1.0 - uvy, 1.5);

    float n1 = texture(noise_big, uv * flame_scale).r;
    float n2 = texture(noise_small, uv * flame_scale * 2.5).r;

    float flame = vertical;
    flame -= (1.0 - vertical) * (n1 * 0.6);
    flame += n2 * 0.15;

    flame = smoothstep(0.0, edge_softness, flame);

    /* ================== ЦВЕТ ================== */

    // Маска середины по высоте
    float mid_mask = smoothstep(mid_start, mid_peak, uvy) *
                     (1.0 - smoothstep(mid_peak, mid_end, uvy)) *
                     mid_intensity;

    vec3 color = mix(color_bottom, color_mid, mid_mask);
    color = mix(color, color_top, smoothstep(mid_end, 1.0, uvy));

    // Жёлто-оранжевые вставки
    float sparks = smoothstep(sparks_start, sparks_end, n2) * mid_mask;
    color = mix(color, color_sparks, sparks * sparks_intensity);

    ALBEDO = color * flame * 2.0;
    ALPHA  = flame * 0.35;
}