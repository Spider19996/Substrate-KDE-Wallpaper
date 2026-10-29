.pragma library

// Every theme setting of the HTML original, in the order shown in the theme manager.
// Keys are the CONFIG names of the original so theme files stay compatible.
var sections = [
    { title: "Lines", params: [
        { key: "STEP_MIN", label: "Minimum speed (px/step)", type: "real", min: 0.01, max: 10, step: 0.05, def: 0.1 },
        { key: "STEP_MAX", label: "Maximum speed (px/step)", type: "real", min: 0.01, max: 10, step: 0.05, def: 1.5 },
        { key: "CRACKS_PER_100K_PIXELS", label: "Start cracks per 100k pixels", type: "real", min: 0, max: 20, step: 0.1, def: 1 },
        { key: "MIN_INITIAL_CRACKS", label: "Minimum start cracks", type: "int", min: 1, max: 500, def: 2 },
        { key: "MAX_INITIAL_CRACKS", label: "Maximum start cracks", type: "int", min: 1, max: 500, def: 20 },
        { key: "MAX_CRACKS", label: "Maximum simultaneous cracks", type: "int", min: 1, max: 2000, def: 100 },
        { key: "CIRCLE_PERCENT", label: "Curved cracks (%)", type: "real", min: 0, max: 100, step: 1, def: 40 },
        { key: "BRANCH_MODE", label: "Branching", type: "enum", def: "perpendicular",
          options: [ { value: "perpendicular", text: "Perpendicular (90°)" },
                     { value: "opposite", text: "Opposite (180°)" },
                     { value: "random", text: "Random angle" } ] },
        { key: "LINE_WIDTH", label: "Line width (px)", type: "real", min: 0.1, max: 10, step: 0.1, def: 1 },
        { key: "ANTI_ALIASING", label: "Anti-aliasing", type: "bool", def: true }
    ] },
    { title: "Sand", params: [
        { key: "SAND_MODE", label: "Sand", type: "enum", def: "both",
          options: [ { value: "both", text: "Both sides" },
                     { value: "one", text: "One side" },
                     { value: "none", text: "Off" } ] },
        { key: "GRAINS", label: "Grains per region", type: "int", min: 0, max: 512, def: 64 },
        { key: "SAND_ALPHA", label: "Sand opacity", type: "real", min: 0, max: 1, step: 0.01, def: 0.1 }
    ] },
    { title: "Drift", params: [
        { key: "LINE_DRIFT_ENABLED", label: "Straight lines drift", type: "bool", def: false },
        { key: "LINE_DRIFT_AMOUNT", label: "Drift per event (°)", type: "real", min: 0, max: 45, step: 0.5, def: 2 },
        { key: "LINE_DRIFT_FREQUENCY", label: "Drift probability per step", type: "real", min: 0, max: 1, step: 0.05, def: 0.3 }
    ] },
    { title: "Sparks", params: [
        { key: "SPARKLER_ENABLED", label: "Sparks", type: "bool", def: true },
        { key: "SPARK_SPAWN_RATE", label: "Sparks per crack and step", type: "int", min: 0, max: 20, def: 3 },
        { key: "SPARK_SPEED_MIN", label: "Minimum spark speed", type: "real", min: 0, max: 20, step: 0.1, def: 0.5 },
        { key: "SPARK_SPEED_MAX", label: "Maximum spark speed", type: "real", min: 0, max: 20, step: 0.1, def: 2.5 },
        { key: "SPARK_LIFETIME", label: "Lifetime (steps)", type: "int", min: 1, max: 300, def: 15 },
        { key: "SPARK_SIZE", label: "Size (px)", type: "real", min: 0.1, max: 20, step: 0.1, def: 1.3 },
        { key: "SPARK_GLOW", label: "Glow radius (px, 0 = off)", type: "real", min: 0, max: 50, step: 0.5, def: 2 }
    ] },
    { title: "Explosions", params: [
        { key: "EXPLOSIONS", label: "Lines can explode on impact", type: "bool", def: false },
        { key: "EXPLOSION_CHANCE", label: "Chance per impact (%)", type: "real", min: 0, max: 100, step: 1, def: 10 },
        { key: "EXPLOSION_RADIUS", label: "Blast radius (% of the shorter screen side)", type: "real", min: 0.5, max: 50, step: 0.5, def: 4 },
        { key: "EXPLOSION_SPARKS", label: "Sparks per explosion", type: "int", min: 0, max: 500, def: 60 },
        { key: "EXPLOSION_SAND", label: "Sand burst at the impact", type: "bool", def: false },
        { key: "EXPLOSION_SAND_GRAINS", label: "Grains of the sand burst", type: "int", min: 0, max: 20000, def: 3000 }
    ] },
    { title: "Rainbow", params: [
        { key: "RAINBOW", label: "Rainbow lines", type: "bool", def: false },
        { key: "RAINBOW_SPEED", label: "Color change (° of hue per step)", type: "real", min: 0.01, max: 20, step: 0.05, def: 0.6 },
        { key: "RAINBOW_SATURATION", label: "Saturation", type: "real", min: 0, max: 1, step: 0.05, def: 1 },
        { key: "RAINBOW_LIGHTNESS", label: "Lightness (lower on bright backgrounds)", type: "real", min: 0.05, max: 0.95, step: 0.05, def: 0.55 }
    ] },
    { title: "Reset", params: [
        { key: "COVERAGE_RESET_PERCENT", label: "Reset at coverage (%)", type: "real", min: 1, max: 100, step: 1, def: 10 },
        { key: "FADE_OUT_SECONDS", label: "Fade out (s, 0 = instant)", type: "real", min: 0, max: 60, step: 0.5, def: 3 },
        { key: "HARD_RESET_EVERY", label: "Hard reset every n resets (0 = never)", type: "int", min: 0, max: 100, def: 3 },
        { key: "HARD_FADE_SECONDS", label: "Hard fade out (s)", type: "real", min: 0.1, max: 60, step: 0.5, def: 2 },
        { key: "HARD_FADE_IN_SECONDS", label: "Fade in after hard reset (s)", type: "real", min: 0, max: 60, step: 0.5, def: 2 }
    ] }
];

// Tab titles: colors first, then one tab per section
function tabs() {
    var t = ["Colors"];
    for (var s = 0; s < sections.length; s++) t.push(sections[s].title);
    return t;
}

// Sections and parameters as one list, for a single form
function flat() {
    var list = [];
    for (var s = 0; s < sections.length; s++) {
        list.push({ type: "section", label: sections[s].title });
        for (var p = 0; p < sections[s].params.length; p++) list.push(sections[s].params[p]);
    }
    return list;
}

function defaults() {
    var c = { BG_COLOR: [0, 0, 0], COLORS: [[255, 50, 50], [50, 255, 50], [50, 50, 255], [255, 255, 0], [255, 0, 255], [0, 255, 255]] };
    for (var s = 0; s < sections.length; s++)
        for (var p = 0; p < sections[s].params.length; p++)
            c[sections[s].params[p].key] = sections[s].params[p].def;
    return c;
}

// Fills in settings a theme file does not define
function complete(config) {
    var c = defaults();
    for (var k in config) c[k] = config[k];
    return c;
}

function toColor(rgb) {
    return Qt.rgba(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255, 1);
}

function fromColor(c) {
    return [Math.round(c.r * 255), Math.round(c.g * 255), Math.round(c.b * 255)];
}
