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

  def self.build_cabinet(data, target_grp = nil)
    return if @working
    @working = true
    model = Sketchup.active_model
    begin
      mats = model.materials
      # Transparent Materials for Preview
      s_mat = mats["SmartSolid"] || mats.add("SmartSolid")
      s_mat.color, s_mat.alpha = [240, 240, 240], 1.0
      
      t_mat = mats["SmartTrans"] || mats.add("SmartTrans")
      t_mat.color, t_mat.alpha = [200, 220, 255], 0.5
      
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

      main_cab.name = "SmartCabinet"
      main_cab.set_attribute("SmartCabinet", "IsSmart", true)
      main_cab.set_attribute("SmartCabinet", "Parameters", data.to_json)
      main_cab.material = s_mat
      ent = main_cab.entities

      g, b, f, i_data = data['global'], data['box'], data['front'], data['interior']
      w, h, d = b['width'].to_f.mm, b['height'].to_f.mm, b['depth'].to_f.mm
      t, bp, pl, gp = g['materialThickness'].to_f.mm, g['backThickness'].to_f.mm, g['plinthHeight'].to_f.mm, g['gap'].to_f.mm
      bt, tt, rw, ct = b['backType'], b['topType'], b['railWidth'].to_f.mm, b['connType']
      bi, gd = b['backInset'].to_f.mm, b['grooveDepth'].to_f.mm

      sh, sz = (ct=="SideOverTop" ? [h-pl, pl] : [h-pl-2*t, pl+t])
      pd = (bt == "Nailed" ? d - bp : d - bi)
      
      ht, ho = f['hingeType'] || "None", f['hingeOffset'].to_f.mm
      rd, dp_h, cd, sd, so = 17.5.mm, 12.mm, 22.5.mm, 45.mm, 9.5.mm
      if ht == "Salice_110" then cd, sd, so = 24.mm, 48.mm, 6.mm
      elsif ht == "Hafele_Metalla" then cd, sd, so = 22.mm, 52.mm, 5.5.mm end
      h_pos = [ho, (h-pl-2*gp)-ho]; h_pos << (h-pl-2*gp)/2.0 if (h-pl-2*gp) > 1000.mm

      create_p = lambda do |nm, x, y, z, pw, pd_val, ph, side_type = nil|
        return if pw <= 0 || pd_val <= 0 || ph <= 0
        p_grp = ent.add_group; p_grp.name = nm
        box(p_grp.entities, x, y, z, pw, pd_val, ph)
        if side_type && ht != "None"
          h_pos.each do |hz|
            shz = hz + (pl + gp); sxs, svs = (side_type == :l ? x+t : x), (side_type == :l ? -1 : 1)
            hole(p_grp.entities, [sxs, y+37.mm, shz + 16.mm], [svs, 0, 0], 2.5.mm, 12.mm, "C_BORE_5")
            hole(p_grp.entities, [sxs, y+37.mm, shz - 16.mm], [svs, 0, 0], 2.5.mm, 12.mm, "C_BORE_5")
          end
        end
      end

      # Box
      if ct == "SideOverTop"
        create_p.call("Left Side", 0, 0, pl, t, d, sh, :l)
        create_p.call("Right Side", w-t, 0, pl, t, d, sh, :r)
        create_p.call("Bottom", t, 0, pl, w-2*t, pd, t)
        create_p.call("Top", t, 0, h-t, w-2*t, pd, t) if tt != "Rails"
      else
        create_p.call("Bottom", 0, 0, pl, w, pd, t)
        create_p.call("Top", 0, 0, h-t, w, pd, t) if tt != "Rails"
        create_p.call("Left Side", 0, 0, sz, t, d, sh, :l)
        create_p.call("Right Side", w-t, 0, sz, t, d, sh, :r)
      end

      if tt == "Rails"
        rx, rwv = (ct=="SideOverTop" ? [t, w-2*t] : [0, w])
        create_p.call("Top Front Rail", rx, 0, h-t, rwv, rw, t)
        create_p.call("Top Back Rail", rx, pd-rw, h-t, rwv, rw, t)
      end
      
      if pl > 0
        create_p.call("Plinth Front", 0, b['plinthInsetF'].to_f.mm, 0, w, t, pl)
        create_p.call("Plinth Back", 0, d-t-b['plinthInsetB'].to_f.mm, 0, w, t, pl)
      end

      if bp > 0
        if bt == "Groove"
          bw = w - 2*t + 2*gd; bh = h - pl - (ct == "SideOverTop" ? 2*t - 2*gd : 0)
          create_p.call("Back Panel", t-gd, d-bi-bp, pl + (ct == "SideOverTop" ? t-gd : 0), bw, bp, bh)
        else
          create_p.call("Back Panel", 0, d-bp, pl, w, bp, h-pl)
        end
      end

      ns = i_data['shelves'].to_i
      if ns > 0
        ah = h-pl-2*t; sp = ah/(ns+1).to_f
        (1..ns).each { |i| create_p.call("Shelf #{i}", t+2.mm, 20.mm, pl+t+i*sp-t/2.0, w-2*t-4.mm, pd-20.mm, t) }
      end

      if f['type'] == "Doors" && f['count'].to_i > 0
        dc = f['count'].to_i; dh, dz = h-pl-2*gp, pl+gp
        dw = (dc == 1) ? w-2*gp : (w-3*gp)/2.0
        [0, (dc == 2 ? 1 : nil)].compact.each do |i|
          dsx = (i == 0) ? gp : w/2.0 + gp/2.0
          d_grp = ent.add_group; d_grp.name = (i == 0 && dc == 2) ? "Left Door" : (i == 1 ? "Right Door" : "Door")
          box(d_grp.entities, dsx, -t, dz, dw, t, dh)
          if ht != "None"
            h_pos.each do |hz|
              real_z = dz + hz; cx = (i == 0) ? dsx + cd : dsx + dw - cd
              hole(d_grp.entities, [cx, -t, real_z], [0,-1,0], rd, dp_h, "C_BORE_35")
              sx = (i == 0) ? cx + so : cx - so
              hole(d_grp.entities, [sx, -t, real_z + 22.5.mm], [0,-1,0], 2.5.mm, 12.mm, "C_BORE_5")
              hole(d_grp.entities, [sx, -t, real_z - 22.5.mm], [0,-1,0], 2.5.mm, 12.mm, "C_BORE_5")
            end
          end
        end
      end
    rescue => e
      puts "Error: #{e.message}"
    ensure
      @working = false
    end
  end

  # PRO HANDLES TOOL
  class SmartHandleTool
    def activate
      @cab = Sketchup.active_model.selection[0]
      unless @cab && @cab.get_attribute("SmartCabinet", "IsSmart")
        UI.messagebox("Select a Smart Cabinet first!")
        Sketchup.active_model.select_tool(nil)
      end
    end

    def draw(view)
      return unless @cab && @cab.valid?
      bb = @cab.bounds; c = bb.center
      pts = [
        [c.offset([bb.width/2, 0, 0]), "ΠΛΑΤΟΣ", "Red"],
        [c.offset([0, bb.depth/2, 0]), "ΒΑΘΟΣ", "Green"],
        [c.offset([0, 0, bb.height/2]), "ΥΨΟΣ", "Blue"]
      ]
      pts.each do |p|
        view.drawing_color = p[2]
        view.draw_points([p[0]], 20, 3) # Large squares
        view.draw_text(view.screen_coords(p[0]), p[1])
      end
    end

    def onLButtonDown(flags, x, y, view)
      bb = @cab.bounds; c = bb.center
      params = JSON.parse(@cab.get_attribute("SmartCabinet", "Parameters"))
      pts = [
        [c.offset([bb.width/2, 0, 0]), "width"],
        [c.offset([0, bb.depth/2, 0]), "depth"],
        [c.offset([0, 0, bb.height/2]), "height"]
      ]
      pts.each do |p_data|
        scr_pt = view.screen_coords(p_data[0])
        dist = Math.sqrt((scr_pt.x - x)**2 + (scr_pt.y - y)**2)
        if dist < 20
          res = UI.inputbox(["Νέο #{p_data[1].upcase} (mm):"], [params['box'][p_data[1]]], "Αλλαγή Διάστασης")
          if res
            params['box'][p_data[1]] = res[0]
            SmartCabinetMaker.build_cabinet(params, @cab)
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
      s_mat, t_mat = m.materials["SmartSolid"], m.materials["SmartTrans"]
      m.entities.grep(Sketchup::Group).each do |g|
        if g.valid? && g.get_attribute("SmartCabinet", "IsSmart")
          g.material = (selection.contains?(g) ? t_mat : s_mat)
        end
      end
    end
  end

  def self.show_dialog
    o = { dialog_title: "Smart Cabinet Maker Pro v12.0", width: 800, height: 700, style: UI::HtmlDialog::STYLE_DIALOG }
    @dialog = UI::HtmlDialog.new(o)
    @dialog.set_file(File.join(File.dirname(__FILE__), 'ui', 'index.html'))
    @dialog.add_action_callback("buildCabinet") { |c, j| self.build_cabinet(JSON.parse(j)) }
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
