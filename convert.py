import os

# Convert UTF-16LE to UTF-8
input_path = r"C:\Users\Admin\Desktop\smart_cabinet_maker\hinges_temp.txt"
output_path = r"C:\Users\Admin\Desktop\smart_cabinet_maker\hinges_temp_utf8.txt"

if os.path.exists(input_path):
    with open(input_path, "r", encoding="utf-16") as f:
        content = f.read()
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Successfully converted hinges_temp.txt to UTF-8!")
else:
    print("hinges_temp.txt not found!")
