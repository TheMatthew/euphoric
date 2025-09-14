from PIL import Image

# Load the image
image_path = 'Ultima_5_-_Tiles-pc-upres.png'  # Replace with your image path
image = Image.open(image_path)

# Define the size of the smaller images
small_width = 128
small_height = 32

# Create a new image with an alpha channel (RGBA)
image = image.convert("RGBA")

# Get the dimensions of the original image
width, height = image.size

# Loop through the image and create smaller images
for y in range(0, height, small_height):
    for x in range(0, width, small_width):
        # Define the box to crop
        box = (x, y, x + small_width, y + small_height)
        small_image = image.crop(box)

        # Save the small image
        small_image_path = f'sprites/small_image_{x}_{y}.png'  # Naming convention
        small_image.save(small_image_path)
        print(f'Saved: {small_image_path}')

