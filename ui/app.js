function openTab(evt, tabName) {
  var i, tabcontent, tablinks;
  tabcontent = document.getElementsByClassName("tabcontent");
  for (i = 0; i < tabcontent.length; i++) {
    tabcontent[i].style.display = "none";
  }
  tablinks = document.getElementsByClassName("tablink");
  for (i = 0; i < tablinks.length; i++) {
    tablinks[i].className = tablinks[i].className.replace(" active", "");
  }
  document.getElementById(tabName).style.display = "block";
  evt.currentTarget.className += " active";
}

function getCabinetData() {
  const data = {
    global: {
      materialThickness: document.getElementById('mat_th').value,
      backThickness: document.getElementById('back_th').value,
      gap: document.getElementById('gap').value,
      plinthHeight: document.getElementById('plinth').value
    },
    box: {
      width: document.getElementById('width').value,
      height: document.getElementById('height').value,
      depth: document.getElementById('depth').value,
      backType: document.getElementById('back_type').value,
      topType: document.getElementById('top_type').value,
      railWidth: document.getElementById('rail_width').value,
      plinthInsetF: document.getElementById('plinth_inset_f').value,
      plinthInsetB: document.getElementById('plinth_inset_b').value,
      connType: document.getElementById('conn_type').value,
      backInset: document.getElementById('back_inset').value,
      grooveDepth: document.getElementById('groove_depth').value
    },
    joinery: {
      connectorType: document.getElementById('connector_type').value,
      connectorMode: document.getElementById('connector_mode').value,
      connectorVal: document.getElementById('connector_val').value,
      connectorOffset: document.getElementById('connector_offset').value
    },
    interior: {
      verticalDividers: document.getElementById('v_dividers').value,
      shelves: document.getElementById('shelves').value
    },
    front: {
      type: document.getElementById('front_type').value,
      count: document.getElementById('front_count').value,
      handles: document.getElementById('handles').value
    },
    materials: {
      carcassName: document.getElementById('mat_carcass_name').value,
      carcassCode: document.getElementById('mat_carcass_code').value,
      frontName: document.getElementById('mat_front_name').value
    },
    ui: {
      ghostMode: document.getElementById('ghost_mode') ? document.getElementById('ghost_mode').checked : false
    }
  };
  return data;
}

function updateConnectorPreview() {
    const type = document.getElementById('connector_type').value;
    const mode = document.getElementById('connector_mode').value;
    const val = parseFloat(document.getElementById('connector_val').value) || 0;
    const offset = parseFloat(document.getElementById('connector_offset').value) || 0;
    const depth = parseFloat(document.getElementById('depth').value) || 500;
    const preview = document.getElementById('panel_preview');

    preview.innerHTML = '';
    
    if (type === 'None') return;

    let positions = [];
    if (mode === 'Manual') {
        const count = Math.floor(val);
        if (count === 1) {
            positions.push(50);
        } else if (count === 2) {
            positions.push((offset / depth) * 100);
            positions.push(((depth - offset) / depth) * 100);
        } else if (count > 2) {
            positions.push((offset / depth) * 100);
            positions.push(((depth - offset) / depth) * 100);
            const remaining = count - 2;
            const step = (depth - 2 * offset) / (remaining + 1);
            for (let i = 1; i <= remaining; i++) {
                positions.push(((offset + i * step) / depth) * 100);
            }
        }
    } else {
        // Auto mode visualization
        let current = offset;
        while (current <= (depth - offset)) {
            positions.push((current / depth) * 100);
            current += val;
        }
        if (positions[positions.length - 1] < ((depth - offset) / depth * 100)) {
             positions.push(((depth - offset) / depth) * 100);
        }
    }

    positions.forEach(pos => {
        const dot = document.createElement('div');
        dot.className = 'connector-dot';
        dot.style.left = pos + '%';
        if (type === 'Screw') dot.style.background = '#3498db';
        if (type === 'Minifix') dot.style.background = '#9b59b6';
        preview.appendChild(dot);
    });
}

function buildCabinet() {
  const data = getCabinetData();
  
  if (typeof sketchup !== 'undefined') {
    sketchup.buildCabinet(JSON.stringify(data));
  } else {
    console.log("JSON Payload:", data);
  }
}

// Live Update Logic with Debounce
let debounceTimer;
function triggerLiveUpdate() {
  clearTimeout(debounceTimer);
  debounceTimer = setTimeout(() => {
    buildCabinet();
  }, 1200); // 1200ms pause before updating
}

// Function called from Ruby to sync UI with selected cabinet
function updateUIFromData(jsonString) {
  const data = JSON.parse(jsonString);
  
  // Globals
  document.getElementById('mat_th').value = data.global.materialThickness;
  document.getElementById('back_th').value = data.global.backThickness;
  document.getElementById('gap').value = data.global.gap;
  document.getElementById('plinth').value = data.global.plinthHeight;
  
  // Box
  document.getElementById('width').value = data.box.width;
  document.getElementById('height').value = data.box.height;
  document.getElementById('depth').value = data.box.depth;
  document.getElementById('back_type').value = data.box.backType;
  document.getElementById('top_type').value = data.box.topType;
  document.getElementById('rail_width').value = data.box.railWidth;
  document.getElementById('plinth_inset_f').value = data.box.plinthInsetF;
  document.getElementById('plinth_inset_b').value = data.box.plinthInsetB;
  
  // Interior
  document.getElementById('v_dividers').value = data.interior.verticalDividers;
  document.getElementById('shelves').value = data.interior.shelves;
  
  // Front
  document.getElementById('front_type').value = data.front.type;
  document.getElementById('front_count').value = data.front.count;
  document.getElementById('handles').value = data.front.handles;

  // Joinery
  if(data.box.connType) document.getElementById('conn_type').value = data.box.connType;
  if(data.box.backInset) document.getElementById('back_inset').value = data.box.backInset;
  if(data.box.grooveDepth) document.getElementById('groove_depth').value = data.box.grooveDepth;
  
  // Connectors
  if(data.joinery) {
      document.getElementById('connector_type').value = data.joinery.connectorType;
      document.getElementById('connector_mode').value = data.joinery.connectorMode;
      document.getElementById('connector_val').value = data.joinery.connectorVal;
      document.getElementById('connector_offset').value = data.joinery.connectorOffset;
  }

  // Materials
  if(data.materials) {
    document.getElementById('mat_carcass_name').value = data.materials.carcassName;
    document.getElementById('mat_carcass_code').value = data.materials.carcassCode;
    document.getElementById('mat_front_name').value = data.materials.frontName;
  }
  
  // UI
  if(data.ui && document.getElementById('ghost_mode')) {
    document.getElementById('ghost_mode').checked = data.ui.ghostMode;
  }

  updateConnectorPreview();
}

function toggleGhostMode() {
  // Functionality removed as per user request
}

// Preset Logic
function savePreset(button) {
  const container = button.parentElement;
  const nameInput = container.querySelector('.preset-name-input');
  const name = nameInput.value.trim();
  
  if (!name) {
    alert("Please enter a name for the preset.");
    return;
  }
  
  const data = getCabinetData();
  sketchup.savePreset(name, JSON.stringify(data));
  nameInput.value = ""; // Clear after save
}

function loadPreset() {
  const selector = document.getElementById('preset_selector');
  const name = selector.value;
  if (!name) return;
  
  sketchup.loadPreset(name);
}

function updatePresetList(jsonString) {
  const presets = JSON.parse(jsonString);
  const selector = document.getElementById('preset_selector');
  
  // Save current selection
  const currentVal = selector.value;
  
  // Clear and rebuild
  selector.innerHTML = '<option value="">-- Select --</option>';
  presets.forEach(name => {
    const opt = document.createElement('option');
    opt.value = name;
    opt.textContent = name;
    selector.appendChild(opt);
  });
  
  // Restore selection if it still exists
  selector.value = currentVal;
}

// Fetch initial presets when loaded
window.onload = () => {
  updateConnectorPreview();
  
  // Attach listeners to all joinery fields for live preview
  const joineryFields = ['connector_type', 'connector_mode', 'connector_val', 'connector_offset', 'depth'];
  joineryFields.forEach(id => {
      const el = document.getElementById(id);
      if (el) {
          el.addEventListener('input', updateConnectorPreview);
          el.addEventListener('change', updateConnectorPreview);
      }
  });

  if (typeof sketchup !== 'undefined') {
    sketchup.fetchPresets();
  }
};
