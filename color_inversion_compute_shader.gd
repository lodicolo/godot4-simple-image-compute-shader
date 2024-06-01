extends RefCounted
class_name ColorInversionComputeShader

var rd: RenderingDevice
var shader: RID
var uniform_input_texture: RDUniform
var uniform_output_texture: RDUniform
var pipeline: RID

func _init() -> void:
	rd = RenderingServer.create_local_rendering_device()

	var shader_source := preload("res://color_inversion_compute_shader.glsl")
	var shader_spirv := shader_source.get_spirv()
	var error_compute := shader_spirv.compile_error_compute
	if error_compute:
		push_error("Failed to compile compute shader: %s" % error_compute)
		return

	shader = rd.shader_create_from_spirv(shader_spirv)

	uniform_input_texture = RDUniform.new()
	uniform_input_texture.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_input_texture.binding = 0

	uniform_output_texture = RDUniform.new()
	uniform_output_texture.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_output_texture.binding = 1

	pipeline = rd.compute_pipeline_create(shader)

func run(input_image: Image) -> Image:
	var input_format = input_image.get_format()

	var input_image_format := RDTextureFormat.new()
	input_image_format.width = input_image.get_width()
	input_image_format.height = input_image.get_height()
	input_image_format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	input_image_format.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT

	var input_texture_view := RDTextureView.new()
	
	var input_texture := rd.texture_create(input_image_format, input_texture_view, [input_image.get_data()])
	uniform_input_texture.clear_ids()
	uniform_input_texture.add_id(input_texture)

	var output_image_format := RDTextureFormat.new()
	output_image_format.width = input_image.get_width()
	output_image_format.height = input_image.get_height()
	output_image_format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	output_image_format.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT

	var output_texture_view := RDTextureView.new()
	
	var output_texture := rd.texture_create(output_image_format, output_texture_view)
	uniform_output_texture.clear_ids()
	uniform_output_texture.add_id(output_texture)

	var uniform_set_0 := rd.uniform_set_create([uniform_input_texture, uniform_output_texture], shader, 0)

	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set_0, 0)

	# Each workgroup is assigned to a 8x8 chunk and so the number of groups
	# should be the width / 8 (rounded up) and the height / 8 (also rounded up).
	# The shader is written in such a way that it will ignore out-of-bounds indices.
	# Defines the range that gl_WorkGroupID will fall in
	var groups_x := int(ceil(input_image.get_width() / 8.0))
	var groups_y := int(ceil(input_image.get_height() / 8.0))
	rd.compute_list_dispatch(compute_list, groups_x, groups_y, 1)
	rd.compute_list_end()
	rd.submit()

	rd.sync()
	var output_texture_result_data := rd.texture_get_data(output_texture, 0)
	var output_image := Image.create_from_data(input_image.get_width(), input_image.get_height(), false, input_format, output_texture_result_data)

	rd.free_rid(uniform_set_0)
	rd.free_rid(input_texture)
	rd.free_rid(output_texture)

	return output_image
