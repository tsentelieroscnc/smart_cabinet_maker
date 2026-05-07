require 'sketchup.rb'
require 'json'

module SmartCabinetMaker
  # Helper to draw a parametric panel
  def self.add_panel(parent, name, x, y, z, width, depth, height, groove = nil, side = :left)
    # groove: {depth: 8, inset: 15, thickness: 4}
    unique_name = "#{name}_#{Time.now.to_i}_#{rand(1000)}"
    comp_def = Sketchup.active_model.definitions.add(unique_name)
    if groove && groove[:depth] > 0
      g_depth = groove[:depth]
      g_inset = groove[:inset]
      g_thick = groove[:thickness]
      d_front = depth - g_inset - g_thick
      
      # Build it as 3 boxes that are guaranteed to touch
      if side == :left
        # Part 1: Outer part (left)
        add_box(comp_def.entities, 0, 0, 0, width - g_depth, depth, height)
        # Part 2 & 3 on the RIGHT face of the panel
        add_box(comp_def.entities, width - g_depth, 0, 0, g_depth, d_front, height) if d_front > 0.1
        add_box(comp_def.entities, width - g_depth, depth - g_inset, 0, g_depth, g_inset, height) if g_inset > 0.1
      else
        # For Right side: Mirror the logic manually within the definition
        # Part 1: Outer part (right)
        add_box(comp_def.entities, g_depth, 0, 0, width - g_depth, depth, height)
        # Part 2 & 3 on the LEFT face of the panel
        add_box(comp_def.entities, 0, 0, 0, g_depth, d_front, height) if d_front > 0.1
        add_box(comp_def.entities, 0, depth - g_inset, 0, g_depth, g_inset, height) if g_inset > 0.1
      end
    else
      add_box(comp_def.entities, 0, 0, 0, width, depth, height)
    end
    
    transform = Geom::Transformation.translation([x, y, z])
    instance = parent.entities.add_instance(comp_def, transform)
    instance.name = name
    instance
  end

  def self.add_box(entities, x, y, z, w, d, h)
    return if w <= 0 || d <= 0 || h <= 0
    pts = [ [x, y, z], [x + w, y, z], [x + w, y + d, z], [x, y + d, z] ]
    face = entities.add_face(pts)
    face.reverse! if face.normal.z < 0
    face.pushpull(h)
  end

  # Returns an array of Y coordinates for connectors along the depth
  def self.add_cylinder(entities, center, vector, radius, height)
    circle = entities.add_circle(center, vector, radius)
    face = entities.add_face(circle)
    face.pushpull(-height) # Push inside
  end

  def self.calculate_connectors(depth, mode, val, edge_offset)
    points = []
    return points if val <= 0
    
    if mode == "Manual"
      # val is the exact count of connectors
      if val == 1
        points << depth / 2.0
      elsif val == 2
        points << edge_offset
        points << depth - edge_offset
      else
        points << edge_offset
        points << depth - edge_offset
        remaining_count = val - 2
        if remaining_count > 0
          inner_dist = depth - 2 * edge_offset
          spacing = inner_dist / (remaining_count + 1).to_f
          (1..remaining_count).each do |i|
            points << edge_offset + i * spacing
          end
        end
      end
    else
      # val is the step distance (e.g. 150mm)
      points << edge_offset
      current_y = edge_offset + val.mm
      while current_y < (depth - edge_offset - 10.mm)
        points << current_y
        current_y += val.mm
      end
      points << depth - edge_offset if points.last < (depth - edge_offset - 10.mm)
    end
    points.sort.uniq
  end

  def self.generate_joinery(parent, points, type, conn_type, w, h, d, t, plinth)
    return if type == "None" || points.empty?
    
    radius = 4.mm # Default Dowel
    depth = 12.mm
    
    case type
    when "Screw"
      radius = 2.5.mm
      depth = 30.mm
    when "Minifix"
      radius = 7.5.mm
      depth = 13.mm
    end

    # Helper to find panel and its entities
    panels = parent.entities.grep(Sketchup::ComponentInstance)
    
    points.each do |y|
      if conn_type == "TopOverSide"
        # Drillings for Top/Bottom over Sides
        top = panels.find{|p| p.name == "Top"}
        bot = panels.find{|p| p.name == "Bottom"}
        l_side = panels.find{|p| p.name == "Left Side"}
        r_side = panels.find{|p| p.name == "Right Side"}

        # Left side connection (Z-axis drillings in T/B, X-axis in Sides)
        if top
            self.add_cylinder(top.definition, [t/2.0, y, 0], [0, 0, -1], radius, depth)
        end
        if bot
            self.add_cylinder(bot.definition, [t/2.0, y, t], [0, 0, 1], radius, depth)
        end
        if l_side
            self.add_cylinder(l_side.definition, [t, y, h - plinth - t - t/2.0], [1, 0, 0], radius, depth)
            self.add_cylinder(l_side.definition, [t, y, t/2.0], [1, 0, 0], radius, depth)
        end

        # Right side connection
        if top
            self.add_cylinder(top.definition, [w - t/2.0, y, 0], [0, 0, -1], radius, depth)
        end
        if bot
            self.add_cylinder(bot.definition, [w - t/2.0, y, t], [0, 0, 1], radius, depth)
        end
        if r_side
            self.add_cylinder(r_side.definition, [0, y, h - plinth - t - t/2.0], [-1, 0, 0], radius, depth)
            self.add_cylinder(r_side.definition, [0, y, t/2.0], [-1, 0, 0], radius, depth)
        end

      elsif conn_type == "SideOverTop"
        # Drillings for Sides over Top/Bottom
        top = panels.find{|p| p.name == "Top"}
        bot = panels.find{|p| p.name == "Bottom"}
        l_side = panels.find{|p| p.name == "Left Side"}
        r_side = panels.find{|p| p.name == "Right Side"}

        if l_side
            self.add_cylinder(l_side.definition, [t/2.0, y, 0], [0, 0, -1], radius, depth)
            self.add_cylinder(l_side.definition, [t/2.0, y, h - plinth], [0, 0, 1], radius, depth)
        end
        if r_side
            self.add_cylinder(r_side.definition, [t/2.0, y, 0], [0, 0, -1], radius, depth)
            self.add_cylinder(r_side.definition, [t/2.0, y, h - plinth], [0, 0, 1], radius, depth)
        end
        if top
            self.add_cylinder(top.definition, [0, y, t/2.0], [-1, 0, 0], radius, depth)
            self.add_cylinder(top.definition, [w - 2*t, y, t/2.0], [1, 0, 0], radius, depth)
        end
        if bot
            self.add_cylinder(bot.definition, [0, y, t/2.0], [-1, 0, 0], radius, depth)
            self.add_cylinder(bot.definition, [w - 2*t, y, t/2.0], [1, 0, 0], radius, depth)
        end
      end
    end
  end

  def self.add_handle(parent, type, x, y, z, parent_type)
    return if type == "None"
    
    if type == "Knob"
      # Small knob 30x30x20
      add_panel(parent, "Knob", x - 15.mm, y - 20.mm, z - 15.mm, 30.mm, 20.mm, 30.mm)
    elsif type == "Bar"
      if parent_type == "Drawer"
        # Horizontal bar
        add_panel(parent, "Bar Pull", x - 75.mm, y - 25.mm, z - 8.mm, 150.mm, 25.mm, 16.mm)
      else
        # Vertical bar
        add_panel(parent, "Bar Pull", x - 8.mm, y - 25.mm, z - 75.mm, 16.mm, 25.mm, 150.mm)
      end
    end
  end

  def self.build_cabinet(data)
    model = Sketchup.active_model
    
    # Busy flag check
    return if @is_building
    @is_building = true
    
    begin
      model.start_operation('Build Cabinet', true)
    
    g = data['global']
    b = data['box']
    f = data['front']
    
    w = b['width'].to_f.mm
    h = b['height'].to_f.mm
    d = b['depth'].to_f.mm
    
    t = g['materialThickness'].to_f.mm
    bp = g['backThickness'].to_f.mm
    plinth = g['plinthHeight'].to_f.mm
    gap = g['gap'].to_f.mm
    
    back_type = b['backType'] # "Nailed", "Grooved", or "Hybrid"
    top_type = b['topType']
    rail_width = b['railWidth'].to_f.mm
    plinth_inset_f = b['plinthInsetF'].to_f.mm
    plinth_inset_b = b['plinthInsetB'].to_f.mm
    conn_type = b['connType'] || "TopOverSide"
    back_inset = b['backInset'].to_f.mm
    groove_depth = b['grooveDepth'].to_f.mm
    handles = f['handles']
    
    # New Joinery Data
    j = data['joinery'] || {}
    conn_type_hardware = j['connectorType'] || "None"
    conn_mode = j['connectorMode'] || "Manual"
    conn_val = j['connectorVal'].to_f
    conn_offset = j['connectorOffset'].to_f.mm

    cabinet_group = nil
    sel = model.selection
    
    if sel.length == 1 && sel[0].is_a?(Sketchup::Group) && sel[0].get_attribute("SmartCabinet", "Parameters")
      cabinet_group = sel[0]
      cabinet_group.entities.clear!
    else
      cabinet_group = model.active_entities.add_group
    end
    
    cabinet_group.name = "Smart Cabinet #{b['width']}x#{b['height']}x#{b['depth']}"
    cabinet_group.set_attribute("SmartCabinet", "Parameters", data.to_json)
    cabinet_group.set_attribute("SmartCabinet", "IsSmartCabinet", true)
    


    # 1. Dimensions calculation based on joinery
    if conn_type == "SideOverTop"
      side_h = h - plinth
      side_z = plinth
      main_w = w - 2*t
      main_x = t
    else # TopOverSide or Miter
      side_h = h - plinth - 2*t
      side_z = plinth + t
      main_w = w
      main_x = 0
    end

    # 2. Back Panel & Depths
    if back_type == "Nailed"
      inner_depth = d - bp
      side_depth = d
      panel_depth = inner_depth
      back_y = inner_depth
      add_panel(cabinet_group, "Back Panel", t, back_y, plinth, w - 2*t, bp, h - plinth)
    elsif back_type == "Grooved"
      # Panels (Top, Bottom, Shelves) stop at the back panel
      panel_depth = d - back_inset
      side_depth = d
      back_y = d - back_inset - bp
      add_panel(cabinet_group, "Back Panel", t - groove_depth, back_y, plinth + t - groove_depth, w - 2*t + 2*groove_depth, bp, h - plinth - 2*t + 2*groove_depth)
    else # Hybrid (Grooved in Sides, Nailed to Top/Bottom)
      # Internal panels (Top, Bottom, Shelves) stop exactly at the back panel face
      panel_depth = d - back_inset - bp
      side_depth = d
      back_y = panel_depth
      
      # Back panel height is full (from plinth to top) to be nailed to T/B
      # Width includes groove depth for the sides
      add_panel(cabinet_group, "Back Panel", t - groove_depth, back_y, plinth, w - 2*t + 2*groove_depth, bp, h - plinth)
    end
    
    # Calculate Connectors now that panel_depth is defined
    if conn_type_hardware != "None"
      conn_points = calculate_connectors(panel_depth, conn_mode, conn_val, conn_offset)
      puts "DEBUG: Connector Points for #{conn_type_hardware}: #{conn_points.map{|p| p.to_mm.round(1)}}"
      generate_joinery(cabinet_group, conn_points, conn_type_hardware, conn_type, w, h, d, t, plinth)
    end
    
    # 3. Box Panels
    groove_info = nil
    if back_type != "Nailed"
        groove_info = {depth: groove_depth, inset: back_inset, thickness: bp}
    end

    if conn_type == "SideOverTop"
      add_panel(cabinet_group, "Left Side", 0, 0, plinth, t, side_depth, side_h, groove_info, :left)
      add_panel(cabinet_group, "Right Side", w - t, 0, plinth, t, side_depth, side_h, groove_info, :right)
      
      add_panel(cabinet_group, "Bottom", t, 0, plinth, w - 2*t, panel_depth, t)
      add_panel(cabinet_group, "Top", t, 0, h - t, w - 2*t, panel_depth, t)
    elsif conn_type == "TopOverSide"
      add_panel(cabinet_group, "Bottom", 0, 0, plinth, w, panel_depth, t)
      add_panel(cabinet_group, "Top", 0, 0, h - t, w, panel_depth, t)
      add_panel(cabinet_group, "Left Side", 0, 0, plinth + t, t, side_depth, side_h, groove_info, :left)
      add_panel(cabinet_group, "Right Side", w - t, 0, plinth + t, t, side_depth, side_h, groove_info, :right)
    else # Miter
      # Placeholder for miter
      add_panel(cabinet_group, "Bottom", 0, 0, plinth, w, panel_depth, t)
      add_panel(cabinet_group, "Top", 0, 0, h - t, w, panel_depth, t)
      add_panel(cabinet_group, "Left Side", 0, 0, plinth + t, t, side_depth, side_h, groove_info, :left)
      add_panel(cabinet_group, "Right Side", w - t, 0, plinth + t, t, side_depth, side_h, groove_info, :right)
    end
    
    # Override Top if Rails
    if top_type == "Rails"
        # Rails always at the top, inside the sides or over them
        # Let's just clear the "Top" and add rails
        top_panel = cabinet_group.entities.grep(Sketchup::ComponentInstance).find{|i| i.name == "Top"}
        top_panel.erase! if top_panel
        
        rx = (conn_type == "SideOverTop") ? t : 0
        rw = (conn_type == "SideOverTop") ? w - 2*t : w
        add_panel(cabinet_group, "Top Front Rail", rx, 0, h - t, rw, rail_width, t)
        add_panel(cabinet_group, "Top Back Rail", rx, panel_depth - rail_width, h - t, rw, rail_width, t)
    end

    # 4. Plinth
    if plinth > 0
      add_panel(cabinet_group, "Plinth Front", 0, plinth_inset_f, 0, w, t, plinth)
      add_panel(cabinet_group, "Plinth Back", 0, side_depth - t - plinth_inset_b, 0, w, t, plinth)
    end
    
    # 5. Interior
    shelves = data['interior']['shelves'].to_i
    v_dividers = data['interior']['verticalDividers'].to_i
    
    shelf_depth = panel_depth - 20.mm
    
    if v_dividers == 0
        if shelves > 0
            avail_h = h - plinth - 2*t
            spacing = avail_h / (shelves + 1).to_f
            shelf_w = w - 2*t
            
            (1..shelves).each do |i|
                shelf_z = plinth + t + i * spacing - t/2.0
                add_panel(cabinet_group, "Shelf #{i}", t, 20.mm, shelf_z, shelf_w, shelf_depth, t)
            end
        end
    else
        avail_w = w - 2*t
        div_w = t
        zone_w = (avail_w - div_w) / 2.0
        
        div_x = t + zone_w
        add_panel(cabinet_group, "Vertical Partition", div_x, 20.mm, plinth + t, div_w, shelf_depth, h - plinth - 2*t)
        
        if shelves > 0
            avail_h = h - plinth - 2*t
            spacing = avail_h / (shelves + 1).to_f
            
            (1..shelves).each do |i|
                shelf_z = plinth + t + i * spacing - t/2.0
                add_panel(cabinet_group, "Left Shelf #{i}", t, 20.mm, shelf_z, zone_w, shelf_depth, t)
                add_panel(cabinet_group, "Right Shelf #{i}", div_x + div_w, 20.mm, shelf_z, zone_w, shelf_depth, t)
            end
        end
    end
    
    # 5. Fronts
    front_type = f['type']
    
    if front_type == "Doors"
        doors = f['count'].to_i
        if doors > 0
            door_h = h - plinth - 2*gap
            door_y = -t
            door_z = plinth + gap
            if doors == 1
                door_w = w - 2*gap
                add_panel(cabinet_group, "Door", gap, door_y, door_z, door_w, t, door_h)
                hx = gap + door_w - 40.mm
                hy = door_y
                hz = door_z + door_h / 2.0
                add_handle(cabinet_group, handles, hx, hy, hz, "Door")
            elsif doors == 2
                door_w = (w - 3*gap) / 2.0
                left_door_x = gap
                right_door_x = w / 2.0 + gap / 2.0
                add_panel(cabinet_group, "Left Door", left_door_x, door_y, door_z, door_w, t, door_h)
                add_panel(cabinet_group, "Right Door", right_door_x, door_y, door_z, door_w, t, door_h)
                
                hx_left = left_door_x + door_w - 40.mm
                hx_right = right_door_x + 40.mm
                hy = door_y
                hz = door_z + door_h / 2.0
                add_handle(cabinet_group, handles, hx_left, hy, hz, "Door")
                add_handle(cabinet_group, handles, hx_right, hy, hz, "Door")
            end
        end
    elsif front_type == "Drawers"
        drawers = f['count'].to_i
        if drawers > 0
            avail_h = h - plinth - 2*gap
            drawer_h = (avail_h - (drawers - 1) * gap) / drawers.to_f
            drawer_w = w - 2*gap
            drawer_y = -t
            (0...drawers).each do |i|
                drawer_z = plinth + gap + i * (drawer_h + gap)
                add_panel(cabinet_group, "Drawer Front #{i+1}", gap, drawer_y, drawer_z, drawer_w, t, drawer_h)
                
                hx = gap + drawer_w / 2.0
                hy = drawer_y
                hz = drawer_z + drawer_h / 2.0
                add_handle(cabinet_group, handles, hx, hy, hz, "Drawer")
            end
        end
    end
    
    # 6. Apply Ghost Mode if requested
    if data['ui'] && data['ui']['ghostMode']
        cabinet_group.material = get_transparent_material
    else
        cabinet_group.material = nil
    end

    model.commit_operation
    ensure
      @is_building = false
    end
  end

  def self.show_dialog
    html_file = File.join(File.dirname(__FILE__), 'ui', 'index.html')
    
    options = {
      :dialog_title => "Smart Cabinet Maker Pro",
      :preferences_key => "com.antigravity.smartcabinetmaker",
      :scrollable => true,
      :resizable => true,
      :width => 800,
      :height => 700,
      :left => 100,
      :top => 100,
      :style => UI::HtmlDialog::STYLE_DIALOG
    }
    
    @dialog = UI::HtmlDialog.new(options)
    @dialog.set_file(html_file)
    
    @dialog.add_action_callback("buildCabinet") do |action_context, json_string|
      data = JSON.parse(json_string)
      self.build_cabinet(data)
    end

    @dialog.add_action_callback("fetchPresets") do |action_context|
      self.fetch_presets
    end

    @dialog.add_action_callback("savePreset") do |action_context, name, json_string|
      self.save_preset(name, json_string)
    end

    @dialog.add_action_callback("loadPreset") do |action_context, name|
      self.load_preset(name)
    end
    
    @dialog.show
    
    # If a cabinet is already selected, sync UI
    sel = Sketchup.active_model.selection
    if sel.length == 1 && sel[0].get_attribute("SmartCabinet", "Parameters")
      data_json = sel[0].get_attribute("SmartCabinet", "Parameters")
      @dialog.execute_script("updateUIFromData('#{data_json}')")
    end
  end

  @transparent_cabinets = []

  def self.transparent_cabinets
    @transparent_cabinets
  end

  def self.get_transparent_material
    model = Sketchup.active_model
    mat = model.materials["SmartCabinet_Ghost"]
    unless mat
      mat = model.materials.add("SmartCabinet_Ghost")
      mat.color = "gray"
      mat.alpha = 0.3 # 30% opacity
    end
    mat
  end

  def self.get_presets_path
    File.join(File.dirname(__FILE__), 'presets.json')
  end

  def self.fetch_presets
    path = get_presets_path
    presets = {}
    presets = JSON.parse(File.read(path)) if File.exist?(path)
    
    @dialog.execute_script("updatePresetList('#{presets.keys.to_json}')") if @dialog && @dialog.visible?
  end

  def self.save_preset(name, json_string)
    path = get_presets_path
    presets = {}
    presets = JSON.parse(File.read(path)) if File.exist?(path)
    
    new_data = JSON.parse(json_string)
    
    # Check for duplicates (same settings, different name)
    duplicate_name = nil
    presets.each do |pname, pdata|
      # Compare excluding name/UI specific fields if any
      if pdata == new_data && pname != name
        duplicate_name = pname
        break
      end
    end
    
    if duplicate_name
      res = UI.messagebox("Οι ρυθμίσεις αυτές υπάρχουν ήδη στο πρότυπο '#{duplicate_name}'. Θέλετε να τις αποθηκεύσετε και ως '#{name}';", MB_YESNO)
      return if res == IDNO
    end
    
    presets[name] = new_data
    File.write(path, presets.to_json)
    
    UI.messagebox("Το πρότυπο '#{name}' αποθηκεύτηκε επιτυχώς!")
    fetch_presets
  end

  def self.load_preset(name)
    path = get_presets_path
    return unless File.exist?(path)
    
    presets = JSON.parse(File.read(path))
    data = presets[name]
    
    if data && @dialog && @dialog.visible?
      @dialog.execute_script("updateUIFromData('#{data.to_json}')")
      # Trigger a build to show the loaded preset
      self.build_cabinet(data)
    end
  end

  def self.revert_transparent_cabinets(current_selection)
    @transparent_cabinets.keep_if do |entity|
      if !entity.valid? || entity.deleted?
        false
      elsif current_selection.include?(entity)
        true
      else
        orig_mat_name = entity.get_attribute("SmartCabinet", "OriginalMaterial", "NONE")
        if orig_mat_name == "NONE"
          entity.material = nil
        else
          entity.material = Sketchup.active_model.materials[orig_mat_name]
        end
        false
      end
    end
  end

  class CabinetSelectionObserver < Sketchup::SelectionObserver
    def handle_selection(selection)
      return if SmartCabinetMaker.instance_variable_get(:@is_building)
      
      # Use a timer to defer model changes, avoiding crashes in observers
      UI.start_timer(0, false) do
        SmartCabinetMaker.revert_transparent_cabinets(selection)
        
        selection.each do |entity|
          next unless entity.valid? && !entity.deleted?
          if entity.is_a?(Sketchup::Group) && (entity.get_attribute("SmartCabinet", "IsSmartCabinet"))
            unless SmartCabinetMaker.transparent_cabinets.include?(entity)
              orig_mat = entity.material
              entity.set_attribute("SmartCabinet", "OriginalMaterial", orig_mat ? orig_mat.name : "NONE")
              
              entity.material = SmartCabinetMaker.get_transparent_material
              SmartCabinetMaker.transparent_cabinets << entity
            end
            
            # Sync UI if dialog is open
            dialog = SmartCabinetMaker.instance_variable_get(:@dialog)
            if selection.length == 1 && dialog && dialog.visible?
              params = entity.get_attribute("SmartCabinet", "Parameters")
              dialog.execute_script("updateUIFromData('#{params}')") if params
            end
          end
        end
      end
    end

    def onSelectionBulkChange(selection)
      handle_selection(selection)
    end
    
    def onSelectionAdded(selection, entity)
      handle_selection(selection)
    end
    
    def onSelectionRemoved(selection, entity)
      handle_selection(selection)
    end

    def onSelectionCleared(selection)
      handle_selection(selection)
    end
  end

  def self.attach_observer
    @observer ||= CabinetSelectionObserver.new
    Sketchup.active_model.selection.remove_observer(@observer)
    Sketchup.active_model.selection.add_observer(@observer)
    puts "Smart Cabinet Observer Attached!"
  end

  class CabinetAppObserver < Sketchup::AppObserver
    def onNewModel(model)
      SmartCabinetMaker.attach_observer
    end
    def onOpenModel(model)
      SmartCabinetMaker.attach_observer
    end
  end

  # Βάζουμε την ενεργοποίηση ΕΚΤΟΣ του μπλοκ, ώστε να ενεργοποιείται 
  # σίγουρα κάθε φορά που τρέχουμε την εντολή load.
  # Ενεργοποιούμε ξανά τον Observer με τη νέα ασφαλή μέθοδο
  SmartCabinetMaker.attach_observer

  unless file_loaded?(__FILE__)
    Sketchup.add_observer(CabinetAppObserver.new)
    
    menu = UI.menu("Plugins")
    if menu
      submenu = menu.add_submenu("Smart Cabinet Maker Pro")
      
      cmd = UI::Command.new("Open Configurator") {
        self.show_dialog
      }
      cmd.set_validation_proc { MF_ENABLED }
      
      # Use the generated logo path for icons
      icon_path = "C:/Users/Admin/.gemini/antigravity/brain/cc04fce2-db21-47d8-a5a5-2ab784a2a06a/smart_cabinet_maker_logo_1777907382602.png"
      cmd.small_icon = icon_path
      cmd.large_icon = icon_path
      cmd.tooltip = "Smart Cabinet Maker Pro"
      cmd.status_bar_text = "Open the Parametric Cabinet Configurator"
      cmd.menu_text = "Open Configurator"
      
      submenu.add_item(cmd)
      
      # Toolbar
      tb = UI::Toolbar.new "Smart Cabinet Maker"
      tb.add_item cmd
      tb.show
    end
    file_loaded(__FILE__)
    # Auto-open the dialog when loaded for immediate use
    self.show_dialog
  end
end
