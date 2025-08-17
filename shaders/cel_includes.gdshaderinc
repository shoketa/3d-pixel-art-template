vec3 _view_from_screen(vec2 _uv, float _depth, mat4 _inv_proj) {
	vec4 _upos = _inv_proj * vec4(_uv * 2.0 - 1.0, _depth, 1.0);
	return _upos.xyz / _upos.w;
}

float remap(float value, float low1, float high1, float low2, float high2) {
    return low2 + (value - low1) * (high2 - low2) / (high1 - low1);
}

vec2 _triplanar_uv(vec3 vert, vec2 norm, vec3 scale, vec3 offset) { // cheaper triplanar. only uses 1 texture fetch.
	return mix(mix(vert.xy*scale.xy+offset.xy, vert.zy*scale.zy+offset.zy, norm.x), vert.xz*scale.xz+offset.xz, norm.y);
}

vec4 _fractal_texture(sampler2D tex, vec2 uv, float min_scale, float scale, float min_distance, vec3 camera_position_world, vec3 world_pos) {
	float d = max(min_scale, log2(distance(camera_position_world, world_pos)/min_distance));
	float stepd = floor(d);
	float pingpong = abs(mod(stepd, 2.));

	vec2 uvA = scale * world_pos.xz / exp2(stepd + pingpong);
	vec2 uvB = scale * world_pos.xz / exp2(stepd + (1. - pingpong));
	float blend_fac = fract(d);
	if (blend_fac >= pingpong) { blend_fac = blend_fac; }
	else { blend_fac = 1.-blend_fac; }

	vec4 texA = texture(tex, uvA);
	vec4 texB = texture(tex, uvB);

	return mix(texA, texB, blend_fac);
}