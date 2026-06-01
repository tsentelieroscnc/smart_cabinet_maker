require 'sketchup.rb'
require 'json'

# VERSION 12.0 - PRO VISUALS & PREVIEW RESTORED
module SmartCabinet
  module Maker
    @id_cnt = 0

  def self.get_l(n)
    m = Sketchup.active_model
    m.layers[n] || m.layers.add(n)
  end

  def self.box(en, x, y, z, pw, pd_val, ph, l = "C_OUTLINE")
    return if pw <= 0 || pd_val <= 0 || ph <= 0
    f = en.add_face([x,y,z], [x+pw,y,z], [x+pw,y+pd_val,z], [x,y+pd_val,z]) rescue nil
    if f
      f.reverse! if f.normal.z < 0
      f.layer = get_l(l)
      f.pushpull(ph)
    end
  end

  def self.hole(en, c, v, r, dp, l = "C_BORE")
    return unless en
    ci = en.add_circle(c, v, r)
    lay = get_l(l)
    ci.each { |e| e.layer = lay if e.valid? }
    f = en.add_face(ci) rescue nil
    if f
      f.layer = lay
      f.pushpull(-dp)
    end
  end

  def self.draw_side_strip(en, x, y_start, y_end, z, pw, ph, is_front, gola_specs)
    if is_front && gola_specs && gola_specs.any?
      pts = [
        [x, y_start, z],
        [x, y_end, z],
        [x, y_end, z + ph]
      ]
      
      sorted_notches = gola_specs.sort_by { |n| -n[:z_top] }
      sorted_notches.each do |n|
        n_top = n[:z_top]
        n_bot = n[:z_top] - n[:gh]
        gd_val = n[:gd]
        gr = n[:gr]
        
        next if n_top <= z || n_bot >= z + ph
        n_top_clipped = [n_top, z + ph].min
        n_bot_clipped = [n_bot, z].max
        
        if n_top_clipped < z + ph
          pts << [x, y_start, n_top_clipped]
        end
        
        if gr > 0 && gr <= gd_val && gr <= n[:gh]
          r = gr
          if n[:type] == "U" || n[:type] == "German_U"
            cy_t = y_start + gd_val - r
            cz_t = n_top - r
            if cz_t < z + ph
              pts << [x, cy_t, n_top_clipped]
              (1..5).each do |i|
                angle = i * (Math::PI / 2.0) / 6.0
                pts << [x, cy_t + r * Math.sin(angle), cz_t + r * Math.cos(angle)]
              end
            end
            
            cy_b = y_start + gd_val - r
            cz_b = n_bot + r
            if cz_b > z
              pts << [x, cy_b + r, cz_b]
              (1..5).each do |i|
                angle = i * (Math::PI / 2.0) / 6.0
                pts << [x, cy_b + r * Math.cos(angle), cz_b - r * Math.sin(angle)]
              end
              pts << [x, cy_b, cz_b - r]
            end
          else
            cy = y_start + gd_val - r
            cz = n_bot + r
            pts << [x, y_start + gd_val, n_top_clipped]
            if cz > z
              pts << [x, cy + r, cz]
              (1..5).each do |i|
                angle = i * (Math::PI / 2.0) / 6.0
                pts << [x, cy + r * Math.cos(angle), cz - r * Math.sin(angle)]
              end
              pts << [x, cy, cz - r]
            end
          end
        else
          pts << [x, y_start + gd_val, n_top_clipped]
          pts << [x, y_start + gd_val, n_bot_clipped]
        end
        pts << [x, y_start, n_bot_clipped]
      end
      
      pts << [x, y_start, z]
      pts.uniq!
      
      f = en.add_face(pts) rescue nil
      if f
        f.reverse! if f.normal.x < 0
        f.pushpull(pw)
      else
        box(en, x, y_start, z, pw, y_end - y_start, ph)
      end
    else
      box(en, x, y_start, z, pw, y_end - y_start, ph)
    end
  end

  def self.draw_legs(en, w, d, pl, b, t)
    return if pl <= 0
    inset_x = 50.mm
    pf = b['plinthInsetF'].to_f.mm
    pb = b['plinthInsetB'].to_f.mm
    
    inset_y_front = pf + t + 20.mm
    inset_y_back = pb + 50.mm
    
    # Volpato leg approx dimensions
    top_plate_w = 70.mm
    top_plate_d = 70.mm
    top_plate_h = 5.mm
    r_cylinder = 14.mm
    r_foot = 18.mm
    foot_h = 20.mm
    
    pos = [
      [inset_x, inset_y_front, 0],
      [w - inset_x, inset_y_front, 0],
      [inset_x, d - inset_y_back, 0],
      [w - inset_x, d - inset_y_back, 0]
    ]
    
    m_leg = apply_mat(Sketchup.active_model, "Plastic_Leg_Volpato", "", [30, 30, 30])
    
    pos.each do |p|
      grp = en.add_group; grp.name = "Volpato_Leg"
      grp.material = m_leg
      l_ent = grp.entities
      
      # Top plate (box)
      plate_x = p[0] - top_plate_w/2.0
      plate_y = p[1] - top_plate_d/2.0
      box(l_ent, plate_x, plate_y, pl - top_plate_h, top_plate_w, top_plate_d, top_plate_h)
      
      # Cylinder body
      ci = l_ent.add_circle([p[0], p[1], foot_h], [0, 0, 1], r_cylinder)
      f = l_ent.add_face(ci) rescue nil
      if f
        f.reverse! if f.normal.z < 0
        f.pushpull(pl - top_plate_h - foot_h)
      end
      
      # Bottom adjustable foot
      ci2 = l_ent.add_circle([p[0], p[1], 0], [0, 0, 1], r_foot)
      f2 = l_ent.add_face(ci2) rescue nil
      if f2
        f2.reverse! if f2.normal.z < 0
        f2.pushpull(foot_h)
      end
      
      # Convert to component
      comp = grp.to_component
      comp.definition.name = "Volpato_Leg"
      comp.name = "Volpato_Leg"
      comp.material = m_leg
    end
  end

  def self.add_handle(en, h_type, hx, hy, hz)
    h_grp = en.add_group; h_grp.name = "Handle"
    m_hand = apply_mat(Sketchup.active_model, "Handle_Metal", "", [192, 192, 192])
    h_grp.material = m_hand
    if h_type == "Knob"
      box(h_grp.entities, hx - 10.mm, hy - 20.mm, hz - 10.mm, 20.mm, 20.mm, 20.mm)
    elsif h_type == "Bar"
      box(h_grp.entities, hx - 60.mm, hy - 15.mm, hz - 5.mm, 120.mm, 15.mm, 10.mm)
    end
  end

  # VERSION 12.5 - PRODUCTION READY
  def self.apply_mat(model, name, tex_path, color_rgb = [240, 240, 240])
    mats = model.materials
    m = mats[name] || mats.add(name)
    m.color = color_rgb
    if tex_path && tex_path != "" && File.exist?(tex_path)
      m.texture = tex_path rescue nil
      m.texture.size = [1000.mm, 1000.mm] if m.texture
    end
    
    # Auto-classify for OpenCutList
    type_str = "sheet_good"
    if name.downcase.include?("leg") || name.downcase.include?("handle") || name.downcase.include?("metal")
      type_str = "hardware"
    end
    
    ["opencutlist", "OpenCutList"].each do |dict|
      m.set_attribute(dict, "type", type_str)
    end
    
    m
  end

  def self.draw_blum_hinge(en, x, y, z, mat, is_right)
    # Basic 3D representation of Blum Clip Top
    grp = en.add_group
    grp.name = "Blum_Hinge"
    grp.material = mat
    ent = grp.entities
    
    # Hinge cup in the door (diameter 35mm, depth 12mm)
    # y is the back face of the door (which is 0 in global coordinates usually)
    cup_x = is_right ? x - 22.5.mm : x + 22.5.mm
    cup_r = 17.5.mm
    self.hole(ent, [cup_x, 0, z], [0, -1, 0], cup_r, 12.mm, "Hardware")
    
    # Hinge arm
    arm_w = 15.mm
    arm_l = 30.mm
    arm_h = 20.mm
    arm_x = is_right ? x - arm_l : x
    self.box(ent, arm_x, 0, z - arm_h/2, arm_l, 37.mm, arm_h)
    
    # Mounting plate on the carcass (at 37mm offset)
    plate_w = 5.mm
    px = is_right ? x - plate_w : x
    self.box(ent, px, 37.mm - 10.mm, z - 16.mm, plate_w, 20.mm, 32.mm)
    
    comp = grp.to_component
    comp.definition.name = "Blum_Hinge"
    comp.name = "Blum_Hinge"
    comp.material = mat
    ["opencutlist", "OpenCutList"].each do |dict|
      comp.material.set_attribute(dict, "type", "hardware")
    end
  end

  def self.draw_gola(en, w, d, pl, h, f, mat, gola_specs)
    return unless gola_specs && gola_specs.any?
    
    gola_specs.each_with_index do |spec, idx|
      g_type = spec[:type]
      gh = spec[:gh]
      gd_val = spec[:gd]
      z_top = spec[:z_top]
      z_bot = z_top - gh
      
      g_grp = en.add_group
      g_grp.name = "Gola_Profile_#{idx + 1}"
      g_grp.material = mat
      g_ent = g_grp.entities
      
      pts = []
      
      if g_type == "L"
        # Volpato/DTC standard L-profile
        # Back face is at gd_val (e.g. 26). Front face is at 0.
        pts << [0, gd_val - 2.mm, z_top] # Top-front edge of back wall
        pts << [0, gd_val, z_top]        # Top-back edge of flange / back wall
        
        # Rounded outer back-bottom corner (fits the r5 notch corner)
        pts << [0, gd_val, z_top - gh + 5.mm]
        (1..5).each do |i|
          angle = i * (Math::PI / 2.0) / 6.0
          pts << [0, gd_val - 5.mm + 5.mm * Math.cos(angle), z_top - gh + 5.mm - 5.mm * Math.sin(angle)]
        end
        pts << [0, gd_val - 5.mm, z_top - gh]
        
        pts << [0, 0, z_top - gh]         # Front-bottom corner
        pts << [0, 0, z_top - gh + 6.mm]  # Front lip top
        pts << [0, 2.mm, z_top - gh + 6.mm] # Front lip back hook
        pts << [0, 2.mm, z_top - gh + 2.mm] # Inner bottom wall start
        
        # Inside curve of back-bottom corner
        pts << [0, gd_val - 5.mm, z_top - gh + 2.mm]
        (1..5).each do |i|
          angle = i * (Math::PI / 2.0) / 6.0
          pts << [0, gd_val - 5.mm + 3.mm * Math.sin(angle), z_top - gh + 2.mm + 3.mm - 3.mm * Math.cos(angle)]
        end
        pts << [0, gd_val - 2.mm, z_top - gh + 5.mm]
        
        # Smooth vertical wall front face
        pts << [0, gd_val - 2.mm, z_top]
        
      elsif g_type == "U"
        # Volpato/DTC standard C/U-profile based on schematic
        # Back face is at gd_val. Front face is at 0.
        # Screw channels are on the BACK of the vertical wall (pointing to gd_val + 3.mm)
        # The interior C-channel is perfectly flat, smooth and curved!
        pts << [0, 0, z_top - 6.mm]         # Top-front lip bottom
        pts << [0, 0, z_top]                # Top-front corner
        
        # Rounded outer back-top corner
        pts << [0, gd_val - 5.mm, z_top]
        (1..5).each do |i|
          angle = i * (Math::PI / 2.0) / 6.0
          pts << [0, gd_val - 5.mm + 5.mm * Math.sin(angle), z_top - 5.mm + 5.mm * Math.cos(angle)]
        end
        pts << [0, gd_val, z_top - 5.mm]
        
        # Screw channels on the back face of the vertical wall (pointing into wood)
        pts << [0, gd_val, z_top - 20.mm]
        pts << [0, gd_val + 3.mm, z_top - 20.mm]
        pts << [0, gd_val + 3.mm, z_top - 22.mm]
        pts << [0, gd_val, z_top - 22.mm]
        
        pts << [0, gd_val, z_top - gh + 22.mm]
        pts << [0, gd_val + 3.mm, z_top - gh + 22.mm]
        pts << [0, gd_val + 3.mm, z_top - gh + 20.mm]
        pts << [0, gd_val, z_top - gh + 20.mm]
        
        # Rounded outer back-bottom corner
        pts << [0, gd_val, z_top - gh + 5.mm]
        (1..5).each do |i|
          angle = i * (Math::PI / 2.0) / 6.0
          pts << [0, gd_val - 5.mm + 5.mm * Math.cos(angle), z_top - gh + 5.mm - 5.mm * Math.sin(angle)]
        end
        pts << [0, gd_val - 5.mm, z_top - gh]
        
        pts << [0, 0, z_top - gh]           # Bottom-front corner
        pts << [0, 0, z_top - gh + 6.mm]    # Bottom-front lip top
        pts << [0, 2.mm, z_top - gh + 6.mm] # Bottom-front lip back hook
        pts << [0, 2.mm, z_top - gh + 2.mm] # Inner bottom wall start
        
        # Curve inside back-bottom corner
        pts << [0, gd_val - 5.mm, z_top - gh + 2.mm]
        (1..5).each do |i|
          angle = i * (Math::PI / 2.0) / 6.0
          pts << [0, gd_val - 5.mm + 3.mm * Math.sin(angle), z_top - gh + 2.mm + 3.mm - 3.mm * Math.cos(angle)]
        end
        pts << [0, gd_val - 2.mm, z_top - gh + 5.mm]
        
        pts << [0, gd_val - 2.mm, z_top - 5.mm] # Smooth vertical wall front face
        
        # Curve inside back-top corner
        (1..5).each do |i|
          angle = i * (Math::PI / 2.0) / 6.0
          pts << [0, gd_val - 5.mm + 3.mm * Math.cos(angle), z_top - 5.mm + 3.mm * Math.sin(angle)]
        end
        pts << [0, gd_val - 5.mm, z_top - 2.mm]
        
        pts << [0, 2.mm, z_top - 2.mm]     # Inner top wall start
        pts << [0, 2.mm, z_top - 6.mm]     # Top-front lip back hook
        
      elsif g_type == "German_L"
        # German L-Gola: 17-point closed polygon lining the notch floor (y=0 to gd_val),
        # wrapping over the wood rail at y=gd_val (z=z_top), and wrapping under the wood rail at y=gd_val (z=z_bot).
        t       = 1.2.mm
        y_back  = gd_val
        y_inner = y_back  - t
        y_fh    = y_back  + 6.7.mm  # top flange back end (goes deeper)
        y_hi    = y_fh    - t
        y_no    = y_back  + 4.0.mm  # bottom flange back end
        y_ni    = y_no    - t
        hk      = 3.0.mm            # top hook drop depth
        ns      = 4.8.mm            # bottom nose drop depth
        z_bot   = z_top  - gh

        pts << [0, y_fh,    z_top - hk   ]   # p1  top hook bottom-right
        pts << [0, y_fh,    z_top        ]   # p2  top hook top-right
        pts << [0, y_back,  z_top        ]   # p3  top-back corner
        pts << [0, y_back,  z_bot        ]   # p4  back wall bottom-back
        pts << [0, y_back,  z_bot - ns   ]   # p5  bottom flange outer-bottom-left
        pts << [0, y_no,    z_bot - ns   ]   # p6  bottom flange outer-bottom-right
        pts << [0, y_no,    z_bot - ns + t]  # p7  bottom flange inner-top-right
        pts << [0, y_back + t, z_bot - ns + t] # p8 bottom flange inner-top-left
        pts << [0, y_back + t, z_bot     ]   # p9  bottom flange inner-top
        pts << [0, 0,       z_bot        ]   # p10 bottom-front outer corner
        pts << [0, 0,       z_bot + 6.mm ]   # p11 front lip top-front
        pts << [0, t,       z_bot + 6.mm ]   # p12 front lip top-back
        pts << [0, t,       z_bot + t    ]   # p13 bottom plate inner-front
        pts << [0, y_inner, z_bot + t    ]   # p14 bottom plate inner-back
        pts << [0, y_inner, z_top - t    ]   # p15 back wall inner-top
        pts << [0, y_hi,    z_top - t    ]   # p16 top flange inner-bottom
        pts << [0, y_hi,    z_top - hk   ]   # p17 top hook inner-left

      elsif g_type == "German_U"
        # German U-Gola: Symmetrical 20-point C-Gola profile sitting inside the notch,
        # wrapping over the top rail (at z_top) and wrapping under the bottom rail (at z_bot).
        t       = 1.2.mm
        y_back  = gd_val
        y_inner = y_back  - t
        y_fh    = y_back  + 6.7.mm  # symmetrical top/bottom flange back end
        y_hi    = y_fh    - t
        hk      = 3.0.mm            # hook depth
        z_bot   = z_top   - gh

        pts << [0, y_fh,    z_top - hk   ]   # p1  top hook bottom-right
        pts << [0, y_fh,    z_top        ]   # p2  top hook top-right
        pts << [0, 0,       z_top        ]   # p3  top-front outer corner
        pts << [0, 0,       z_top - 6.mm ]   # p4  top lip bottom-front
        pts << [0, t,       z_top - 6.mm ]   # p5  top lip bottom-back
        pts << [0, t,       z_top - t    ]   # p6  top plate inner-front
        pts << [0, y_inner, z_top - t    ]   # p7  top plate inner-back
        pts << [0, y_inner, z_bot + t    ]   # p8  back wall inner-bottom
        pts << [0, t,       z_bot + t    ]   # p9  bottom plate inner-back
        pts << [0, t,       z_bot + 6.mm ]   # p10 bottom lip top-back
        pts << [0, 0,       z_bot + 6.mm ]   # p11 bottom lip top-front
        pts << [0, 0,       z_bot        ]   # p12 bottom-front outer corner
        pts << [0, y_fh,    z_bot        ]   # p13 bottom hook bottom-right
        pts << [0, y_fh,    z_bot + hk   ]   # p14 bottom hook top-right
        pts << [0, y_hi,    z_bot + hk   ]   # p15 bottom hook top-left
        pts << [0, y_hi,    z_bot + t    ]   # p16 bottom flange inner-top
        pts << [0, y_back,  z_bot + t    ]   # p17 back wall outer-bottom
        pts << [0, y_back,  z_top - t    ]   # p18 back wall outer-top
        pts << [0, y_hi,    z_top - t    ]   # p19 top flange inner-bottom
        pts << [0, y_hi,    z_top - hk   ]   # p20 top hook bottom-left
      end
      
      face = g_ent.add_face(pts) rescue nil
      if face
        face.reverse! if face.normal.x < 0
        face.pushpull(w)
        
        comp = g_grp.to_component
        comp.definition.name = "Gola_Profile_#{spec[:type]}_#{idx + 1}"
        comp.name = "Gola_Profile"
        comp.material = mat
        
        ["opencutlist", "OpenCutList"].each do |dict|
          comp.material.set_attribute(dict, "type", "hardware")
        end
      end
    end
  end

  def self.build_cabinet(data, target_grp = nil)
    begin
      File.write(File.join(File.dirname(__FILE__), 'last_state.json'), data.to_json)
    rescue => e
      puts "Could not save last state: #{e}"
    end
    return if @working
    @working = true
    model = Sketchup.active_model
    @@dxf_parts = []
    begin
      # 1. Setup Materials
      g = data['global']
      m_car = apply_mat(model, "Carcass_#{data['materials']['mat_carcass_name']}", data['materials']['mat_carcass_tex'])
      m_f1 = apply_mat(model, "Front1_#{data['materials']['mat_front1_name']}", data['materials']['mat_front1_tex'], [200, 180, 150])
      m_f2 = apply_mat(model, "Front2_#{data['materials']['mat_front2_name']}", data['materials']['mat_front2_tex'], [80, 80, 85])
      m_back = apply_mat(model, "Back_#{data['materials']['mat_back_name']}", "")
      m_plinth = apply_mat(model, "Plinth_#{data['materials']['mat_plinth_name']}", "")

      # Initialize Transparency Materials
      mats = model.materials
      st = mats["SmartTrans"] || mats.add("SmartTrans")
      st.alpha = 0.4; st.color = [200, 220, 255]
      ss = mats["SmartSolid"] || mats.add("SmartSolid")
      ss.alpha = 1.0

      if target_grp && target_grp.valid?
        target_grp.entities.clear!
        main_cab = target_grp
      else
        sel = model.selection
        if sel.length == 1 && sel[0].is_a?(Sketchup::Group) && sel[0].get_attribute("SmartCabinet", "IsSmart")
          sel[0].entities.clear!
          main_cab = sel[0]
        else
          main_cab = model.active_entities.add_group
        end
      end

      main_cab.name = "SmartCabinet_#{data['box']['cab_type']}"
      main_cab.set_attribute("SmartCabinet", "IsSmart", true)
      main_cab.set_attribute("SmartCabinet", "Parameters", data.to_json)
      ent = main_cab.entities

      b, f, i_data = data['box'], data['front'], data['interior']
      h, d, w = b['height'].to_f.mm, b['depth'].to_f.mm, b['width'].to_f.mm
      t, bp, pl, gp = g['materialThickness'].to_f.mm, g['backThickness'].to_f.mm, g['plinthHeight'].to_f.mm, g['gap'].to_f.mm
      bt, tt, rw, ct = b['backType'], b['topType'], b['railWidth'].to_f.mm, b['connType']
      bi, gd = b['backInset'].to_f.mm, b['grooveDepth'].to_f.mm
      
      # Gola Settings
      is_gola = (f['front_type'].to_s.downcase.include?("gola") || 
                 f['handle_type'].to_s.downcase.include?("gola") || 
                 f['type'].to_s.downcase.include?("gola") || 
                 f['handles'].to_s.downcase.include?("gola"))
      g_type = f['gola_type']
      gh, gd_val = f['gola_size'].to_f.mm, f['gola_depth'].to_f.mm
      gr = f['gola_radius'] ? f['gola_radius'].to_f.mm : 5.mm
      gr = 5.mm if gr <= 0

      # Fronts Count & Drawer Height Pre-calculation
      dc = f['count'].to_i
      gap = 3.mm
      drw_h_total = 0.to_mm
      if f['front_type'] == "Drawers" && dc > 0
        if is_gola
          drw_h_total = (h - gp - (gh / 2.0) - (dc - 1) * (gh / 2.0)) / dc
        else
          int_h = (h - 2*t)
          drw_h_total = (int_h - (dc + 1) * gap) / dc
        end
      end

      # Dynamic Gola profiles collection
      gola_specs = []
      if is_gola
        # Top Gola profile must always be an L-profile, regardless of UI selection
        top_g_type = g_type
        top_gh = gh
        top_gd = gd_val
        
        if g_type == "German_U" || g_type == "German_L"
          top_g_type = "German_L"
          top_gh = 57.9.mm
          top_gd = 26.2.mm
        elsif g_type == "U" || g_type == "L"
          top_g_type = "L"
          top_gh = 57.mm
          top_gd = 26.mm
        end
        
        gola_specs << { type: top_g_type, z_top: pl + h, gh: top_gh, gd: top_gd, gr: gr }
        
        # Intermediate Gola profiles for drawers
        if f['front_type'] == "Drawers" && dc > 1
          (0...(dc - 1)).each do |i|
            dz_i = pl + gp + i * (drw_h_total + (gh / 2.0))
            z_g_center = dz_i + drw_h_total + (gh / 4.0)
            if g_type == "German_L" || g_type == "German_U"
              gh_u = 72.6.mm # German C-profile height
              z_g_top = z_g_center + (gh_u / 2.0)
              gola_specs << { type: "German_U", z_top: z_g_top, gh: gh_u, gd: gd_val, gr: gr }
            else
              gh_u = 73.mm # Standard Volpato U-profile height
              z_g_top = z_g_center + (gh_u / 2.0)
              gola_specs << { type: "U", z_top: z_g_top, gh: gh_u, gd: gd_val, gr: gr }
            end
          end
        end
      end

      sh, sz = (ct == "SideOverTop" ? [h, pl] : [h - 2*t, pl + t])
      # For Grooved back, all panels must go to full depth to have aligned grooves
      panel_d = (bt == "Grooved" ? d : (bt == "Nailed" ? d - bp : d - bi - bp))
      
      # PRE-CALCULATE SHELVES AND HOLES
      ns, s_inset = i_data['shelves'].to_i, i_data['shelf_inset'].to_f.mm
      ns = 0 if f['front_type'] == "Drawers"
      lb_step = (i_data['lb_step'] || 32).to_f.mm
      lb_qty = i_data['lb_qty'] || "Full"
      shelf_z_list = []
      actual_hole_z_list = []
      
      lb_anchor = pl + t + 100.mm
      
      if ns > 0
        ah = h - 2*t; sp = ah / (ns + 1).to_f
        (1..ns).each do |i|
          ideal_shelf_z = pl + t + i*sp - t/2.0
          if i_data['line_boring']
            k = ((ideal_shelf_z - 2.5.mm - lb_anchor) / lb_step).round
            actual_hz = lb_anchor + k * lb_step
            actual_shelf_z = actual_hz + 2.5.mm
            actual_hole_z_list << actual_hz
            shelf_z_list << actual_shelf_z
          else
            actual_shelf_z = ideal_shelf_z
            shelf_z_list << actual_shelf_z
          end
        end
      end
      
      create_p = lambda do |nm, x, y, z, pw, pd_val, ph, mat, side_type = nil, is_horiz = false|
        return if pw <= 0 || pd_val <= 0 || ph <= 0
        p_grp = ent.add_group; p_grp.name = nm
        p_grp.material = mat
        
        is_grooved = (bt == "Grooved" || bt == "Hybrid") && gd > 0
        
        part_data = {
          name: nm,
          length: (side_type ? ph : pw),
          width: pd_val,
          thickness: (side_type ? pw : ph),
          holes: [],
          grooves: []
        }
        if nm.downcase.include?("back panel")
          part_data[:length] = pw
          part_data[:width] = ph
          part_data[:thickness] = pd_val
        end

        if side_type && gola_specs && gola_specs.any?
          b_pts = []
          b_pts << [0.mm, 0.mm]
          b_pts << [0.mm, pd_val]
          b_pts << [ph, pd_val]
          
          # We trace the boundary from top (x = ph) to bottom (x = 0)
          sorted_notches = gola_specs.sort_by { |n| -n[:z_top] }
          
          sorted_notches.each do |n|
            n_top = n[:z_top] - z
            n_bot = n[:z_top] - n[:gh] - z
            gd_val_n = n[:gd]
            gr_n = n[:gr]
            
            next if n_top <= 0 || n_bot >= ph
            n_top_clipped = [n_top, ph].min
            n_bot_clipped = [n_bot, 0].max
            
            if n_top_clipped < ph
            b_pts << [n_top_clipped, 0.mm]
          end
            
            if gr_n > 0 && gr_n <= gd_val_n && gr_n <= n[:gh]
              r = gr_n
              if n[:type] == "U" || n[:type] == "German_U"
                cx_t = n_top - r
                cy_t = gd_val_n - r
                if cx_t < ph
                  b_pts << [n_top_clipped, cy_t]
                  (1..5).each do |i|
                    angle = i * (Math::PI / 2.0) / 6.0
                    b_pts << [cx_t + r * Math.cos(angle), cy_t + r * Math.sin(angle)]
                  end
                end
                
                cx_b = n_bot + r
                cy_b = gd_val_n - r
                if cx_b > 0
                  b_pts << [cx_b, cy_b + r]
                  (1..5).each do |i|
                    angle = i * (Math::PI / 2.0) / 6.0
                    b_pts << [cx_b - r * Math.sin(angle), cy_b + r * Math.cos(angle)]
                  end
                  b_pts << [cx_b - r, cy_b]
                end
              else
                cx = n_bot + r
                cy = gd_val_n - r
                b_pts << [n_top_clipped, gd_val_n]
                if cx > 0
                  b_pts << [cx, cy + r]
                  (1..5).each do |i|
                    angle = i * (Math::PI / 2.0) / 6.0
                    b_pts << [cx - r * Math.sin(angle), cy + r * Math.cos(angle)]
                  end
                  b_pts << [cx - r, cy]
                end
              end
            else
              b_pts << [n_top_clipped, gd_val_n]
              b_pts << [n_bot_clipped, gd_val_n]
            end
            
            b_pts << [n_bot_clipped, 0.mm]
          end
          
          b_pts << [0.mm, 0.mm]
          b_pts.uniq!
          part_data[:boundary] = b_pts
        end
        
        if side_type
          if is_grooved
            g_start_y = pd_val - bi - bp
            g_end_y = pd_val - bi
            if side_type == :l
              draw_side_strip(p_grp.entities, x, y, y + pd_val, z, t - gd, ph, true, gola_specs)
              draw_side_strip(p_grp.entities, x + t - gd, y, y + g_start_y, z, gd, ph, true, gola_specs)
              draw_side_strip(p_grp.entities, x + t - gd, y + g_end_y, y + pd_val, z, gd, ph, false, gola_specs)
            else
              draw_side_strip(p_grp.entities, x + gd, y, y + pd_val, z, t - gd, ph, true, gola_specs)
              draw_side_strip(p_grp.entities, x, y, y + g_start_y, z, gd, ph, true, gola_specs)
              draw_side_strip(p_grp.entities, x, y + g_end_y, y + pd_val, z, gd, ph, false, gola_specs)
            end
          else
            draw_side_strip(p_grp.entities, x, y, y + pd_val, z, pw, ph, true, gola_specs)
          end
        elsif bt == "Grooved" && gd > 0 && is_horiz
          g_start_y = pd_val - bi - bp
          g_end_y = pd_val - bi
          box(p_grp.entities, x, y, z + gd, pw, pd_val, t - gd)
          box(p_grp.entities, x, y, z, pw, g_start_y, gd)
          box(p_grp.entities, x, y + g_end_y, z, pw, bi, gd)
        else
          box(p_grp.entities, x, y, z, pw, pd_val, ph)
        end

        # Line Boring (Shelf Pin Holes)
        if side_type && i_data['line_boring']
          lb_f, lb_b = i_data['lb_offset_f'].to_f.mm, i_data['lb_offset_b'].to_f.mm
          holes_to_drill = []
          
          if lb_qty == "Full"
            end_z = pl + h - t - 100.mm
            (lb_anchor..end_z).step(lb_step) do |hz|
              holes_to_drill << hz
            end
          else
            qty = lb_qty.to_i
            half_qty = qty / 2
            actual_hole_z_list.each do |shz|
              (-half_qty..half_qty).each do |k|
                holes_to_drill << shz + k * lb_step
              end
            end
            holes_to_drill.uniq!
          end
          
          holes_to_drill.each do |hz|
            if hz > pl + t + 20.mm && hz < pl + h - t - 20.mm
              sxs, svs = (side_type == :l ? x + t : x), (side_type == :l ? 1 : -1)
              hole(p_grp.entities, [sxs, y + lb_f, hz], [svs, 0, 0], 2.5.mm, 12.mm, "C_BORE_5")
              hole(p_grp.entities, [sxs, y + pd_val - lb_b, hz], [svs, 0, 0], 2.5.mm, 12.mm, "C_BORE_5")
              part_data[:holes] << [hz - z, lb_f, 2.5.mm, 12.mm]
              part_data[:holes] << [hz - z, pd_val - lb_b, 2.5.mm, 12.mm]
            end
          end
        end

        # Track Grooves for DXF
        if side_type && is_grooved
          part_data[:grooves] << [0, g_start_y, ph, g_start_y]
          part_data[:grooves] << [ph, g_start_y, ph, g_end_y]
          part_data[:grooves] << [ph, g_end_y, 0, g_end_y]
          part_data[:grooves] << [0, g_end_y, 0, g_start_y]
        elsif bt == "Grooved" && gd > 0 && is_horiz
          part_data[:grooves] << [0, g_start_y, pw, g_start_y]
          part_data[:grooves] << [pw, g_start_y, pw, g_end_y]
          part_data[:grooves] << [pw, g_end_y, 0, g_end_y]
          part_data[:grooves] << [0, g_end_y, 0, g_start_y]
        end

        # Joinery Screws (CNC Ready)
        if (side_type || is_horiz) && b['connector_type'] == "Screw_3.5"
          # Logic for assembly screws...
        end
        
        # Convert to component for OpenCutList
        p_comp = p_grp.to_component
        p_comp.definition.name = nm
        p_comp.name = nm
        p_comp.material = mat
        @@dxf_parts << part_data
        p_comp
      end

      # Construct Box
      if ct == "SideOverTop"
        create_p.call("Left Side", 0, 0, pl, t, d, h, m_car, :l)
        create_p.call("Right Side", w - t, 0, pl, t, d, h, m_car, :r)
        create_p.call("Bottom", t, 0, pl, w - 2 * t, panel_d, t, m_car, nil, true)
        create_p.call("Top", t, (is_gola ? gd_val + 12.mm : 0), pl + h - t, w - 2 * t, (is_gola ? panel_d - gd_val - 12.mm : panel_d), t, m_car, nil, true) if tt != "Rails"
      else
        create_p.call("Bottom", 0, 0, pl, w, panel_d, t, m_car, nil, true)
        create_p.call("Top", 0, (is_gola ? gd_val + 12.mm : 0), pl + h - t, w, (is_gola ? panel_d - gd_val - 12.mm : panel_d), t, m_car, nil, true) if tt != "Rails"
        create_p.call("Left Side", 0, 0, sz, t, d, sh, m_car, :l)
        create_p.call("Right Side", w - t, 0, sz, t, d, sh, m_car, :r)
      end

      # Rails
      if tt == "Rails"
        rx, rwv = (ct == "SideOverTop" ? [t, w - 2 * t] : [0, w])
        if is_gola
          # Vertical Front Rail for Gola
          create_p.call("Top Front Rail (V)", rx, gd_val, pl + h - gh, rwv, t, gh - 4.mm, m_car)
        else
          # Standard Horizontal Rail
          create_p.call("Top Front Rail", rx, 0, pl + h - t, rwv, rw, t, m_car)
        end
        create_p.call("Top Back Rail", rx, panel_d - rw, pl + h - t, rwv, rw, t, m_car)
      end
      
      # Plinth
      if pl > 0
        base_type = g['base_type'] || "Box"
        if base_type == "Box"
          create_p.call("Plinth Front", 0, b['plinthInsetF'].to_f.mm, 0, w, t, pl, m_plinth)
          create_p.call("Plinth Back", 0, d - t - b['plinthInsetB'].to_f.mm, 0, w, t, pl, m_plinth)
        elsif base_type == "FrontLegs"
          create_p.call("Plinth Front", 0, b['plinthInsetF'].to_f.mm, 0, w, t, pl, m_plinth)
          draw_legs(ent, w, d, pl, b, t)
        elsif base_type == "LegsOnly"
          draw_legs(ent, w, d, pl, b, t)
        end
      end

      # Back
      if bp > 0
        if bt == "Grooved"
          bw, bh = w - 2*t + 2*gd, h - (ct == "SideOverTop" ? 0 : 2*t) + 2*gd
          bz = pl + (ct == "SideOverTop" ? -gd : t - gd)
          create_p.call("Back Panel", t - gd, d - bi - bp, bz, bw, bp, bh, m_back)
        elsif bt == "Hybrid"
          bh = (ct == "SideOverTop" ? h : h - 2*t)
          bz = pl + (ct == "SideOverTop" ? 0 : t)
          create_p.call("Back Panel", t - gd, d - bi - bp, bz, w - 2*t + 2*gd, bp, bh, m_back)
        else
          create_p.call("Back Panel", 0, d - bp, pl, w, bp, h, m_back)
        end
      end

      # Draw Gola Profiles if applicable
      if is_gola
        m_gola = apply_mat(model, "Hardware_Gola_Profile", "", [220, 220, 220])
        self.draw_gola(ent, w, d, pl, h, f, m_gola, gola_specs)
      end

      # Shelves & Pins
      if ns > 0
        m_pin = apply_mat(model, "Hardware_Shelf_Pin", "", [200, 200, 200])
        (1..ns).each do |i|
          sz_val = shelf_z_list[i-1]
          create_p.call("Shelf #{i}", t + 2.mm, s_inset, sz_val, w - 2*t - 4.mm, panel_d - s_inset, t, m_car)
          
          if i_data['line_boring']
            hz = sz_val - 2.5.mm
            lb_f, lb_b = i_data['lb_offset_f'].to_f.mm, i_data['lb_offset_b'].to_f.mm
            # Draw 4 pins (little 3D cylinders sticking out of side panels to support shelf)
            [[t, lb_f, 1], [t, d - lb_b, 1], [w - t, lb_f, -1], [w - t, d - lb_b, -1]].each do |px, py, dir|
              p_grp = ent.add_group
              p_grp.name = "Shelf_Support_Pin"
              p_grp.material = m_pin
              ci = p_grp.entities.add_circle([px, py, hz], [dir, 0, 0], 2.5.mm)
              f_face = p_grp.entities.add_face(ci) rescue nil
              if f_face
                f_face.reverse! if (dir == 1 && f_face.normal.x < 0) || (dir == -1 && f_face.normal.x > 0)
                f_face.pushpull(8.mm)
              end
              comp = p_grp.to_component
              comp.definition.name = "Shelf_Support_Pin"
              comp.name = "Shelf_Support_Pin"
              comp.material = m_pin
              ["opencutlist", "OpenCutList"].each { |dict| comp.material.set_attribute(dict, "type", "hardware") }
            end
          end
        end
      end

      # Fronts (Doors/Drawers)
      ht = f['handle_type']
      if f['front_type'] == "Doors" && f['count'].to_i > 0
        dc = f['count'].to_i
        dz = pl + gp
        dh = is_gola ? (h - (gh / 2.0) - gp) : (h - 2*gp)
        dw = (dc == 1) ? w - 2*gp : (w - 3*gp) / 2.0
        [0, (dc == 2 ? 1 : nil)].compact.each do |i|
          dsx = (i == 0) ? gp : w / 2.0 + gp / 2.0
          d_grp = ent.add_group; d_grp.name = "Door_#{i+1}"
          d_grp.material = (i == 0 ? m_f1 : m_f2)
          box(d_grp.entities, dsx, -t, dz, dw, t, dh)
          
          door_part = {
            name: "Door_#{i+1}",
            length: dh,
            width: dw,
            thickness: t,
            holes: [],
            grooves: []
          }
          
          if ht == "Knob" || ht == "Bar"
            hx = (dc == 1) ? dsx + dw - 30.mm : (i == 0 ? dsx + dw - 30.mm : dsx + 30.mm)
            hz_h = dz + dh / 2.0
            add_handle(d_grp.entities, ht, hx, -t, hz_h)
            
            local_y = (dc == 1) ? dw - 30.mm : (i == 0 ? dw - 30.mm : 30.mm)
            if ht == "Knob"
              door_part[:holes] << [dh / 2.0, local_y, 2.to_mm, 15.mm]
            elsif ht == "Bar"
              door_part[:holes] << [dh / 2.0 - 48.mm, local_y, 2.to_mm, 15.mm]
              door_part[:holes] << [dh / 2.0 + 48.mm, local_y, 2.to_mm, 15.mm]
            end
          end
          
          hinge_type = f['hingeType'] || "None"
          if hinge_type == "Blum_ClipTop" || hinge_type == "Salice_110"
            h_offset = (f['hingeOffset'] || 120).to_f.mm
            hinge_zs = [dz + h_offset, dz + dh - h_offset]
            if dh > 900.mm && dh <= 1600.mm
              hinge_zs << dz + dh / 2.0
            elsif dh > 1600.mm
              hinge_zs = [dz + h_offset, dz + dh/3.0, dz + 2.0*dh/3.0, dz + dh - h_offset]
            end
            
            is_right_hinge = (i == 1)
            hx_carcass = is_right_hinge ? w - t : t
            
            hinge_zs.each do |hz|
              m_hinge = apply_mat(model, "Hardware_Hinge", "", [150, 150, 150])
              draw_blum_hinge(ent, hx_carcass, -t, hz, m_hinge, is_right_hinge)
              
              door_hx = is_right_hinge ? dw - 22.5.mm : 22.5.mm
              door_part[:holes] << [hz - dz, door_hx, 17.5.to_mm, 12.mm]
              
              side_name = is_right_hinge ? "Right Side" : "Left Side"
              side_part = @@dxf_parts.find { |p| p[:name] == side_name }
              if side_part
                side_part[:holes] << [hz - pl + 16.mm, 37.mm, 2.5.to_mm, 12.mm]
                side_part[:holes] << [hz - pl - 16.mm, 37.mm, 2.5.to_mm, 12.mm]
              end
            end
          end
          
          @@dxf_parts << door_part
        end
      elsif f['front_type'] == "Drawers" && f['count'].to_i > 0
        dc = f['count'].to_i; gap = 3.mm
        # Available internal space
        int_w = w - 2*t
        int_h = is_gola ? (h - t - gh) : (h - 2*t)
        int_d = d - bi
        
        # Safety check for missing drawer data (e.g. old presets)
        drw = data['drawer'] || {}
        dt = (drw['mat_th'] || 16).to_f.mm
        rg = (drw['runner_gap'] || 13).to_f.mm
        dbth = (drw['bottom_th'] || 8).to_f.mm
        dbi = (drw['bottom_inset'] || 12).to_f.mm
        dbg = (drw['bottom_groove'] || 8).to_f.mm
        db_gap = (drw['back_gap'] || 10).to_f.mm
        
        (0...dc).each do |i|
          if is_gola
            dz = pl + gp + i * (drw_h_total + (gh / 2.0))
          else
            dz = pl + t + gap + i * (drw_h_total + gap)
          end
          # 1. Front Panel (Visual)
          f_grp = ent.add_group; f_grp.name = "Drawer_Front_#{i+1}"
          f_grp.material = m_f1
          box(f_grp.entities, gp, -t, dz, w - 2*gp, t, drw_h_total)
          
          f_part = {
            name: "Drawer_Front_#{i+1}",
            length: w - 2*gp,
            width: drw_h_total,
            thickness: t,
            holes: [],
            grooves: []
          }
          
          if ht == "Knob" || ht == "Bar"
            hx = w / 2.0
            hz_h = dz + drw_h_total / 2.0
            add_handle(f_grp.entities, ht, hx, -t, hz_h)
            
            cx = (w - 2*gp) / 2.0
            cy = drw_h_total / 2.0
            if ht == "Knob"
              f_part[:holes] << [cx, cy, 2.to_mm, 15.mm]
            elsif ht == "Bar"
              f_part[:holes] << [cx - 48.mm, cy, 2.to_mm, 15.mm]
              f_part[:holes] << [cx + 48.mm, cy, 2.to_mm, 15.mm]
            end
          end
          
          @@dxf_parts << f_part
          
          f_comp = f_grp.to_component
          f_comp.definition.name = "Drawer_Front_#{i+1}"
          f_comp.name = "Drawer_Front_#{i+1}"
          f_comp.material = m_f1
          
          # 2. Drawer Box (Construction)
          drw_y_start = 0
          box_dz_start = dz
          box_h = drw_h_total - 30.mm
          if is_gola && i > 0
            box_dz_start = dz + 31.5.mm
            box_h = drw_h_total - 61.5.mm
          end
          box_w = int_w - 2 * rg
          box_d = (int_d - drw_y_start) - db_gap; box_x = t + rg
          
          b_grp = ent.add_group; b_grp.name = "Drawer_Box_#{i+1}"
          b_grp.material = m_car
          b_ent = b_grp.entities
          
          # Drawer Sides
          box(b_ent, box_x, drw_y_start, box_dz_start, dt, box_d, box_h)
          box(b_ent, box_x + box_w - dt, drw_y_start, box_dz_start, dt, box_d, box_h)
          # Drawer Front/Back (Inner)
          box(b_ent, box_x + dt, drw_y_start, box_dz_start, box_w - 2*dt, dt, box_h)
          box(b_ent, box_x + dt, drw_y_start + box_d - dt, box_dz_start, box_w - 2*dt, dt, box_h)
          # Drawer Bottom
          box(b_ent, box_x + dt - dbg, drw_y_start + dt, box_dz_start + dbi, box_w - 2*dt + 2*dbg, box_d - 2*dt, dbth)
          
          b_comp = b_grp.to_component
          b_comp.definition.name = "Drawer_Box_#{i+1}"
          b_comp.name = "Drawer_Box_#{i+1}"
          b_comp.material = m_car
        end
      end
    rescue => e
      UI.messagebox("Build Error: #{e.message}")
    ensure
      @working = false
    end
  end

  # PRO HANDLES TOOL
  class SmartHandleTool
    def activate
      @cab = Sketchup.active_model.selection[0]
      unless @cab && @cab.valid? && @cab.get_attribute("SmartCabinet", "IsSmart")
        UI.messagebox("Επιλέξτε ένα Smart Cabinet πρώτα!")
        Sketchup.active_model.select_tool(nil)
        return
      end
      @hover_index = nil
    end

    def get_handles
      return [] unless @cab && @cab.valid?
      bb = @cab.bounds
      c = bb.center
      # Offset handles to the face centers for better visibility
      [
        {pos: c.offset([bb.width/2.0, 0, 0]), label: "ΠΛΑΤΟΣ (W)", color: "Red", key: "width"},
        {pos: c.offset([0, bb.depth/2.0, 0]), label: "ΒΑΘΟΣ (D)", color: "Green", key: "depth"},
        {pos: c.offset([0, 0, bb.height/2.0]), label: "ΥΨΟΣ (H)", color: "Blue", key: "height"}
      ]
    end

    def draw(view)
      handles = get_handles
      return if handles.empty?
      
      c = @cab.bounds.center
      view.line_width = 2
      
      handles.each_with_index do |h, i|
        # Draw Axis Line
        view.drawing_color = h[:color]
        view.line_stipple = ""
        view.draw(1, c, h[:pos]) # 1 = Sketchup::View::LINES
        
        # Draw Handle Point
        size = (i == @hover_index) ? 14 : 10
        view.draw_points([h[:pos]], size, 4, h[:color]) # 4 = Filled circle
        
        # Draw Text Label
        scr_pos = view.screen_coords(h[:pos])
        view.draw_text(scr_pos.offset([15, -15]), h[:label], {color: h[:color], font: "Arial", size: 12, bold: true})
      end
    end

    def onMouseMove(flags, x, y, view)
      handles = get_handles
      @hover_index = nil
      handles.each_with_index do |h, i|
        dist = view.screen_coords(h[:pos]).distance(Geom::Point3d.new(x, y, 0))
        if dist < 15
          @hover_index = i
          view.invalidate
          break
        end
      end
      view.invalidate if @hover_index.nil? # Reset if moved away
    end

    def onLButtonDown(flags, x, y, view)
      handles = get_handles
      handles.each do |h|
        dist = view.screen_coords(h[:pos]).distance(Geom::Point3d.new(x, y, 0))
        if dist < 20
          params = JSON.parse(@cab.get_attribute("SmartCabinet", "Parameters"))
          current_val = params['box'][h[:key]].to_f.mm
          
          res = UI.inputbox(["Νέα τιμή για #{h[:label]}:"], [current_val.to_s], "Smart Resize")
          if res
            begin
              # Convert input string to length (supports units like '60cm')
              new_val = res[0].to_l.to_mm
              params['box'][h[:key]] = new_val
              SmartCabinet::Maker.build_cabinet(params, @cab)
            rescue
              UI.messagebox("Άκυρη τιμή μονάδας!")
            end
          end
          return
        end
      end
    end
  end

  # =========================================================================
  # SMART VISION MODULE - Transparency Management
  # Replaces the old CabSelectionObserver with proper save/restore logic
  # =========================================================================
  module SmartVision
    extend self

    @original_states = {}   # entity_id => { material:, faces: [] }
    @ghost_active = false
    @hidden_doors = []

    DOOR_KEYWORDS = [
      'door', 'front', 'drawer_front', 'πόρτα', 'πορτα',
      'πρόσοψη', 'προσοψη', 'μέτωπο', 'μετωπο', 'facade'
    ].freeze

    # ----- GHOST MODE TOGGLE -----
    def toggle_ghost_mode
      model = Sketchup.active_model
      if @ghost_active
        restore_all(model)
        @ghost_active = false
        Sketchup.status_text = "Smart Vision: Ghost OFF"
      else
        targets = get_smart_cabinets(model)
        return UI.messagebox("Δεν βρέθηκαν Smart Cabinets.") if targets.empty?
        model.start_operation('Ghost Mode ON', true)
        targets.each { |cab| ghost_entity(cab, model, 0.35) }
        model.commit_operation
        @ghost_active = true
        Sketchup.status_text = "Smart Vision: Ghost ON — πατήστε ξανά για επαναφορά"
      end
    end

    # ----- HIDE / SHOW DOORS -----
    def toggle_hide_doors
      model = Sketchup.active_model
      if @hidden_doors.any?
        model.start_operation('Show Doors', true)
        @hidden_doors.each { |e| e.hidden = false if e.valid? }
        model.commit_operation
        @hidden_doors.clear
        Sketchup.status_text = "Smart Vision: Πόρτες εμφανείς"
      else
        targets = get_smart_cabinets(model)
        return UI.messagebox("Δεν βρέθηκαν Smart Cabinets.") if targets.empty?
        found = []
        targets.each { |cab| find_doors(cab, found) }
        if found.empty?
          UI.messagebox("Δεν βρέθηκαν πόρτες/προσόψεις.\nΤο plugin ψάχνει ονόματα: door, front, drawer_front, πόρτα κλπ.")
          return
        end
        model.start_operation('Hide Doors', true)
        found.each { |e| e.hidden = true; @hidden_doors << e }
        model.commit_operation
        Sketchup.status_text = "Smart Vision: #{found.length} πόρτες κρύφτηκαν"
      end
    end

    # ----- SMART LENS TOOL ACTIVATOR -----
    def activate_lens
      Sketchup.active_model.select_tool(SmartLensTool.new)
    end

    # ----- HELPERS -----
    def get_smart_cabinets(model)
      source = model.selection.empty? ? model.active_entities : model.selection
      source.select { |e|
        (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) &&
        e.get_attribute("SmartCabinet", "IsSmart")
      }
    end

    def ghost_entity(entity, model, alpha)
      id = entity.entityID
      unless @original_states.key?(id)
        @original_states[id] = { material: entity.material, sub: [] }
      end
      # Ghost the main group
      gm = model.materials.add("_sv_#{id}")
      gm.color = entity.material ? entity.material.color : Sketchup::Color.new(200,200,200)
      gm.alpha = alpha
      entity.material = gm
      # Ghost all sub-groups and components (panels)
      entity.entities.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }.each do |panel|
        pid = panel.entityID
        @original_states[id][:sub] << { id: pid, material: panel.material }
        pm = model.materials.add("_sv_#{pid}")
        pm.color = panel.material ? panel.material.color : Sketchup::Color.new(200,200,200)
        pm.alpha = alpha
        panel.material = pm
      end
    end

    def restore_all(model)
      model.start_operation('Restore Materials', true)
      @original_states.each do |eid, state|
        ent = find_entity(model, eid)
        next unless ent && ent.valid?
        ent.material = state[:material]
        state[:sub].each do |sub_state|
          sub = find_entity(model, sub_state[:id])
          sub.material = sub_state[:material] if sub && sub.valid?
        end
      end
      # Clean up temporary materials
      model.materials.select { |m| m.name.start_with?("_sv_") }.each do |m|
        model.materials.remove(m) rescue nil
      end
      model.commit_operation
      @original_states.clear
    end

    def find_entity(model, target_id)
      _search(model.active_entities, target_id)
    end

    def _search(entities, tid)
      entities.each do |e|
        return e if e.entityID == tid
        if e.is_a?(Sketchup::Group)
          r = _search(e.entities, tid)
          return r if r
        elsif e.is_a?(Sketchup::ComponentInstance)
          r = _search(e.definition.entities, tid)
          return r if r
        end
      end
      nil
    end

    def find_doors(entity, results)
      subs = entity.entities.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      subs.each do |s|
        name = s.respond_to?(:definition) ? (s.name.to_s + " " + s.definition.name.to_s) : s.name.to_s
        if DOOR_KEYWORDS.any? { |kw| name.downcase.include?(kw) }
          results << s
        else
          find_doors(s, results) if s.is_a?(Sketchup::Group)
        end
      end
    end
  end # SmartVision

  # =========================================================================
  # SMART LENS TOOL - Hover-based transparency (InteriorCAD style)
  # =========================================================================
  class SmartLensTool
    def initialize
      @last_cab = nil
      @saved = {}   # cab_entity_id => { material:, panels: [{entity:, material:}] }
      @alpha = 0.3
    end

    def activate
      Sketchup.status_text = "Smart Lens: hover σε ερμάριο → διαφάνεια | Click = κλείδωμα | ESC = έξοδος"
    end

    def deactivate(view)
      # Restore everything on exit
      @saved.each { |_id, st| restore_cab(st, view.model) }
      @saved.clear
      cleanup(view.model)
      view.invalidate
    end

    def onCancel(_reason, view)
      view.model.select_tool(nil)
    end

    def onKeyDown(key, _repeat, _flags, view)
      view.model.select_tool(nil) if key == 27 # ESC
    end

    def onMouseMove(_flags, x, y, view)
      ph = view.pick_helper
      ph.do_pick(x, y)
      picked = ph.best_picked
      cab = find_smart_parent(picked, view.model)

      if cab != @last_cab
        # Restore previous (unless locked by click)
        if @last_cab && @last_cab.valid?
          id = @last_cab.entityID
          if @saved[id] && !@saved[id][:locked]
            restore_cab(@saved.delete(id), view.model)
            cleanup(view.model)
          end
        end
        # Ghost new
        if cab && cab.valid?
          id = cab.entityID
          unless @saved.key?(id)
            @saved[id] = save_and_ghost(cab, view.model)
          end
          Sketchup.status_text = "Smart Lens: #{cab.name}"
        else
          Sketchup.status_text = "Smart Lens: hover σε ερμάριο..."
        end
        @last_cab = cab
        view.invalidate
      end
    end

    def onLButtonDown(_flags, _x, _y, _view)
      if @last_cab && @last_cab.valid?
        id = @last_cab.entityID
        @saved[id][:locked] = true if @saved[id]
        Sketchup.status_text = "Smart Lens: Κλειδωμένο σε #{@last_cab.name} — ESC για έξοδο"
        @last_cab = nil
      end
    end

    def getExtents
      Sketchup.active_model.bounds
    end

    private

    def find_smart_parent(entity, model)
      return nil unless entity
      current = entity
      # Walk up to group/component
      if current.is_a?(Sketchup::Face) || current.is_a?(Sketchup::Edge)
        parent = current.parent
        if parent.is_a?(Sketchup::ComponentDefinition)
          current = parent.instances.first
        elsif parent.respond_to?(:entities)
          # Try to find enclosing group or component
          model.active_entities.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }.each do |g|
            return g if g.get_attribute("SmartCabinet", "IsSmart") && g.entities.include?(current) rescue false
          end
        end
        return nil unless current
      end
      # Check if it's a smart cabinet or inside one
      if (current.is_a?(Sketchup::Group) || current.is_a?(Sketchup::ComponentInstance)) && current.get_attribute("SmartCabinet", "IsSmart")
        return current
      end
      # Check parent groups and components
      model.active_entities.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }.each do |g|
        if g.get_attribute("SmartCabinet", "IsSmart")
          g.entities.each do |sub|
            return g if sub == current || (sub.respond_to?(:entityID) && sub.entityID == current.entityID)
          end
        end
      end
      nil
    end

    def save_and_ghost(cab, model)
      state = { material: cab.material, panels: [], locked: false }
      # Ghost main group
      gm = model.materials.add("_lens_#{cab.entityID}")
      gm.color = cab.material ? cab.material.color : Sketchup::Color.new(180,200,220)
      gm.alpha = @alpha
      cab.material = gm
      # Ghost panels (groups and components)
      cab.entities.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }.each do |p|
        state[:panels] << { entity: p, material: p.material }
        pm = model.materials.add("_lens_#{p.entityID}")
        pm.color = p.material ? p.material.color : Sketchup::Color.new(180,200,220)
        pm.alpha = @alpha
        p.material = pm
      end
      state
    end

    def restore_cab(state, model)
      return unless state
      # Find the cabinet by checking if any panel is still valid
      state[:panels].each do |ps|
        ps[:entity].material = ps[:material] if ps[:entity].valid?
      end
    end

    def cleanup(model)
      model.materials.select { |m| m.name.start_with?("_lens_") }.each do |m|
        model.materials.remove(m) rescue nil
      end
    end
  end

  # AUTO-TRANSPARENCY OBSERVER
  # Automatically ghosts selected cabinets and restores deselected ones
  class CabSelectionObserver < Sketchup::SelectionObserver
    def initialize
      @ghosted = {}  # entity_id => { material:, sub: [{id:, material:}] }
    end

    # Called when clicking on empty space (full deselect)
    def onSelectionCleared(selection)
      restore_all_ghosted
    end

    def onSelectionBulkChange(selection)
      model = Sketchup.active_model
      
      # Find currently selected smart cabinets
      selected_ids = {}
      model.entities.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }.each do |g|
        if g.valid? && g.get_attribute("SmartCabinet", "IsSmart") && selection.contains?(g)
          selected_ids[g.entityID] = g
        end
      end

      # Restore cabinets that are no longer selected
      restore_deselected(selected_ids)

      # Ghost newly selected cabinets
      selected_ids.each do |eid, cab|
        next if @ghosted.key?(eid)
        ghost_cab(cab, model)
      end
    end

    private

    def restore_all_ghosted
      model = Sketchup.active_model
      return if @ghosted.empty?
      @ghosted.each do |eid, state|
        ent = SmartVision._search(model.active_entities, eid)
        next unless ent && ent.valid?
        ent.material = state[:material]
        state[:sub].each do |ss|
          sub = SmartVision._search(model.active_entities, ss[:id])
          sub.material = ss[:material] if sub && sub.valid?
        end
      end
      @ghosted.clear
      model.materials.select { |m| m.name.start_with?("_auto_") }.each { |m| model.materials.remove(m) rescue nil }
    end

    def restore_deselected(selected_ids)
      model = Sketchup.active_model
      @ghosted.keys.each do |eid|
        unless selected_ids.key?(eid)
          state = @ghosted.delete(eid)
          ent = SmartVision._search(model.active_entities, eid)
          next unless ent && ent.valid?
          ent.material = state[:material]
          state[:sub].each do |ss|
            sub = SmartVision._search(model.active_entities, ss[:id])
            sub.material = ss[:material] if sub && sub.valid?
          end
        end
      end
      model.materials.select { |m| m.name.start_with?("_auto_") }.each { |m| model.materials.remove(m) rescue nil } if @ghosted.empty?
    end

    def ghost_cab(cab, model)
      eid = cab.entityID
      state = { material: cab.material, sub: [] }
      gm = model.materials.add("_auto_#{eid}")
      gm.color = cab.material ? cab.material.color : Sketchup::Color.new(200,200,200)
      gm.alpha = 0.35
      cab.material = gm
      cab.entities.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }.each do |panel|
        pid = panel.entityID
        state[:sub] << { id: pid, material: panel.material }
        pm = model.materials.add("_auto_#{pid}")
        pm.color = panel.material ? panel.material.color : Sketchup::Color.new(200,200,200)
        pm.alpha = 0.35
        panel.material = pm
      end
      @ghosted[eid] = state
    end
  end

  def self.write_dxf(file_path, name, w_val, l_val, holes, grooves = [], boundary = [])
    drill_layers = holes.map { |h| "DRILL_#{sprintf("%g", (h[2]*2).to_mm)}" }.uniq
    layers = ["CUT", "GROOVE"] + drill_layers
    
    lines = []
    lines << "0"
    lines << "SECTION"
    lines << "2"
    lines << "HEADER"
    lines << "9"
    lines << "$ACADVER"
    lines << "1"
    lines << "AC1009"
    lines << "0"
    lines << "ENDSEC"
    
    lines << "0"
    lines << "SECTION"
    lines << "2"
    lines << "TABLES"
    lines << "0"
    lines << "TABLE"
    lines << "2"
    lines << "LAYER"
    lines << "70"
    lines << layers.length.to_s
    layers.each_with_index do |layer_name, idx|
      color = (idx % 7) + 1
      lines << "0"
      lines << "LAYER"
      lines << "2"
      lines << layer_name
      lines << "70"
      lines << "0"
      lines << "62"
      lines << color.to_s
    end
    lines << "0"
    lines << "ENDTAB"
    lines << "0"
    lines << "ENDSEC"
    
    lines << "0"
    lines << "SECTION"
    lines << "2"
    lines << "ENTITIES"
    
    draw_line = lambda do |x1, y1, x2, y2, layer = "CUT"|
      lines << "0"
      lines << "LINE"
      lines << "8"
      lines << layer
      lines << "10"
      lines << sprintf("%.3f", x1.to_mm)
      lines << "20"
      lines << sprintf("%.3f", y1.to_mm)
      lines << "30"
      lines << "0.0"
      lines << "11"
      lines << sprintf("%.3f", x2.to_mm)
      lines << "21"
      lines << sprintf("%.3f", y2.to_mm)
      lines << "31"
      lines << "0.0"
    end
    
    if boundary && !boundary.empty?
      (0...boundary.length).each do |i|
        pt1 = boundary[i]
        pt2 = boundary[(i + 1) % boundary.length]
        draw_line.call(pt1[0], pt1[1], pt2[0], pt2[1], "CUT")
      end
    else
      draw_line.call(0, 0, w_val, 0)
      draw_line.call(w_val, 0, w_val, l_val)
      draw_line.call(w_val, l_val, 0, l_val)
      draw_line.call(0, l_val, 0, 0)
    end
    
    holes.each do |h|
      hx, hy, r, d = h
      lines << "0"
      lines << "CIRCLE"
      lines << "8"
      lines << "DRILL_#{sprintf("%g", (r*2).to_mm)}"
      lines << "10"
      lines << sprintf("%.3f", hx.to_mm)
      lines << "20"
      lines << sprintf("%.3f", hy.to_mm)
      lines << "30"
      lines << "0.0"
      lines << "40"
      lines << sprintf("%.3f", r.to_mm)
    end
    
    grooves.each do |g|
      gx1, gy1, gx2, gy2 = g
      draw_line.call(gx1, gy1, gx2, gy2, "GROOVE")
    end
    
    lines << "0"
    lines << "ENDSEC"
    lines << "0"
    lines << "EOF"
    
    File.write(file_path, lines.join("\n"))
  end

  def self.show_dialog
    o = { 
      dialog_title: "Smart Cabinet Maker Pro v13.4", 
      preferences_key: "SmartCabinetMakerPro_UI", 
      width: 520, 
      height: 600, 
      left: 1200, 
      top: 400, 
      style: UI::HtmlDialog::STYLE_DIALOG 
    }
    @dialog = UI::HtmlDialog.new(o)
    @dialog.set_file(File.join(File.dirname(__FILE__), 'ui_v13', 'index.html'))
    @dialog.add_action_callback("buildCabinet") { |c, j| self.build_cabinet(JSON.parse(j)) }
    @dialog.add_action_callback("browseFile") { |c, id|
      path = UI.openpanel("Επιλογή Υλικού (Texture)", "", "*.jpg;*.png;*.bmp;*.tif;*.png")
      @dialog.execute_script("setFilePath('#{id}', '#{path.gsub('\\', '/')}')") if path
    }
    # Smart Vision callbacks from UI buttons
    @dialog.add_action_callback("ghostMode") { |c, _| SmartVision.toggle_ghost_mode }
    @dialog.add_action_callback("hideDoors") { |c, _| SmartVision.toggle_hide_doors }
    @dialog.add_action_callback("smartLens") { |c, _| SmartVision.activate_lens }
    @dialog.add_action_callback("resizeTool") { |c, _| Sketchup.active_model.select_tool(SmartHandleTool.new) }
    @dialog.add_action_callback("exportDXF") { |c, _|
      if !defined?(@@dxf_parts) || !@@dxf_parts || @@dxf_parts.empty?
        UI.messagebox("Σχεδιάστε πρώτα ένα ερμάριο!")
        next
      end
      
      folder = UI.select_directory(title: "Επιλέξτε φάκελο αποθήκευσης DXF")
      if folder
        begin
          count = 0
          @@dxf_parts.each do |p|
            clean_name = p[:name].gsub(" ", "_").gsub(/[^0-9A-Za-z_]/, "")
            file_path = File.join(folder, "#{clean_name}.dxf")
            self.write_dxf(file_path, p[:name], p[:length], p[:width], p[:holes], p[:grooves], p[:boundary])
            count += 1
          end
          UI.messagebox("Επιτυχής εξαγωγή #{count} αρχείων DXF στο φάκελο:\n#{folder}")
        rescue => e
          UI.messagebox("Σφάλμα κατά την εξαγωγή: #{e.message}")
        end
      end
    }
    
    @dialog.add_action_callback("fetchPresets") { |c, _|
      presets_path = File.join(File.dirname(__FILE__), 'presets.json')
      if File.exist?(presets_path)
        begin
          presets_data = File.read(presets_path)
          JSON.parse(presets_data) # Validate it is valid JSON
          @dialog.execute_script("updatePresetsList(#{presets_data})")
        rescue => e
          puts "Error parsing presets.json: #{e.message}"
        end
      else
        File.write(presets_path, "{}")
        @dialog.execute_script("updatePresetsList({})")
      end
      
      # Restore last state
      last_state_path = File.join(File.dirname(__FILE__), 'last_state.json')
      if File.exist?(last_state_path)
        begin
          last_data = File.read(last_state_path)
          JSON.parse(last_data)
          @dialog.execute_script("loadPresetData(#{last_data})")
        rescue => e
          puts "Error parsing last_state.json: #{e.message}"
        end
      end
    }

    @dialog.add_action_callback("savePreset") { |c, name, data_json|
      if name.to_s.empty?
        UI.messagebox("Δώστε ένα έγκυρο όνομα για το πρότυπο!")
        next
      end

      presets_path = File.join(File.dirname(__FILE__), 'presets.json')
      presets = {}
      if File.exist?(presets_path)
        begin
          presets = JSON.parse(File.read(presets_path))
        rescue
          presets = {}
        end
      end

      begin
        presets[name] = JSON.parse(data_json)
        File.write(presets_path, JSON.pretty_generate(presets))
        @dialog.execute_script("updatePresetsList(#{presets.to_json})")
        UI.messagebox("Το πρότυπο '#{name}' αποθηκεύτηκε επιτυχώς!")
      rescue => e
        UI.messagebox("Σφάλμα κατά την αποθήκευση: #{e.message}")
      end
    }

    @dialog.add_action_callback("loadPreset") { |c, name|
      next if name.to_s.empty?
      presets_path = File.join(File.dirname(__FILE__), 'presets.json')
      if File.exist?(presets_path)
        begin
          presets = JSON.parse(File.read(presets_path))
          if presets.key?(name)
            preset_data = presets[name]
            @dialog.execute_script("loadPresetData(#{preset_data.to_json})")
          end
        rescue => e
          puts "Error loading preset: #{e.message}"
        end
      end
    }
    @dialog.show
  end

    unless file_loaded?("smart_cabinet_maker_pro") || defined?(@menu_loaded)
      @menu_loaded = true
      m = UI.menu("Plugins").add_submenu("Smart Cabinet Maker Pro")
      m.add_item("Configurator") { self.show_dialog }
      file_loaded("smart_cabinet_maker_pro")
    end
  end
end
