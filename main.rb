require 'sketchup.rb'
require 'json'

# VERSION 12.0 - PRO VISUALS & PREVIEW RESTORED
module SmartCabinetMaker
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

  # VERSION 12.5 - PRODUCTION READY
  def self.apply_mat(model, name, tex_path, color_rgb = [240, 240, 240])
    mats = model.materials
    m = mats[name] || mats.add(name)
    m.color = color_rgb
    if tex_path && tex_path != "" && File.exist?(tex_path)
      m.texture = tex_path rescue nil
      m.texture.size = [1000.mm, 1000.mm] if m.texture
    end
    m
  end

  def self.build_cabinet(data, target_grp = nil)
    return if @working
    @working = true
    model = Sketchup.active_model
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
      is_gola = (f['front_type'] == "Gola" || f['handle_type'] == "Gola")
      g_type = f['gola_type']
      gh, gd_val = f['gola_size'].to_f.mm, f['gola_depth'].to_f.mm
      gr = f['gola_radius'].to_f.mm # Future CNC layer info

      sh, sz = (ct == "SideOverTop" ? [h, pl] : [h - 2*t, pl + t])
      # For Grooved back, all panels must go to full depth to have aligned grooves
      panel_d = (bt == "Grooved" ? d : (bt == "Nailed" ? d - bp : d - bi))
      
      create_p = lambda do |nm, x, y, z, pw, pd_val, ph, mat, side_type = nil, is_horiz = false|
        return if pw <= 0 || pd_val <= 0 || ph <= 0
        p_grp = ent.add_group; p_grp.name = nm
        p_grp.material = mat
        
        # Gola Notch logic for Sides (L Profile)
        if is_gola && side_type && g_type == "L"
          # Side with L notch at the top front
          # Top part (shorter depth)
          box(p_grp.entities, x, y + gd_val, z + h - gh, pw, pd_val - gd_val, gh)
          # Bottom part (full depth)
          box(p_grp.entities, x, y, z, pw, pd_val, h - gh)
        elsif bt == "Grooved" && gd > 0 && (side_type || is_horiz)
          # Grooved Panel logic (from previous version)
          g_start_y = pd_val - bi - bp
          g_end_y = pd_val - bi
          if side_type == :l
            box(p_grp.entities, x, y, z, t - gd, pd_val, ph)
            box(p_grp.entities, x + t - gd, y, z, gd, g_start_y, ph)
            box(p_grp.entities, x + t - gd, y + g_end_y, z, gd, bi, ph)
          elsif side_type == :r
            box(p_grp.entities, x + gd, y, z, t - gd, pd_val, ph)
            box(p_grp.entities, x, y, z, gd, g_start_y, ph)
            box(p_grp.entities, x, y + g_end_y, z, gd, bi, ph)
          else # Horizontals
            box(p_grp.entities, x, y, z + gd, pw, pd_val, t - gd)
            box(p_grp.entities, x, y, z, pw, g_start_y, gd)
            box(p_grp.entities, x, y + g_end_y, z, pw, bi, gd)
          end
        else
          box(p_grp.entities, x, y, z, pw, pd_val, ph)
        end

        # Line Boring (Shelf Pin Holes)
        if side_type && i_data['line_boring']
          lb_f, lb_b = i_data['lb_offset_f'].to_f.mm, i_data['lb_offset_b'].to_f.mm
          step = 32.mm; start_z = pl + t + 100.mm; end_z = pl + h - t - 100.mm
          (start_z..end_z).step(step) do |hz|
            sxs, svs = (side_type == :l ? x + t : x), (side_type == :l ? -1 : 1)
            hole(p_grp.entities, [sxs, y + lb_f, hz], [svs, 0, 0], 2.5.mm, 12.mm, "C_BORE_5")
            hole(p_grp.entities, [sxs, y + pd_val - lb_b, hz], [svs, 0, 0], 2.5.mm, 12.mm, "C_BORE_5")
          end
        end

        # Joinery Screws (CNC Ready)
        if (side_type || is_horiz) && b['connector_type'] == "Screw_3.5"
          # Logic for assembly screws...
        end
      end

      # Construct Box
      if ct == "SideOverTop"
        create_p.call("Left Side", 0, 0, pl, t, d, h, m_car, :l)
        create_p.call("Right Side", w - t, 0, pl, t, d, h, m_car, :r)
        create_p.call("Bottom", t, 0, pl, w - 2 * t, panel_d, t, m_car, nil, true)
        create_p.call("Top", t, 0, pl + h - t, w - 2 * t, (is_gola ? panel_d - gd_val : panel_d), t, m_car, nil, true) if tt != "Rails"
      else
        create_p.call("Bottom", 0, 0, pl, w, panel_d, t, m_car, nil, true)
        create_p.call("Top", 0, 0, pl + h - t, w, (is_gola ? panel_d - gd_val : panel_d), t, m_car, nil, true) if tt != "Rails"
        create_p.call("Left Side", 0, 0, sz, t, d, sh, m_car, :l)
        create_p.call("Right Side", w - t, 0, sz, t, d, sh, m_car, :r)
      end

      # Rails
      if tt == "Rails"
        rx, rwv = (ct == "SideOverTop" ? [t, w - 2 * t] : [0, w])
        if is_gola
          # Vertical Front Rail for Gola
          create_p.call("Top Front Rail (V)", rx, gd_val, pl + h - gh - t, rwv, t, gh, m_car)
        else
          # Standard Horizontal Rail
          create_p.call("Top Front Rail", rx, 0, pl + h - t, rwv, rw, t, m_car)
        end
        create_p.call("Top Back Rail", rx, panel_d - rw, pl + h - t, rwv, rw, t, m_car)
      end
      
      # Plinth
      if pl > 0
        create_p.call("Plinth Front", 0, b['plinthInsetF'].to_f.mm, 0, w, t, pl, m_plinth)
        create_p.call("Plinth Back", 0, d - t - b['plinthInsetB'].to_f.mm, 0, w, t, pl, m_plinth)
      end

      # Back
      if bp > 0
        if bt == "Grooved"
          bw, bh = w - 2*t + 2*gd, h - (ct == "SideOverTop" ? 0 : 2*t) + 2*gd
          bz = pl + (ct == "SideOverTop" ? -gd : t - gd)
          create_p.call("Back Panel", t - gd, d - bi - bp, bz, bw, bp, bh, m_back)
        else
          create_p.call("Back Panel", 0, d - bp, pl, w, bp, h, m_back)
        end
      end

      # Shelves
      ns, s_inset = i_data['shelves'].to_i, i_data['shelf_inset'].to_f.mm
      if ns > 0
        ah = h - 2*t; sp = ah / (ns + 1).to_f
        (1..ns).each { |i| create_p.call("Shelf #{i}", t + 2.mm, s_inset, pl + t + i*sp - t/2.0, w - 2*t - 4.mm, panel_d - s_inset, t, m_car) }
      end

      # Fronts (Doors/Drawers)
      if f['front_type'] == "Doors" && f['count'].to_i > 0
        dc = f['count'].to_i; dh, dz = h - 2*gp, pl + gp
        dw = (dc == 1) ? w - 2*gp : (w - 3*gp) / 2.0
        [0, (dc == 2 ? 1 : nil)].compact.each do |i|
          dsx = (i == 0) ? gp : w / 2.0 + gp / 2.0
          d_grp = ent.add_group; d_grp.name = "Door_#{i+1}"
          d_grp.material = (i == 0 ? m_f1 : m_f2)
          box(d_grp.entities, dsx, -t, dz, dw, t, dh)
          # Handle logic...
        end
      elsif f['front_type'] == "Drawers" && f['count'].to_i > 0
        dc = f['count'].to_i; gap = 3.mm
        # Available internal space
        int_w = w - 2*t; int_h = h - 2*t; int_d = d - bi
        drw_h_total = (int_h - (dc + 1) * gap) / dc
        
        # Safety check for missing drawer data (e.g. old presets)
        drw = data['drawer'] || {}
        dt = (drw['mat_th'] || 16).to_f.mm
        rg = (drw['runner_gap'] || 13).to_f.mm
        dbth = (drw['bottom_th'] || 8).to_f.mm
        dbi = (drw['bottom_inset'] || 12).to_f.mm
        dbg = (drw['bottom_groove'] || 8).to_f.mm
        db_gap = (drw['back_gap'] || 10).to_f.mm
        
        (0...dc).each do |i|
          dz = pl + t + gap + i * (drw_h_total + gap)
          # 1. Front Panel (Visual)
          f_grp = ent.add_group; f_grp.name = "Drawer_Front_#{i+1}"
          f_grp.material = m_f1
          box(f_grp.entities, gp, -t, dz, w - 2*gp, t, drw_h_total)
          
          # 2. Drawer Box (Construction)
          box_w = int_w - 2 * rg; box_h = drw_h_total - 30.mm
          box_d = int_d - db_gap; box_x = t + rg
          
          b_grp = ent.add_group; b_grp.name = "Drawer_Box_#{i+1}"
          b_grp.material = m_car
          b_ent = b_grp.entities
          
          # Drawer Sides
          box(b_ent, box_x, 0, dz, dt, box_d, box_h)
          box(b_ent, box_x + box_w - dt, 0, dz, dt, box_d, box_h)
          # Drawer Front/Back (Inner)
          box(b_ent, box_x + dt, 0, dz, box_w - 2*dt, dt, box_h)
          box(b_ent, box_x + dt, box_d - dt, dz, box_w - 2*dt, dt, box_h)
          # Drawer Bottom
          box(b_ent, box_x + dt - dbg, dt, dz + dbi, box_w - 2*dt + 2*dbg, box_d - 2*dt, dbth)
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
              SmartCabinetMaker.build_cabinet(params, @cab)
            rescue
              UI.messagebox("Άκυρη τιμή μονάδας!")
            end
          end
          return
        end
      end
    end
  end

  # OBSERVER FOR TRANSPARENCY
  class CabSelectionObserver < Sketchup::SelectionObserver
    def onSelectionBulkChange(selection)
      m = Sketchup.active_model
      m.entities.grep(Sketchup::Group).each do |g|
        if g.valid? && g.get_attribute("SmartCabinet", "IsSmart")
          is_sel = selection.contains?(g)
          # Apply transparency to the main group and all sub-groups (panels)
          g.entities.grep(Sketchup::Group).each { |p| p.material.alpha = (is_sel ? 0.3 : 1.0) rescue nil }
        end
      end
    end
  end

  def self.show_dialog
    o = { dialog_title: "Smart Cabinet Maker Pro v12.0", width: 800, height: 700, style: UI::HtmlDialog::STYLE_DIALOG }
    @dialog = UI::HtmlDialog.new(o)
    @dialog.set_file(File.join(File.dirname(__FILE__), 'ui_v13', 'index.html'))
    @dialog.add_action_callback("buildCabinet") { |c, j| self.build_cabinet(JSON.parse(j)) }
    @dialog.add_action_callback("browseFile") { |c, id|
      path = UI.openpanel("Επιλογή Υλικού (Texture)", "", "*.jpg;*.png;*.bmp;*.tif;*.png")
      @dialog.execute_script("setFilePath('#{id}', '#{path.gsub('\\', '/')}')") if path
    }
    @dialog.show
    
    # Init Observer
    Sketchup.active_model.selection.add_observer(CabSelectionObserver.new) unless @obs_init
    @obs_init = true
  end

  unless file_loaded?(__FILE__)
    m = UI.menu("Plugins").add_submenu("Smart Cabinet Maker Pro")
    m.add_item("Configurator") { self.show_dialog }
    m.add_item("Resize Tool") { Sketchup.active_model.select_tool(SmartHandleTool.new) }
    file_loaded(__FILE__)
  end
end
