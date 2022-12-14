shader_type canvas_item;

const float SCALING = 10.0;
const float PI = 3.14159265359;

vec2 cart_to_polar(vec2 z) {
	return vec2(length(z), mod(atan(z.y, z.x) + 2.0 * PI, 2.0 * PI));
}

vec2 polar_to_cart(vec2 z) {
	return vec2(z.x * cos(z.y), z.x * sin(z.y));
}

vec2 cconj(vec2 z) {
	return vec2(z.x, -z.y);
}

vec2 cmult(vec2 a, vec2 b) {
	vec2 polar_a = cart_to_polar(a);
	vec2 polar_b = cart_to_polar(b);
	
	return polar_to_cart(vec2(polar_a.x * polar_b.x, polar_a.y + polar_b.y));
}

vec2 cdiv(vec2 a, vec2 b) {
	vec2 polar_b = cart_to_polar(b);
	vec2 inverse_polar_b = vec2(1.0 / polar_b.x, -polar_b.y);
	vec2 inverse_b = polar_to_cart(inverse_polar_b);
	return cmult(a, inverse_b);
}

vec2 cpow(vec2 base, vec2 power) {
	vec2 polar_base = cart_to_polar(base);
	
	if (polar_base.y > PI) {
		polar_base.y = polar_base.y - 2.0 * PI;
	}
	
	return polar_to_cart(vec2(pow(polar_base.x, power.x) * exp(-polar_base.y * power.y), 
			polar_base.y * power.x + log(polar_base.x) * power.y));
}

vec2 cexp(vec2 z) {
	return exp(z.x) * vec2(cos(z.y), sin(z.y));
}

vec2 clog(vec2 z) {
	vec2 polar_z = cart_to_polar(z);
	if (polar_z.y > PI) {
		polar_z.y = polar_z.y - 2.0 * PI;
	}
	return vec2(log(polar_z.x), 0.0) + cmult(vec2(0.0, 1.0), vec2(polar_z.y, 0.0));
}

vec2 csin(vec2 z) {
	return cmult(vec2(0.0, -0.5), cexp(cmult(vec2(0.0, 1.0), z)) - cexp(cmult(vec2(0.0, -1.0), z)));
}

vec2 ccos(vec2 z) {
	return cmult(vec2(0.5, 0.0), cexp(cmult(vec2(0.0, 1.0), z)) + cexp(cmult(vec2(0.0, -1.0), z)));
}

vec2 ctan(vec2 z) {
	return cdiv(csin(z), ccos(z));
}

vec2 carg(vec2 z) {
	return vec2(mod(atan(z.y, z.x) + 2.0 * PI, 2.0 * PI), 0.0);
}

vec2 cmod(vec2 z) {
	return vec2(length(z), 0);
}

vec2 cuv_to_uv(vec2 cuv) {
	return (cuv / SCALING + vec2(0.5, -0.5)) / vec2(1.0, -1.0);
}

void fragment() {
	vec2 cuv = SCALING * (UV * vec2(1.0, -1.0) - vec2(0.5, -0.5));
	
	COLOR = texture(TEXTURE, cuv_to_uv(cuv));
}