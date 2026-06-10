with open('C:\\Users\\Admin\\Desktop\\smart_cabinet_maker\\main.rb', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add part_data[:b] = b
target1 = "conn_type_val = b['connector_type'] || \"None\"\n        if conn_type_val != \"None\" && (side_type || is_horiz)\n"
replace1 = "conn_type_val = b['connector_type'] || \"None\"\n        part_data[:b] = b # Pass build config to draw_connectors\n        if conn_type_val != \"None\" && (side_type || is_horiz)\n"
content = content.replace(target1, replace1)

# 2. Extract tt, rw, is_gola, gd_val inside draw_connectors
target2 = "spec = CONNECTOR_SPECS[conn_type]\n    return unless spec"
replace2 = "spec = CONNECTOR_SPECS[conn_type]\n    return unless spec\n\n    b = part_data[:b] || {}\n    tt = b['topType'] || \"Solid\"\n    rw = b['railWidth'].to_f.mm\n    is_gola = (b['isGola'] == true || b['isGola'] == \"true\")\n    gd_val = b['grooveDepth'].to_f.mm"
content = content.replace(target2, replace2)

# 3. Override positions_y for top_join_z if tt == "Rails"
target3 = "[bottom_join_z, top_join_z].each do |join_z|\n        positions_y.each do |cy_off|"
replace3 = "[bottom_join_z, top_join_z].each do |join_z|\n        curr_pos_y = positions_y\n        if join_z == top_join_z && tt == \"Rails\"\n          curr_pos_y = is_gola ? [gd_val + t/2.0, panel_len - rw/2.0] : [rw/2.0, panel_len - rw/2.0]\n        end\n        curr_pos_y.each do |cy_off|"
content = content.replace(target3, replace3)

with open('C:\\Users\\Admin\\Desktop\\smart_cabinet_maker\\main.rb', 'w', encoding='utf-8') as f:
    f.write(content)
