// Strictly ES5 for IE11/SU2017 Compatibility
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
    if (evt) {
        evt.currentTarget.className += " active";
    }
}

function updateDefaults() {
    var type = document.getElementById('cab_type').value;
    if (type === "Base") {
        document.getElementById('height').value = 760;
        document.getElementById('depth').value = 560;
    } else if (type === "Wall") {
        document.getElementById('height').value = 720;
        document.getElementById('depth').value = 330;
    } else if (type === "Wardrobe") {
        document.getElementById('height').value = 1600;
        document.getElementById('depth').value = 580;
    }
}
function toggleGolaSettings() {
    var handleType = document.getElementById('handle_type').value;
    var golaSection = document.getElementById('gola_section');
    if (handleType === 'Gola') {
        golaSection.style.display = 'block';
    } else {
        golaSection.style.display = 'none';
    }
}

function browseFile(id) {
    window.location.href = 'skp:browseFile@' + id;
}

function setFilePath(id, path) {
    document.getElementById(id).value = path;
}

function collectData() {
    var data = {
        global: {
            materialThickness: parseFloat(document.getElementById('mat_th').value) || 18,
            backThickness: parseFloat(document.getElementById('back_th').value) || 8,
            plinthHeight: parseFloat(document.getElementById('plinth').value) || 100,
            gap: parseFloat(document.getElementById('gap').value) || 3,
            pvcThickness: parseFloat(document.getElementById('pvc_th').value) || 1
        },
        box: {
            cab_type: document.getElementById('cab_type').value,
            width: parseFloat(document.getElementById('width').value) || 600,
            height: parseFloat(document.getElementById('height').value) || 800,
            depth: parseFloat(document.getElementById('depth').value) || 500,
            backType: document.getElementById('back_type').value,
            topType: document.getElementById('top_type').value,
            railWidth: parseFloat(document.getElementById('rail_width').value) || 100,
            connType: document.getElementById('conn_type').value,
            backInset: parseFloat(document.getElementById('back_inset').value) || 15,
            grooveDepth: parseFloat(document.getElementById('groove_depth').value) || 8,
            plinthInsetF: parseFloat(document.getElementById('plinth_inset_f').value) || 50,
            plinthInsetB: parseFloat(document.getElementById('plinth_inset_b').value) || 0,
            connector_type: document.getElementById('connector_type').value
        },
        front: {
            front_type: document.getElementById('front_type').value,
            overlay_type: document.getElementById('overlay_type').value,
            count: parseInt(document.getElementById('front_count').value) || 1,
            hingeType: document.getElementById('hinge_type').value,
            hingeOffset: parseFloat(document.getElementById('hinge_offset').value) || 100,
            handle_type: document.getElementById('handle_type').value,
            handle_cc: parseFloat(document.getElementById('handle_cc').value) || 128,
            handle_offset_x: parseFloat(document.getElementById('handle_offset_x').value) || 40,
            handle_offset_z: parseFloat(document.getElementById('handle_offset_z').value) || 40,
            gola_type: document.getElementById('gola_type').value,
            gola_size: parseFloat(document.getElementById('gola_size').value) || 55,
            gola_depth: parseFloat(document.getElementById('gola_depth').value) || 30,
            gola_radius: parseFloat(document.getElementById('gola_radius').value) || 0
        },
        interior: {
            shelves: parseInt(document.getElementById('shelves').value) || 0,
            shelf_inset: parseFloat(document.getElementById('shelf_inset').value) || 20,
            line_boring: document.getElementById('line_boring').checked,
            lb_offset_f: parseFloat(document.getElementById('lb_offset_f').value) || 37,
            lb_offset_b: parseFloat(document.getElementById('lb_offset_b').value) || 37,
            zone_split: document.getElementById('zone_split').value
        },
        materials: {
            mat_carcass_name: document.getElementById('mat_carcass_name').value,
            mat_carcass_pvc: document.getElementById('mat_carcass_pvc').value,
            mat_carcass_tex: document.getElementById('mat_carcass_tex').value,
            mat_front1_name: document.getElementById('mat_front1_name').value,
            mat_front1_pvc: document.getElementById('mat_front1_pvc').value,
            mat_front1_tex: document.getElementById('mat_front1_tex').value,
            mat_front2_name: document.getElementById('mat_front2_name').value,
            mat_front2_tex: document.getElementById('mat_front2_tex').value,
            mat_back_name: document.getElementById('mat_back_name').value,
            mat_plinth_name: document.getElementById('mat_plinth_name').value
        }
    };
    return data;
}

function buildCabinet() {
    var data = collectData();
    window.location.href = 'skp:buildCabinet@' + JSON.stringify(data);
}

function savePreset(btn) {
    var input = btn.previousElementSibling;
    var name = input.value || "New Preset";
    var data = collectData();
    window.location.href = 'skp:savePreset@' + name + '@' + JSON.stringify(data);
}

function loadPreset() {
    var select = document.getElementById('preset_selector');
    if (select.value) {
        window.location.href = 'skp:loadPreset@' + select.value;
    }
}

function updatePresetList(listJson) {
    var list = JSON.parse(listJson);
    var select = document.getElementById('preset_selector');
    select.innerHTML = '<option value="">-- Επιλογή --</option>';
    for (var i = 0; i < list.length; i++) {
        var opt = document.createElement('option');
        opt.value = list[i];
        opt.innerHTML = list[i];
        select.appendChild(opt);
    }
}

function updateUIFromData(json) {
    var data = JSON.parse(json);
    try {
        // Global
        document.getElementById('mat_th').value = data.global.materialThickness;
        document.getElementById('back_th').value = data.global.backThickness;
        document.getElementById('plinth').value = data.global.plinthHeight;
        document.getElementById('gap').value = data.global.gap;
        document.getElementById('pvc_th').value = data.global.pvcThickness || 1;
        // Box
        document.getElementById('cab_type').value = data.box.cab_type || "Base";
        document.getElementById('width').value = data.box.width;
        document.getElementById('height').value = data.box.height;
        document.getElementById('depth').value = data.box.depth;
        document.getElementById('back_type').value = data.box.backType;
        document.getElementById('top_type').value = data.box.topType;
        document.getElementById('rail_width').value = data.box.railWidth;
        document.getElementById('conn_type').value = data.box.connType;
        document.getElementById('connector_type').value = data.box.connector_type || "Screw_3.5";
        // Front
        document.getElementById('front_type').value = data.front.front_type || "Doors";
        document.getElementById('overlay_type').value = data.front.overlay_type || "Full";
        document.getElementById('front_count').value = data.front.count;
        document.getElementById('hinge_type').value = data.front.hingeType;
        document.getElementById('handle_type').value = data.front.handle_type || "None";
        toggleGolaSettings(); // Update visibility
        if (data.front.handle_type === 'Gola') {
            document.getElementById('gola_size').value = data.front.gola_size || 55;
            document.getElementById('gola_depth').value = data.front.gola_depth || 30;
            document.getElementById('gola_radius').value = data.front.gola_radius || 0;
        }
        // Interior
        document.getElementById('shelves').value = data.interior.shelves;
        document.getElementById('line_boring').checked = data.interior.line_boring || false;
        // Materials
        document.getElementById('mat_carcass_name').value = data.materials.mat_carcass_name;
        document.getElementById('mat_front1_name').value = data.materials.mat_front1_name;
    } catch(e) { console.log("UI Update Error: ", e); }
}

function updateConnectorPreview() {
    // Placeholder to prevent errors if called
}

window.onload = function() {
    openTab(null, 'globals');
    window.location.href = 'skp:fetchPresets';
};
