#[compute]
#version 450

// Workgroups are assigned to 8x8 chunks, defines gl_WorkGroupSize
// 8x8 => 64 which is a multiple of both 32 (Nvidia) and 64 (AMD)
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout (rgba8, set = 0, binding = 0) uniform restrict readonly image2D u_input_texture;
layout (rgba8, set = 0, binding = 1) uniform restrict writeonly image2D u_output_texture;

// This function processes 1 pixel
void main() {
    // Get the size of the input image, we will use this to ignore out-of-bounds pixels (since we are running chunks of 32)
    ivec2 size = imageSize(u_input_texture);

    // the x,y coordinates of the pixel
    // must SPECIFICALLY be **Global**InvocationID, not Local
    // Local would be the pixel inside of the 8x8 chunk, but you wouldn't know where in the image the workgroup is
    // gl_GlobalInvocationID = gl_WorkGroupID * gl_WorkGroupSize + gl_LocalInvocationID
    // gl_WorkGroupID is in the range specified by the number of groups in the compute_list_dispatch() call
    ivec2 pixel_coord = ivec2(gl_GlobalInvocationID.xy);

    // Ignore out-of-bounds pixels
    if (size.x <= pixel_coord.x || size.y <= pixel_coord.y) {
        return;
    }

    vec4 color = imageLoad(u_input_texture, pixel_coord);
    vec4 inverted_color = vec4(vec3(1.0) - color.xyz, color.w);

    imageStore(u_output_texture, pixel_coord, inverted_color);
}
