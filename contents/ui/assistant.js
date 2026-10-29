.pragma library

// Random theme generator behind the theme assistant. The asked-for basics are fixed (or picked from a
// short list when set to "random"), everything else is rolled; "variation" says how far the numbers
// may wander from the typical values. The result only contains settings the assistant cares about,
// the rest is inherited from the collection the theme goes into.

var backgrounds = ["black", "white", "dark", "light", "custom", "random"];
var palettes = ["random", "analogous", "complementary", "triadic", "monochrome", "warm", "cool", "pastel", "neon", "accent"];
var levels = {
    curved: { none: 0, few: 15, normal: 40, many: 70 },
    speed: { slow: [0.05, 0.8], normal: [0.1, 1.5], fast: [0.3, 3.0] },
    sand: { none: null, subtle: [0.05, 48], normal: [0.1, 64], strong: [0.2, 96] },
    sparks: { none: 0, few: 1, normal: 3, lots: 6 },
    explosions: { off: 0, rare: 5, often: 20 }
};

function pick(rng, list) {
    return list[Math.floor(rng() * list.length) % list.length];
}

// A named level, or a random one when the choice is "random"
function level(rng, name, choice) {
    return choice === "random" ? pick(rng, Object.keys(levels[name])) : choice;
}

// Numbers wander by up to +-50 % at full variation
function jitter(rng, value, variation) {
    return value * (1 + (rng() * 2 - 1) * 0.5 * variation / 100);
}

function round(value, digits) {
    var f = Math.pow(10, digits);
    return Math.round(value * f) / f;
}

function hslToRgb(h, s, l) {
    h = ((h % 360) + 360) % 360 / 360;
    var q = l < 0.5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q;
    function channel(t) {
        t = (t + 1) % 1;
        if (t < 1 / 6) return p + (q - p) * 6 * t;
        if (t < 1 / 2) return q;
        if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
        return p;
    }
    return [Math.round(channel(h + 1 / 3) * 255), Math.round(channel(h) * 255), Math.round(channel(h - 1 / 3) * 255)];
}

function luminance(rgb) {
    return (0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]) / 255;
}

function backgroundColor(rng, choice, custom) {
    if (choice === "random") choice = pick(rng, ["black", "white", "dark", "light"]);
    switch (choice) {
    case "white": return [255, 255, 255];
    case "dark": return hslToRgb(rng() * 360, 0.25 + rng() * 0.25, 0.05 + rng() * 0.09);
    case "light": return hslToRgb(rng() * 360, 0.2 + rng() * 0.3, 0.9 + rng() * 0.06);
    case "custom": return custom && custom.length === 3 ? custom : [0, 0, 0];
    default: return [0, 0, 0];
    }
}

// accentHue: hue (degrees) of the Plasma accent color, used by the "accent" palette
function colors(rng, kind, count, darkGround, accentHue) {
    var base = kind === "accent" && accentHue !== undefined ? accentHue : rng() * 360;
    var list = [];
    // Readable on the ground: light colors on dark, darker on light
    var lightLow = darkGround ? 0.5 : 0.28, lightHigh = darkGround ? 0.75 : 0.5;
    for (var i = 0; i < count; i++) {
        var hue, sat = 0.65 + rng() * 0.35, light = lightLow + rng() * (lightHigh - lightLow);
        switch (kind) {
        case "analogous":
        case "accent":
            hue = base + (i - (count - 1) / 2) * (18 + rng() * 10);
            break;
        case "complementary":
            hue = base + (i % 2 ? 180 : 0) + (rng() - 0.5) * 30;
            break;
        case "triadic":
            hue = base + (i % 3) * 120 + (rng() - 0.5) * 24;
            break;
        case "monochrome":
            hue = base + (rng() - 0.5) * 8;
            light = lightLow + (i + 0.5) / count * (lightHigh - lightLow);
            break;
        case "warm":
            hue = -30 + rng() * 90;
            break;
        case "cool":
            hue = 170 + rng() * 100;
            break;
        case "pastel":
            hue = rng() * 360;
            sat = 0.45 + rng() * 0.25;
            light = darkGround ? 0.72 + rng() * 0.12 : 0.55 + rng() * 0.1;
            break;
        case "neon":
            hue = rng() * 360;
            sat = 1;
            light = darkGround ? 0.5 + rng() * 0.12 : 0.4 + rng() * 0.08;
            break;
        default: // random
            hue = rng() * 360;
        }
        list.push(hslToRgb(hue, Math.min(1, sat), light));
    }
    return list;
}

// options: { background, customBackground, palette, colorCount, rainbow, curved, speed, sand, sparks,
//            explosions, explosionSand, variation, accentHue }
function generate(options, rng) {
    rng = rng || Math.random;
    var variation = options.variation === undefined ? 40 : options.variation;
    var bg = backgroundColor(rng, options.background, options.customBackground);
    var dark = luminance(bg) < 0.5;
    var palette = options.palette === "random" && rng() < 0.5 ? pick(rng, palettes.slice(1, 9)) : options.palette;
    var count = Math.max(1, Math.min(16, options.colorCount || 6));
    var config = { BG_COLOR: bg, COLORS: colors(rng, palette, count, dark, options.accentHue) };

    if (options.rainbow) {
        config.RAINBOW = true;
        config.RAINBOW_SPEED = round(Math.max(0.05, jitter(rng, 0.6, variation)), 2);
        config.RAINBOW_LIGHTNESS = dark ? 0.58 : 0.42;
    }

    config.CIRCLE_PERCENT = Math.round(Math.max(0, Math.min(100, levels.curved[level(rng, "curved", options.curved)]
                                      + (rng() * 2 - 1) * variation * 0.3)));

    var speed = levels.speed[level(rng, "speed", options.speed)];
    config.STEP_MIN = round(Math.max(0.02, jitter(rng, speed[0], variation)), 2);
    config.STEP_MAX = round(Math.max(config.STEP_MIN + 0.1, jitter(rng, speed[1], variation)), 2);

    var sand = levels.sand[level(rng, "sand", options.sand)];
    if (sand === null) {
        config.SAND_MODE = "none";
    } else {
        config.SAND_MODE = "both";
        config.SAND_ALPHA = round(Math.min(0.5, Math.max(0.02, jitter(rng, sand[0], variation))), 2);
        config.GRAINS = Math.round(Math.max(8, jitter(rng, sand[1], variation)));
    }

    var spawn = levels.sparks[level(rng, "sparks", options.sparks)];
    config.SPARKLER_ENABLED = spawn > 0;
    if (spawn > 0) config.SPARK_SPAWN_RATE = Math.max(1, Math.round(jitter(rng, spawn, variation)));

    var blast = levels.explosions[level(rng, "explosions", options.explosions)];
    config.EXPLOSIONS = blast > 0;
    if (blast > 0) {
        config.EXPLOSION_CHANCE = round(Math.min(60, Math.max(1, jitter(rng, blast, variation))), 1);
        config.EXPLOSION_RADIUS = round(Math.max(1.5, jitter(rng, 4, variation)), 1);
        config.EXPLOSION_SAND = options.explosionSand === true;
    }
    return config;
}
