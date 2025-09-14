import os

# Specify the directory containing your files
directory = '.'

# Loop through each file in the directory
for filename in os.listdir(directory):
    # Check if the file matches the pattern
    if filename.startswith('sprite_') and filename.endswith('.png'):
        # Create the new filename
        new_filename = filename[11:]
        # Construct full file paths
        old_file = os.path.join(directory, filename)
        new_file = os.path.join(directory, new_filename)
        # Rename the file
        os.rename(old_file, new_file)
        print(f'Renamed: {old_file} to {new_file}')

