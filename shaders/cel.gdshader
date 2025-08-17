/* 
	Master Shader for my cel-shading 
*/
shader_type spatial;
render_mode depth_prepass_alpha;

uniform sampler2D depth_texture : hint_depth_texture;
uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture;

group_uniforms albedo;
uniform vec3 tint : source_color = vec3(1.);
uniform sampler2D albedo_tex : filter_nearest_mipmap, hint_default_white;

group_uniforms normal;
uniform float normal_strength : hint_range(-4.0, 4.) = .25;
uniform sampler2D normal_tex : filter_nearest_mipmap, hint_normal;

group_uniforms sampling;
uniform vec3 _scale = vec3(1.);
uniform vec3 _offset = vec3(0.);
uniform bool use_triplanar = false;

group_uniforms fractal;
uniform bool use_fractal = false;
uniform float fractal_min_scale = .01;
uniform float fractal_scale = 1.;
uniform float fractal_min_distance = 10.;

group_uniforms shading;
uniform int steps : hint_range(0,8) = 2;
uniform float wrap : hint_range(-2.,2.) = 0.;
uniform float steepness : hint_range(1.,8.) = 1.;
uniform bool use_attenuation = true;
group_uniforms specular;
uniform bool use_specular = true;
uniform float specular_smoothness : hint_range(2.,32.) = 16.;
uniform float specular_strength : hint_range(0.0, 2.0) = 1.;

group_uniforms rim;
uniform bool use_rim = false;
uniform vec4 rim_color : source_color = vec4(1.);
uniform float rim_width : hint_range(2.,16.) = 4.;
uniform bool step_rim = true;
uniform float rim_threshold : hint_range(0.,1.) = .5;

group_uniforms outlines; // from denovodavid / davidhol.land
uniform bool use_outline = false;
uniform vec3 outline_color : source_color = vec3(0, 0, 1);
uniform float depth_threshold : hint_range(0.0, 1.0, 0.01) = 0.25;
uniform float depth_normal_threshold : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float depth_normal_threshold_scale = 2.0;
uniform vec3 edge_color : source_color = vec3(1, 0, 0);
uniform float convex_threshold = 0.5;
uniform float convex_normal_threshold : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float convex_normal_threshold_scale = 2.0;

// modelspace VERTEX & NORMAL
varying vec3 _vert;
varying vec3 _norm;
 
varying vec3 _world_vert;
varying vec3 _world_camera_pos;

#include "res://shaders/cel_includes.gdshaderinc"
#define view_from_screen(uv, depth_tex) _view_from_screen((uv), textureLod((depth_tex), (uv), 0.0).r, INV_PROJECTION_MATRIX)
#define triplanar_uv(vert, norm) _triplanar_uv(vert, norm, _scale, _offset)
#define fractal_texture(tex, uv, min_scale, scale, min_distance) _fractal_texture(tex, uv, min_scale, scale, min_distance, _world_camera_pos, _world_vert)

void vertex() {
	_world_vert = (vec4(VERTEX,1.)*MODEL_MATRIX).xyz;
	_world_camera_pos = CAMERA_POSITION_WORLD;
	_vert = VERTEX;
	_norm = NORMAL;
}

void fragment() {
	// Cheaper Triplanar UV
	vec2 uv = UV*_scale.xy+_offset.xy;
	if (use_triplanar) { uv = triplanar_uv(_vert, abs(_norm.xy)); } // about +-0.01ms

	vec4 albedo;
	vec3 normal;
	if (use_fractal) { // about +-0.02ms
		albedo = fractal_texture(albedo_tex, uv, fractal_min_scale, fractal_scale, fractal_min_distance);
		normal = fractal_texture(normal_tex, uv, fractal_min_scale, fractal_scale, fractal_min_distance).xyz;
	} else {
		albedo = texture(albedo_tex, uv);
		normal = texture(normal_tex, uv).rgb;
	}

	ALBEDO = albedo.rgb * tint;
	ALPHA = albedo.a;
	NORMAL_MAP = normal;
	NORMAL_MAP_DEPTH = normal_strength;

	if (use_outline) { // about +-0.03ms
		vec2 texel_size = 1.0 / VIEWPORT_SIZE;
		vec2 offset[5] = {
						 vec2(-1, 0),
			vec2(0, -1), vec2( 0, 0), vec2(0, 1),
						 vec2( 1, 0)
		};
		vec3 pos[5];
		vec3 norm[5];

		// loop over offsets
		for (int i = 0; i < 5; i++) {
			// fragment uv + neighbour offset
			vec2 uv = SCREEN_UV + offset[i] * texel_size;
			// fragment position in view space
			pos[i] = view_from_screen(uv, depth_texture);
			// fragment normal in view space
			norm[i] = texture(normal_roughness_texture, uv).xyz * 2.0 - 1.0;
		}

		// scale depth threshold based on view normal; remap normal from min..1 -> 1..max
		float depth_threshold_normal_bias = remap(
			// NOTE(david): in orthogonal projections, normal.z is equivalent to dot(normal, -view_forward)
			max(depth_normal_threshold, 1.0 - norm[2].z),
			depth_normal_threshold, 1.0,
			1.0, depth_normal_threshold_scale
		);
		// final depth threshold
		float depth_thresh = depth_threshold * depth_threshold_normal_bias;

		// same for convexity; remap normal from 0..max -> low..1
		float convex_threshold_normal_bias = remap(
			min(norm[2].z, convex_normal_threshold),
			0.0, convex_normal_threshold,
			convex_normal_threshold_scale, 1.0
		);
		float convex_thresh = convex_threshold * convex_threshold_normal_bias;

		// ===== edge ===== //
		float is_edge = 0.0;
		for (int i = 0; i < 5; i++) {
			if (i == 2) continue;
			// cross product gets convexity/concavity (mostly)
			vec3 cp = cross(norm[2], norm[i]);
			float convexity = dot(cp, vec3(offset[i].yx, 0));
			float norm_bias = i < 2 ? 1e-5 : 0.0;
			is_edge +=
				// is this below the depth threshold
				abs(pos[i].z - pos[2].z) < depth_thresh
				// is the normal more oblique; less aligned with the camera (up/left takes priority when even)
				&& norm[i].z + norm_bias > norm[2].z
				// is this a convex edge
				&& convexity > convex_thresh
				? 1.0 : 0.0;
		}
		EMISSION = is_edge > 0.0 ? edge_color : EMISSION;

		// ===== outline ===== //
		EMISSION =
			pos[2].z - pos[0].z > depth_thresh ||
			pos[2].z - pos[1].z > depth_thresh ||
			pos[2].z - pos[3].z > depth_thresh ||
			pos[2].z - pos[4].z > depth_thresh
			? outline_color : EMISSION;
	}
}

void light() {
	vec3 lpi = LIGHT_COLOR*0.31831; // precalculated pi
	float atten = mix(1.,ATTENUATION,float(use_attenuation)); // negligble latency diff, so lerp it is
	
	// Diffuse Light

	float da = (dot(NORMAL,LIGHT)+(atten-1.)+wrap)*steepness;
	float ist = 1./float(steps);
	float ds = clamp(da+mod(1.-da,ist),0.,1.);
	vec3 col = ALBEDO.rgb*lpi;
	col *= ds;

	DIFFUSE_LIGHT += col;

	// Specular Light

	if (use_specular) { // neglible <0.01ms
		vec3 h = normalize(LIGHT+VIEW);
		float sa = max(pow(dot(NORMAL,h), specular_smoothness*specular_smoothness),0.)*atten;
		sa = step(.5, sa);
		SPECULAR_LIGHT += specular_strength*sa*lpi;
	}

	// Rim Light

	if (use_rim){ // neglible <0.01ms
		float r = pow(1.-dot(NORMAL,VIEW), rim_width)*max(0.,da);
		r = mix(r, step(rim_threshold,r),float(step_rim));
		SPECULAR_LIGHT += r*rim_color.rgb*rim_color.a*lpi;
	}
}
