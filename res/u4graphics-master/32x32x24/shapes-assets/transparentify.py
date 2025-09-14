import os
from PIL import Image
from tqdm import tqdm

def replace_black_with_transparent(input_image_path, output_image_path):
    # Open the input image
    image = Image.open(input_image_path).convert("RGBA")
    
    # Create a new image with the same size and a transparent background
    new_image = Image.new("RGBA", image.size)

    # Iterate through each pixel in the image
    for x in range(image.width):
        for y in range(image.height):
            r, g, b, a = image.getpixel((x, y))
            # Check if the pixel is black (you can adjust the threshold if needed)
            if r < 10 and g < 10 and b < 10:  # Adjust threshold for black
                new_image.putpixel((x, y), (0, 0, 0, 0))  # Set to transparent
            else:
                new_image.putpixel((x, y), (r, g, b, a))  # Keep original pixel

    # Save the new image
    new_image.save(output_image_path, "PNG")
    print(f"Black pixels in '{input_image_path}' have been replaced with transparent pixels in '{output_image_path}'.")


def process_images_in_folder(folder_path):
    # Get a list of all image files in the folder
    image_files = [f for f in os.listdir(folder_path) if f.lower().endswith(('.png', '.jpg', '.jpeg'))]
    
    for image_file in tqdm(image_files, desc="Processing images"):
        input_image_path = os.path.join(folder_path, image_file)
        output_image_path = os.path.join(folder_path, f"sprite_{image_file}")
        replace_black_with_transparent(input_image_path, output_image_path)

if __name__ == "__main__":
    folder_path = "."  # Replace with your folder path
    process_images_in_folder(folder_path)

