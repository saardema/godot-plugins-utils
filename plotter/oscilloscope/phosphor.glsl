#[compute]
#version 450

layout(local_size_x = 32, local_size_y = 1, local_size_z = 1) in;

layout(binding = 0, rgba32f) uniform image2D output_texture;

layout(binding = 0, set = 1, std430) restrict readonly buffer X_BUFFER {
	float feature_x[];
};

layout(binding = 1, set = 1, std430) restrict readonly buffer Y_BUFFER {
	float feature_y[];
};

layout(binding = 2, set = 1, std430) restrict readonly buffer ALPHA_BUFFER {
	float feature_alpha[];
};

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

uvec3 ID = gl_GlobalInvocationID;

float lerp(float a, float b, float t) {
	return a + t * (b - a);
}

vec2 lerp(vec2 v1, vec2 v2, float t) {
	vec2 delta = v2 - v1;
	return v1 + t * delta;
}

vec2 toUvSpace(vec2 v) {
	return v * params.texture_size;
}

vec2 toNormalSpace(vec2 v) {
	return v / params.texture_size;
}

vec2 toPlotSpace(vec2 v) {
	return (v + params.tf_pos) / params.tf_scale;
}

float lerpy(float idxf) {
	int idx = int(idxf);
	float y1 = -feature_y[idx];
	float y2 = -feature_y[idx+1];
	float t = fract(idxf);

	float y = lerp(y1, y2, t);
	y += params.tf_pos.y;
	y /= params.tf_scale.y;
	y *= params.texture_size.y;

	return y;
}

void line(float y1, float y2) {}

void main() {
	float idxf = float(ID.x);
	idxf += params.jitter.x;
	idxf *= params.texture_scale.x;
	idxf -= params.tf_pos.x;
	idxf -= feature_x[0];
	idxf /= params.units_per_point;

	if (idxf < 0 || idxf >= params.content_size - 1) return;

	int idx = int(idxf);
	float y1 = feature_y[idx];
	float y2 = feature_y[idx + 1];
	float delta = y2 - y1;
	float y = y1 + fract(idxf) * delta + params.tf_pos.y;
	y /= params.texture_scale.y;
	y += params.jitter.y;
	float delta_ratio = abs(delta) / params.units_per_point * params.scale_ratio;
	vec2 ratio = vec2(sign(delta), 0);
	if (delta_ratio < 1) ratio = ratio.yx;
	ivec2 uv = ivec2(vec2(ID.x, y) - ratio * (int(ID.y) - 1));
	float alpha = imageLoad(output_texture, uv).a;
	float interp = ID.y == 1 ? 1 : 0.5;
	alpha = min(1, alpha + params.intensity * interp);
	imageStore(output_texture, uv, vec4(0, 1, 0, alpha));
}
