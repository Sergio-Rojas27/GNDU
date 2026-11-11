shader_type canvas_item;

// Controles ajustables en el Inspector
uniform float skew_amount : hint_range(-0.5, 0.5) = -0.15; // Inclinación vertical
uniform float perspective : hint_range(0.0, 0.5) = 0.1;    // Compresión de escala derecha

void fragment() {
	vec2 uv = UV;
	
	// Centrar UV verticalmente
	float v_offset = (uv.x - 0.5) * skew_amount;
	uv.y -= v_offset;
	
	// Aplicar escalado trapezoidal (perspectiva)
	float factor = 1.0 + (uv.x - 0.5) * perspective;
	uv.y = (uv.y - 0.5) / factor + 0.5;
	
	// Cortar fuera de los bordes originales
	if (uv.y < 0.0 || uv.y > 1.0 || uv.x < 0.0 || uv.x > 1.0) {
		discard;
	}
	
	COLOR = texture(TEXTURE, uv);
}