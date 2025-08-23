#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(binding = 0, rgba32f) uniform image2D texture_a;

layout(push_constant, std430) readonly uniform Params {
	mat3 transform;
    vec2 tf_scale;
    vec2 tf_pos;
    ivec2 texture_size;
	int content_size;
	float blanking;
	vec4 diffusion;
	float intensity;
	bool alpha_enabled;
} params;

const float weights[5][5] = {
    {.01, .05, .12, .05, .01},
    {.05, .12,  .2, .12, .05},
    {.12,  .2, -0.1,  .2, .12},
    {.05, .12,  .2, .12, .05},
    {.01, .05, .12, .05, .01},
};

ivec2 uv = ivec2(gl_GlobalInvocationID.xy);

vec2 averageNb() {
	float weightSum = 0;
	vec2 sum = vec2(0);

	for (int y = -1; y <= 1; ++y) {
		for (int x = -1; x <= 1; ++x) {
			float weight = weights[y + 2][x + 2];
			if (x == 0 && y == 0) weight = params.diffusion.x;
			vec2 value = imageLoad(texture_a, uv + ivec2(x, y)).rg;
			if (value.r < params.diffusion.z) value *= params.diffusion.w;
			weightSum += weight;
			sum += value * weight;
		}
	}

	vec2 result = sum / weightSum;

	return result;
}

vec2 avgDirection() {
	vec2 sum = vec2(0);
	float weightSum = 1;

	for (int y = -1; y <= 1; ++y) {
		for (int x = 0; x <= 1; ++x) {
			if (x == 0 && y == 0) continue;
			vec4 texel = imageLoad(texture_a, uv + ivec2(x, y) * 2);
			float dir = mix(texel.g, atan(y, x), params.diffusion.z);
			float weight = texel.r + params.diffusion.w;
			// if (x == 0 && y == 0) weight = params.diffusion.x;
			sum += vec2(dir, 0) * weight;
			weightSum += weight;
		}
	}

	return sum / weightSum;
}

void main() {
	vec4 a_color = vec4(0);
	vec4 b_color = imageLoad(texture_a, uv);

	b_color.r = b_color.r - b_color.r * params.blanking;
	// b_color.r += (averageNb().r - b_color.r) * params.diffusion.y;
	b_color = clamp(b_color, 0, 1);

	a_color = vec4(0, b_color.r, 0, 1);

	imageStore(texture_a, uv, a_color);
	imageStore(texture_a, uv, b_color);
}
