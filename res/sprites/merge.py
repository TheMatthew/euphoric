from PIL import Image
import os
import re

# Directory containing the images
directory = '.'  # Replace with your directory path

# Find all image files that match the pattern of names ending with sequential integers
image_files = {}
for filename in os.listdir(directory):
    match = re.match(r'^(.*?)(\d+)\.png$', filename)
    if match:
        base_name = match.group(1)  # Get the base name without the number
        if base_name not in image_files:
            image_files[base_name] = []
        image_files[base_name].append(os.path.join(directory, filename))

# Process each group of images
for base_name, files in image_files.items():
    # Sort the files based on the numeric part
    files.sort(key=lambda x: int(re.search(r'(\d+)', x).group()))

    # Load images
    images = [Image.open(file) for file in files]

    # Calculate total width and maximum height for the new image
    total_width = sum(image.width for image in images)
    max_height = max(image.height for image in images)

    # Create a new blank image with the calculated dimensions
    new_image = Image.new('RGBA', (total_width, max_height))

    # Paste each image into the new image
    current_x = 0
    for image in images:
        new_image.paste(image, (current_x, 0))
        current_x += image.width

    # Define the output file path
    output_file_path = os.path.join(directory, f'{base_name}.png')

    # Check if the file already exists
    if os.path.exists(output_file_path):
        print(f'File {output_file_path} already exists. Choose a different name or delete the existing file.')
    else:
        # Save the new image with the base name
        new_image.save(output_file_path)
        print(f'Saved: {output_file_path}')

