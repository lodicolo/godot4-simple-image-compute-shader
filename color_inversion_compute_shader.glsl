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

    int downscale_factor = 32;
    vec4 sum = vec4(0.0);
    // Nearest neighbor power-of-2 downscale
    // Note: Need to check to make sure the re-scaled pixels are still in bounds
    // to account for images that are not perfect multiples of the downscale factor
    ivec2 downscaled_pixel_coord = pixel_coord / downscale_factor;
    for (int x = 0; x < downscale_factor; ++x) {
        for (int y = 0; y < downscale_factor; ++y) {
            ivec2 src_coord = downscaled_pixel_coord * downscale_factor + ivec2(x, y);
            if (size.x <= src_coord.x || size.y <= src_coord.y) {
                continue;
            }

            sum += imageLoad(u_input_texture, src_coord);
        }
    }

    // Given a 33x33 image, the top left 32x32's
    //  - scan_start will be (0,0)
    //  - scan_limit will be (32,32)
    //  - valid pixels will also be (32,32)
    // The top right section will be 1 vertical strip of pixels and 31 "void" pixels
    //  - scan_start will be (32,0)
    //  - scan_limit will be (64,32)
    //  - valid_pixels however will be (1,32) because size is (33,33)
    // The bottom left would be the same as the top right, just x and y swapped
    // The bottom right would be 1 singular pixel
    //  - scan_start would be (32,32)
    //  - scan_limit would be (64,64)
    //  - valid_pixels would be (1,1)
    ivec2 scan_start = downscaled_pixel_coord * downscale_factor;
    ivec2 scan_limit = (ivec2(1) + downscaled_pixel_coord) * downscale_factor;
    ivec2 valid_pixels = min(size, scan_limit) - scan_start;

    // We sampled valid_pixels.x * valid_pixels.y, so we need to
    // divide by that number to get the true average color
    // e.g. if valid_pixels is (32,32) then we sampled 1024 pixels
    vec4 color = sum / float(valid_pixels.x * valid_pixels.y);
    vec4 inverted_color = vec4(vec3(1.0) - color.xyz, color.w);

    imageStore(u_output_texture, pixel_coord, inverted_color);
}
