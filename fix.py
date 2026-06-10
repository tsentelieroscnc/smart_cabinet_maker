# -*- coding: utf-8 -*-
with open('C:\\Users\\Admin\\Desktop\\smart_cabinet_maker\\main.rb', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'cup_dir = [0, -1, 0]' in line:
        lines[i] = line.replace('[0, -1, 0]', '[0, 1, 0]')
    if 'is_left_door' in line and i < len(lines)-20 and 'box(plate_grp.entities' in lines[i+2]:
        # we are at the if is_left_door block for the plate
        pass
        
# A safer way to fix the [-1, 0, 0] and [1, 0, 0] bug:
start_plate = -1
for i, line in enumerate(lines):
    if 'plate_cy = 37.mm' in line:
        start_plate = i
        break

if start_plate != -1:
    for i in range(start_plate, start_plate + 20):
        if 'if is_left_door' in lines[i]:
            for j in range(i+1, i+10):
                if 'hole(cab_ents' in lines[j]:
                    lines[j] = lines[j].replace('[-1, 0, 0]', '[1, 0, 0]')
        elif 'else' in lines[i] and 'is_left_door' not in lines[i]: # The else block
            for j in range(i+1, i+10):
                if 'hole(cab_ents' in lines[j]:
                    lines[j] = lines[j].replace('[1, 0, 0]', '[-1, 0, 0]')

with open('C:\\Users\\Admin\\Desktop\\smart_cabinet_maker\\main.rb', 'w', encoding='utf-8') as f:
    f.writelines(lines)
