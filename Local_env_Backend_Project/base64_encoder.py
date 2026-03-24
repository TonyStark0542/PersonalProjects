<<<<<<< HEAD
import base64
# Example function that returns a base64 string
def encode_image_to_base64(image_path):
    with open(image_path, 'rb') as image_file:
        base64_string = base64.b64encode(image_file.read()).decode('utf-8')
        dat = len(base64_string)
    return base64_string

# Function to write base64 string to a file
def save_base64_to_file(base64_string, filename):
    with open(filename, 'w') as file:
        file.write(base64_string)

# Usage
base64_string = encode_image_to_base64("C:\\Users\\hmahesh\\OneDrive - Capgemini\\Documents\\Sample_Projects\\static\\images\\10_gitanjali-min.jpg")

filename = "C:\\Users\\hmahesh\\OneDrive - Capgemini\\Documents\\Sample_Projects\\base64_string.txt"

save_base64_to_file(base64_string, filename)

print(f'Base64 string has been saved to {filename}')

=======
import base64
# Example function that returns a base64 string
def encode_image_to_base64(image_path):
    with open(image_path, 'rb') as image_file:
        base64_string = base64.b64encode(image_file.read()).decode('utf-8')
        dat = len(base64_string)
    return base64_string

# Function to write base64 string to a file
def save_base64_to_file(base64_string, filename):
    with open(filename, 'w') as file:
        file.write(base64_string)

# Usage
base64_string = encode_image_to_base64("C:\\Users\\hmahesh\\OneDrive - Capgemini\\Documents\\Sample_Projects\\static\\images\\10_gitanjali-min.jpg")

filename = "C:\\Users\\hmahesh\\OneDrive - Capgemini\\Documents\\Sample_Projects\\base64_string.txt"

save_base64_to_file(base64_string, filename)

print(f'Base64 string has been saved to {filename}')

>>>>>>> fb86e7e (new_folder_added)
