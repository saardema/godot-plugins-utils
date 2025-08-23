#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(binding = 0, rgba32f) uniform image2D output_texture;

layout(push_constant, std430) readonly uniform Params {
    vec2 tf_scale;
    vec2 tf_pos;
	vec2 texture_scale;
    ivec2 texture_size;
	float scale_ratio;
	float data_range;
	float units_per_point;
	int content_size;
	float blanking;
	float intensity;
	bool alpha_enabled;
	vec2 jitter;
} params;

void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	float cur = imageLoad(output_texture, uv).a;
	cur = max(0, cur - cur * params.blanking);
	imageStore(output_texture, uv, vec4(0, 1, 0, cur));
}
