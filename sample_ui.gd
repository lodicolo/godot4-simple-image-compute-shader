extends CanvasLayer

@onready var texture_rect_in: TextureRect = %In/VBoxContainer/Panel/TextureRect
@onready var texture_rect_out: TextureRect = %Out/VBoxContainer/Panel/TextureRect
@onready var color_inversion_compute_shader := ColorInversionComputeShader.new()

func _on_button_run_shader_pressed() -> void:
	var input_image := texture_rect_in.texture.get_image()
	var output_image := color_inversion_compute_shader.run(input_image)
	
	var texture := ImageTexture.create_from_image(output_image)
	texture_rect_out.texture = texture
