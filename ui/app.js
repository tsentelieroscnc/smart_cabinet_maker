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

function collectData() {
    // Map HTML IDs to what main.rb expects
    var data = {
        global: {
            materialThickness: parseFloat(document.getElementById('mat_th').value) || 18,
            backThickness: parseFloat(document.getElementById('back_th').value) || 8,
            plinthHeight: parseFloat(document.getElementById('plinth').value) || 100,
            gap: parseFloat(document.getElementById('gap').value) || 3
        },
        box: {
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
            plinthInsetB: parseFloat(document.getElementById('plinth_inset_b').value) || 0
        },
        front: {
            type: document.getElementById('front_type').value,
            count: parseInt(document.getElementById('front_count').value) || 1,
            hingeType: document.getElementById('hinge_type').value,
            hingeOffset: parseFloat(document.getElementById('hinge_offset').value) || 100,
            handles: "None" // Fixed placeholder
        },
        interior: {
            shelves: parseInt(document.getElementById('shelves').value) || 0
        },
        joinery: {
            connectorType: document.getElementById('connector_type').value,
            connectorMode: document.getElementById('connector_mode').value,
            connectorVal: parseFloat(document.getElementById('connector_val').value) || 3,
            connectorOffset: parseFloat(document.getElementById('connector_offset').value) || 37
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
    // Global
    document.getElementById('mat_th').value = data.global.materialThickness;
    document.getElementById('back_th').value = data.global.backThickness;
    document.getElementById('plinth').value = data.global.plinthHeight;
    document.getElementById('gap').value = data.global.gap;
    // Box
    document.getElementById('width').value = data.box.width;
    document.getElementById('height').value = data.box.height;
    document.getElementById('depth').value = data.box.depth;
    document.getElementById('back_type').value = data.box.backType;
    document.getElementById('top_type').value = data.box.topType;
    document.getElementById('rail_width').value = data.box.railWidth;
    document.getElementById('conn_type').value = data.box.connType;
    document.getElementById('back_inset').value = data.box.backInset;
    document.getElementById('groove_depth').value = data.box.grooveDepth;
    document.getElementById('plinth_inset_f').value = data.box.plinthInsetF;
    document.getElementById('plinth_inset_b').value = data.box.plinthInsetB;
    // Front
    document.getElementById('front_type').value = data.front.type;
    document.getElementById('front_count').value = data.front.count;
    document.getElementById('hinge_type').value = data.front.hingeType;
    document.getElementById('hinge_offset').value = data.front.hingeOffset;
    // Interior
    document.getElementById('shelves').value = data.interior.shelves;
}

function updateConnectorPreview() {
    // Placeholder to prevent errors if called
}

window.onload = function() {
    openTab(null, 'globals');
    window.location.href = 'skp:fetchPresets';
};
