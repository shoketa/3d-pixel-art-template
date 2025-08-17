#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;

// Our push constant
layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	vec2 reserved;
} params;

const mat4 bayer4 = mat4(
	0, 8, 2, 10,
	12, 4, 14, 6,
	3, 11, 1, 9,
	15, 7, 13, 5
);

// The code we want to execute in each invocation
void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);
    float spread = params.reserved.x * 0.01;
	int colors = int(params.reserved.y);

	// Prevent reading/writing out of bounds.
	if (uv.x >= size.x || uv.y >= size.y) {
		return;
	}

	// Read from our color buffer.
	vec4 color = imageLoad(color_image, uv);

	// Apply our changes.
    //float lum = dot(color.rgb, vec3(.2125, .7154, .0721));
	
	float m = bayer4[int(uv.x) % 4][int(uv.y) % 4]*(1./4.*4.)*(1./4.*4.)-0.5;
	color.rgb += vec3(spread*m);
	float n = colors-1.;
	color.rgb = floor(color.rgb*(n)+0.5)/n;
    // Write back to our color buffer.
	imageStore(color_image, uv, color);
}