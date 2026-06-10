with open('C:\\Users\\Admin\\Desktop\\smart_cabinet_maker\\main.rb', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'hole(hw_grp.entities, [inner_x, cy, join_z], drill_dir, r_head, d_head' in line:
        indent = line[:len(line) - len(line.lstrip())]
        new_lines = [
            indent + 'outer_x = is_left ? x : (x + pw)\n',
            indent + 'hw_dir = is_left ? [-1, 0, 0] : [1, 0, 0]\n',
            indent + 'hole(hw_grp.entities, [outer_x, cy, join_z], hw_dir, r_head, d_head, "C_BORE_#{(r_head*2).to_mm.round}")\n'
        ]
        lines[i] = ''.join(new_lines)
        break

with open('C:\\Users\\Admin\\Desktop\\smart_cabinet_maker\\main.rb', 'w', encoding='utf-8') as f:
    f.writelines(lines)
