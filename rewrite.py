# -*- coding: utf-8 -*-
import re

def rewrite_hinges():
    with open('C:\\Users\\Admin\\Desktop\\smart_cabinet_maker\\main.rb', 'r', encoding='utf-8') as f:
        content = f.read()
        
    start_str = 'def self.draw_hinges(cab_ents, door_ents, door_part,'
    end_str = 'end # hinge_z_positions.each'
    
    start_idx = content.find(start_str)
    if start_idx == -1: return 'start not found'
    
    end_idx = content.find(end_str, start_idx)
    if end_idx == -1: return 'end not found'
    
    end_idx = content.find('end', end_idx + len(end_str)) # include the method end
    end_idx += 3
    
    new_method = '''def self.draw_hinges(cab_ents, door_ents, door_part,
                       hinge_type, overlay_type,
                       door_x, door_z, door_w, door_h, t,
                       side_inner_x, hinge_offset_v, door_idx)

    spec = HINGE_SPECS[hinge_type] || HINGE_SPECS["Blum_ClipTop"]

    cup_r      = spec[:cup_r].mm
    cup_depth  = spec[:cup_depth].mm
    cup_off_x  = 22.5.mm
    plate_w    = spec[:plate_w].mm
    plate_d    = spec[:plate_d].mm
    plate_h    = spec[:plate_h].mm
    screw_r    = spec[:screw_r].mm
    hw_color   = spec[:color]

    qty = calc_hinge_qty(door_h.to_mm)

    hinge_z_positions = []
    if qty == 2
      hinge_z_positions = [door_z + hinge_offset_v, door_z + door_h - hinge_offset_v]
    elsif qty == 3
      hinge_z_positions = [
        door_z + hinge_offset_v,
        door_z + door_h / 2.0,
        door_z + door_h - hinge_offset_v
      ]
    else
      step = (door_h - 2.0 * hinge_offset_v) / (qty - 1).to_f
      (0...qty).each do |k|
        hinge_z_positions << door_z + hinge_offset_v + k * step
      end
    end

    is_left_door = (door_idx == 0)

    m_hinge = apply_mat(Sketchup.active_model, "Hardware_Hinge_#{hinge_type}", "", hw_color)

    hinge_z_positions.each_with_index do |hz, idx|

      if is_left_door
        cup_cx = door_x + cup_off_x
      else
        cup_cx = door_x + door_w - cup_off_x
      end
      
      cup_cy = 0.mm
      cup_dir = [0, -1, 0]

      hole(door_ents, [cup_cx, cup_cy, hz], cup_dir, cup_r, cup_depth, "C_BORE_35")

      door_part[:holes] << [hz.to_mm - door_z.to_mm, cup_off_x.to_mm, cup_r, cup_depth]

      cup_grp = cab_ents.add_group
      cup_grp.name = "Hinge_Cup_#{idx+1}_Door#{door_idx+1}"
      cup_grp.material = m_hinge

      ci_cup = cup_grp.entities.add_circle([cup_cx, cup_cy, hz], cup_dir, cup_r - 1.mm)
      f_cup = cup_grp.entities.add_face(ci_cup) rescue nil
      if f_cup
        f_cup.reverse! if f_cup.normal.y > 0
        f_cup.pushpull(cup_depth - 1.mm)
      end

      cup_comp = cup_grp.to_component
      cup_comp.definition.name = "#{hinge_type}_Cup"
      cup_comp.name = "#{hinge_type}_Cup"
      cup_comp.material = m_hinge
      ["opencutlist", "OpenCutList"].each { |d| cup_comp.material.set_attribute(d, "type", "hardware") rescue nil }

      arm_grp = cab_ents.add_group
      arm_grp.name = "Hinge_Arm_#{idx+1}_Door#{door_idx+1}"
      arm_grp.material = m_hinge

      arm_h    = 8.mm
      arm_d    = 25.mm
      arm_y0   = 5.mm

      if is_left_door
        arm_w = (cup_cx - side_inner_x).abs
        box(arm_grp.entities, side_inner_x, arm_y0, hz - arm_h / 2.0, arm_w, arm_d, arm_h)
      else
        arm_w = (side_inner_x - cup_cx).abs
        box(arm_grp.entities, cup_cx, arm_y0, hz - arm_h / 2.0, arm_w, arm_d, arm_h)
      end

      arm_comp = arm_grp.to_component
      arm_comp.definition.name = "#{hinge_type}_Arm"
      arm_comp.name = "#{hinge_type}_Arm"
      arm_comp.material = m_hinge
      ["opencutlist", "OpenCutList"].each { |d| arm_comp.material.set_attribute(d, "type", "hardware") rescue nil }

      plate_grp = cab_ents.add_group
      plate_grp.name = "Hinge_Plate_#{idx+1}_Door#{door_idx+1}"
      plate_grp.material = m_hinge

      plate_cy = 37.mm

      if is_left_door
        box(plate_grp.entities, side_inner_x, plate_cy - plate_d/2.0, hz - plate_w/2.0, plate_h, plate_d, plate_w)
        if screw_r > 0
          [-16.mm, 16.mm].each do |z_off|
            hole(cab_ents, [side_inner_x, plate_cy, hz + z_off], [-1, 0, 0], screw_r, 15.mm, "DRILL_HINGE_PLATE")
          end
        end
      else
        box(plate_grp.entities, side_inner_x - plate_h, plate_cy - plate_d/2.0, hz - plate_w/2.0, plate_h, plate_d, plate_w)
        if screw_r > 0
          [-16.mm, 16.mm].each do |z_off|
            hole(cab_ents, [side_inner_x, plate_cy, hz + z_off], [1, 0, 0], screw_r, 15.mm, "DRILL_HINGE_PLATE")
          end
        end
      end

      plate_comp = plate_grp.to_component
      plate_comp.definition.name = "#{hinge_type}_Plate"
      plate_comp.name = "#{hinge_type}_Plate"
      plate_comp.material = m_hinge
      ["opencutlist", "OpenCutList"].each { |d| plate_comp.material.set_attribute(d, "type", "hardware") rescue nil }

    end
  end'''
    
    final_content = content[:start_idx] + new_method + content[end_idx:]
    with open('C:\\Users\\Admin\\Desktop\\smart_cabinet_maker\\main.rb', 'w', encoding='utf-8') as f:
        f.write(final_content)
        
    return 'success'

print(rewrite_hinges())
