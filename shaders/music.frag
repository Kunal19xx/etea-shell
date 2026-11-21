#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 l0; // what cava hears, 26 bands, four to a vector
    vec4 l1;
    vec4 l2;
    vec4 l3;
    vec4 l4;
    vec4 l5;
    vec4 l6;
    vec4 ink; // the music's colour
    vec4 light; // and the light its tops catch
    vec2 world; // the whole world's size, in pixels
    vec2 origin; // where this strip starts in it
    vec2 size; // and its size
    float horizon;
    float curve; // the planet's radius, in units of a 1600 wide world
    float relief;
    float orbit;
    float planetAngle;
    float seed;
    float farA; // the far ground's form, which the lines echo
    float rough;
    float hills; // 1 with hills: the music stands behind them; 0 on the screen's edge
    float style; // 0 lines, 1 bars, 2 stars
    float reach; // how high it climbs, in units
    float density; // how many columns across the screen
    float time; // seconds, for the stars to breathe and their sparks to rise
    // What the music struck, each on the clock above: stars born on the horizon (the band
    // they rose from, when, how hard, how long they live), sparks running along the
    // constellation (when, how hard) and the constellations let go to drift into the sky
    vec4 birth0;
    vec4 birth1;
    vec4 birth2;
    vec4 birth3;
    vec4 birth4;
    vec4 birth5;
    vec4 birth6;
    vec4 birth7;
    vec2 spark0;
    vec2 spark1;
    vec2 spark2;
    vec4 ghostAt0; // when each of the eight was let go
    vec4 ghostAt1;
    float ghostRise; // how high they drift, in units
};

// What each let-go constellation heard, a row of 26 bands each
layout(binding = 1) uniform sampler2D ghosts;

// The ridge and its forms, as terrain.frag draws them, for the lines to follow
float ridge(float s, float a) {
    float fine = rough, middle = mix(0.45, 1.0, rough);
    return 0.5 * sin(7.0 * a + 0.3 + s) + 0.3 * sin(17.0 * a + 1.1 + s)
        + 0.22 * middle * sin(41.0 * a + 2.2 + s) + 0.16 * middle * sin(97.0 * a + 0.7 + s)
        + 0.11 * fine * sin(211.0 * a + 1.9 + s) + 0.07 * fine * sin(431.0 * a + 3.1 + s)
        + 0.05 * fine * sin(863.0 * a + 0.4 + s);
}

float tables(float s, float a) {
    float swell = 0.45 * sin(13.0 * a + 0.3 + s) + 0.35 * sin(31.0 * a + 1.1 + s) + 0.2 * sin(67.0 * a + 2.2 + s);
    float x = swell * 2.2 + 2.2;
    return (floor(x) + smoothstep(0.84, 0.97, fract(x))) / 2.2 - 1.0 + 0.035 * rough * sin(431.0 * a + 3.1 + s);
}

float dunes(float s, float a) {
    float x = a * 17.0 + 0.6 * sin(9.0 * a + s) + s;
    float f = fract(x);
    float face = f < 0.8 ? f / 0.8 : (1.0 - f) / 0.2;
    return 0.35 * sin(4.0 * a + 0.7 + s) + (face - 0.5) * 1.1;
}

float form(float kind, float s, float a) {
    return kind < 0.5 ? ridge(s, a) : kind < 1.5 ? tables(s, a) : dunes(s, a);
}

float heightOf(float kind, float s, float a, float sampleStep) {
    float cell = a / sampleStep;
    return mix(form(kind, s, floor(cell) * sampleStep), form(kind, s, ceil(cell) * sampleStep), fract(cell));
}

float band(int i) {
    vec4 rows[7] = vec4[](l0, l1, l2, l3, l4, l5, l6);
    i = clamp(i, 0, 25);
    return rows[i / 4][i % 4];
}

// How loud a note is, low notes on the left
float sound(float t) {
    float at = clamp(t, 0.0, 1.0) * 25.0;
    int i = int(floor(at));
    float f = fract(at);
    f = f * f * (3.0 - 2.0 * f);
    return mix(band(i), band(i + 1), f);
}

// What a column across the screen hears, softened toward its neighbours and with the
// quiet highs lifted a little, 0 to 1
float heardAt(float x) {
    float t = 0.5 - 0.5 * cos(3.14159 * (x / 1600.0 * 1.3 + 0.17));
    float heard = (sound(t - 0.03) + sound(t) * 2.0 + sound(t + 0.03)) * 0.25;
    return 1.0 - exp(-heard * (0.55 + 0.75 * t) * 1.9);
}

// What a star hears: its own note across the whole range, low on the left, lightly
// smoothed so each star moves on its own, the quiet highs lifted
float noteAt(float x) {
    float t = 0.02 + 0.92 * clamp(x / 1600.0, 0.0, 1.0);
    float heard = (sound(t - 0.015) + sound(t) * 2.0 + sound(t + 0.015)) * 0.25 * mix(1.0, 1.7, t);
    return clamp(pow(heard, 0.85), 0.0, 1.0);
}

// ETEA's star as a distance: |x|^0.62 + |y|^0.62 = r^0.62
float starShape(vec2 p) {
    vec2 a = abs(p);
    return pow(pow(a.x, 0.62) + pow(a.y, 0.62), 1.0 / 0.62);
}

float hash(float n) {
    return fract(sin(n * 127.1) * 43758.5453);
}

// Over: a colour laid on what's below it
vec4 over(vec4 top, vec4 below) {
    return top + below * (1.0 - top.a);
}

// Distance from a point to a segment
float toSegment(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a;
    float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
    return length(p - a - ab * t);
}

// How loud a band of the constellation sounds, 0 to 1, the quiet highs lifted
float heardBand(float c) {
    int i = int(clamp(c, 0.0, 25.0));
    return 1.0 - exp(-band(i) * 1.9 * (0.6 + 0.7 * c / 25.0));
}

// ETEA's star, near enough with square roots, and cheap: (√|x| + √|y|)² = r
float starOf(vec2 q) {
    float s = sqrt(q.x) + sqrt(q.y);
    return s * s;
}

// The same, as a true distance near its outline, so a ring around it keeps one width
float starEdge(vec2 q, float r) {
    q = max(q, vec2(1e-3));
    float s = sqrt(q.x) + sqrt(q.y);
    float slope = s * sqrt(1.0 / q.x + 1.0 / q.y);
    return (s * s - r) / slope;
}

// A star of that size, flat, with its four rays thrown out as loud goes from 0.4 to 0.9,
// in two flat steps, kept within reach
vec4 starAt(vec2 q, float size, float loud, float reachOut, vec3 tone, vec3 shine, float px) {
    float body = clamp((size - starOf(q)) / (1.5 * px) + 0.5, 0.0, 1.0);
    vec4 star = vec4(tone, 1.0) * body * (0.5 + 0.5 * loud);
    float flare = smoothstep(0.4, 0.9, loud);
    float len = min(size * (1.2 + 2.4 * flare), reachOut);
    float w = 0.5 * px + 0.03 * size;
    vec2 thin = clamp((w - q.yx) / px + 0.5, 0.0, 1.0);
    vec2 inner = clamp((len * 0.5 - q) / px + 0.5, 0.0, 1.0);
    vec2 outer = clamp((len - q) / px + 0.5, 0.0, 1.0);
    vec2 rays = thin * (0.25 * outer + 0.3 * inner);
    return over(star, vec4(shine, 1.0) * min(rays.x + rays.y, 0.55) * flare);
}

// Where a spark runs, in units across the screen: it leaves the lows and crosses to the highs
// in under a second
float sparkFront(vec2 spark) {
    return -60.0 + (time - spark.x) * 1900.0;
}

// How lit a spot across the screen is by the sparks: full where one just passed, fading
// behind it, 0 ahead of it
float sparkLight(float x) {
    vec2 sparks[3] = vec2[](spark0, spark1, spark2);
    float lit = 0.0;
    for (int i = 0; i < 3; i++) {
        float behind = sparkFront(sparks[i]) - x;
        if (time < sparks[i].x || behind < -12.0 || behind > 420.0)
            continue;
        float come = clamp((behind + 12.0) / 12.0, 0.0, 1.0);
        float go = 1.0 - behind / 420.0;
        lit = max(lit, sparks[i].y * come * go * go);
    }
    return lit;
}

// The thread from star a to star b, drawn twice by hand like a porthole's frame: a wobbly
// line and a fainter one beside it, both lifting off the paper around the stars
float inkThread(vec2 at, vec2 a, vec2 b, float gapA, float gapB, float px) {
    vec2 ab = b - a;
    float len = length(ab);
    vec2 dir = ab / max(len, 1e-3);
    vec2 normal = vec2(-dir.y, dir.x);
    float along = dot(at - a, dir);
    float side = dot(at - a, normal) / px;
    float ends = clamp((along - gapA) / px + 0.5, 0.0, 1.0) * clamp((len - gapB - along) / px + 0.5, 0.0, 1.0);
    float phase = a.x * 0.37;
    float wobble = 0.45 * sin(along / px * 0.07 + phase) + 0.25 * sin(along / px * 0.19 + phase * 1.7);
    float first = clamp(0.65 - abs(side - wobble) + 0.5, 0.0, 1.0);
    float second = clamp(0.4 - abs(side - 1.8 - 0.8 * wobble) + 0.5, 0.0, 1.0) * 0.38;
    return max(first, second) * ends;
}

// The constellation that breathes with the music: one star per band of what's heard, riding
// on it and growing with it, whiter the louder, throwing out its rays on a loud note or as a
// spark runs by; a hand-drawn thread joins it to the next. Each pixel reads three bands at
// most, so it moves as smoothly as the bars.
vec4 constellationAt(vec2 at, float wide, float lift, float px) {
    float cell = clamp(floor(at.x / wide), 0.0, 25.0);
    vec2 stars[3];
    float louds[3];
    float sizes[3];
    for (int n = 0; n < 3; n++) {
        float c = clamp(cell + float(n - 1), 0.0, 25.0);
        float heard = heardBand(c);
        float x = (c + 0.5) * wide;
        float glow = max(heard, sparkLight(x));
        float seedC = hash(c + 17.0);
        float breath = 1.0 + 0.12 * sin(time * (1.4 + seedC) + seedC * 6.283);
        stars[n] = vec2(x, 10.0 + heard * lift);
        louds[n] = glow;
        sizes[n] = (3.2 + 11.0 * heard + 4.0 * (glow - heard)) * breath;
    }

    // The threads to either side, lit where a spark has just run
    float lit = sparkLight(at.x);
    float thread = 0.0;
    if (cell > 0.0)
        thread = inkThread(at, stars[0], stars[1], sizes[0] + 4.0 * px, sizes[1] + 4.0 * px, px);
    if (cell < 25.0)
        thread = max(thread, inkThread(at, stars[1], stars[2], sizes[1] + 4.0 * px, sizes[2] + 4.0 * px, px));
    vec3 threadTone = mix(ink.rgb, light.rgb, lit);
    vec4 color = vec4(threadTone, 1.0) * thread * min(1.0, 0.35 + 0.4 * louds[1] + 0.5 * lit);

    vec3 tone = mix(ink.rgb, light.rgb, smoothstep(0.2, 0.8, louds[1]));
    color = over(starAt(abs(at - stars[1]), sizes[1], louds[1], wide * 0.48, tone, light.rgb, px), color);

    // The sparks themselves, small and white, riding the threads
    vec2 sparks[3] = vec2[](spark0, spark1, spark2);
    for (int i = 0; i < 3; i++) {
        float front = sparkFront(sparks[i]);
        if (time < sparks[i].x || abs(front - at.x) > wide)
            continue;
        float f = clamp(front / wide - 0.5, 0.0, 25.0);
        float from = floor(f) - (cell - 1.0);
        if (from < 0.0 || from > 1.0)
            continue;
        vec2 head = from < 0.5 ? mix(stars[0], stars[1], fract(f)) : mix(stars[1], stars[2], fract(f));
        float size = 2.5 + 4.0 * sparks[i].y;
        color = over(starAt(abs(at - head), size, 0.6 + 0.4 * sparks[i].y, wide * 0.4, light.rgb, light.rgb, px), color);
    }
    return color;
}

// A star born on the horizon where a note was struck: it opens fast, a little too big, settles
// and closes again, while three flat rings of its shape spread out from it and fade. The lows
// are born big and slow, the highs small and quick.
vec4 birthsAt(vec2 at, float wide, float px) {
    vec4 births[8] = vec4[](birth0, birth1, birth2, birth3, birth4, birth5, birth6, birth7);
    vec4 color = vec4(0.0);
    for (int i = 0; i < 8; i++) {
        vec4 b = births[i];
        float age = time - b.y;
        if (age < 0.0 || age > b.w)
            continue;
        float along = b.x / 25.0;
        float size = mix(15.0, 6.0, along) * (0.6 + 0.4 * b.z);
        float spread = mix(5.5, 3.5, along);
        vec2 q = abs(at - vec2((b.x + 0.5) * wide, 6.0));
        if (q.x > size * (1.4 + spread) + 4.0 || q.y > size * (1.4 + spread) + 4.0)
            continue;
        float e = age / b.w;
        for (int k = 2; k >= 0; k--) {
            float delay = float(k) * 0.06;
            float ek = clamp((age - delay) / (b.w - delay), 0.0, 1.0);
            if (ek <= 0.0 || ek >= 1.0)
                continue;
            float out_ = 1.0 - (1.0 - ek) * (1.0 - ek);
            float radius = size * (1.2 + out_ * spread);
            float width = (1.6 - 0.4 * float(k)) * (1.0 - ek) + 0.4;
            float ring = clamp(width - abs(starEdge(q, radius)) / px + 0.5, 0.0, 1.0);
            vec3 tone = mix(light.rgb, ink.rgb, float(k) * 0.5);
            color = over(vec4(tone, 1.0) * ring * pow(1.0 - ek, 1.2) * (0.8 - 0.2 * float(k)) * (0.5 + 0.5 * b.z), color);
        }
        // Born a little too big, it settles, then closes as its rings fade
        float open = 1.5 * (1.0 - pow(1.0 - clamp(age / 0.09, 0.0, 1.0), 3.0));
        float settle = clamp((age - 0.09) / 0.22, 0.0, 1.0) - 1.0;
        float back = 1.0 + 2.70158 * settle * settle * settle + 1.70158 * settle * settle;
        float grown = (age < 0.09 ? open : mix(1.5, 1.0, back)) * (1.0 - smoothstep(0.4, 1.0, e));
        color = over(starAt(q, size * grown, b.z, size * 3.0, light.rgb, light.rgb, px), color);
    }
    return color;
}

// The constellations the music let go: each drifts up into the sky, drawing in toward the
// middle as it goes away, and pales until it's gone. Flat ink, a thread and small stars.
vec4 ghostsAt(vec2 at, float wide, float lift, float px) {
    float lets[8] = float[](ghostAt0.x, ghostAt0.y, ghostAt0.z, ghostAt0.w, ghostAt1.x, ghostAt1.y, ghostAt1.z, ghostAt1.w);
    vec4 color = vec4(0.0);
    for (int g = 0; g < 8; g++) {
        float age = time - lets[g];
        if (age < 0.0 || age > 2.6)
            continue;
        float e = age / 2.6;
        float away = 1.0 - (1.0 - e) * (1.0 - e);
        float s = 1.0 - 0.5 * away;
        vec2 local = vec2(800.0 + (at.x - 800.0) / s, (at.y - ghostRise * away) / s);
        if (local.y < -10.0 || local.y > lift + 30.0)
            continue;
        float cell = clamp(floor(local.x / wide), 0.0, 25.0);
        float row = (float(g) + 0.5) / 8.0;
        vec2 stars[3];
        float louds[3];
        for (int n = 0; n < 3; n++) {
            float c = clamp(cell + float(n - 1), 0.0, 25.0);
            float heard = texture(ghosts, vec2((c + 0.5) / 26.0, row)).r;
            stars[n] = vec2((c + 0.5) * wide, 10.0 + heard * lift);
            louds[n] = heard;
        }
        float d = min(cell > 0.0 ? toSegment(local, stars[0], stars[1]) : 1e4, cell < 25.0 ? toSegment(local, stars[1], stars[2]) : 1e4) * s / px;
        float thread = clamp(0.45 - d + 0.5, 0.0, 1.0) * 0.6;
        float size = (2.0 + 6.0 * louds[1]) * s;
        float body = clamp((size - starOf(abs(local - stars[1]) * s)) / (1.5 * px) + 0.5, 0.0, 1.0);
        float fade = pow(1.0 - e, 1.6) * 0.55;
        color = over(vec4(mix(ink.rgb, light.rgb, 0.25 * louds[1]), 1.0) * max(thread, body) * fade, color);
    }
    return color;
}

// The music on the ground, drawn only in the strip it can reach: lines echoing the
// ridge like a seismograph, bars, or columns of stars joined top to top. Flat, each edge
// antialiased over one pixel.
void main() {
    float k = world.x / 1600.0;
    vec2 p = (origin + qt_TexCoord0 * size) / k; // in units of the whole world
    float height = world.y / k;
    vec2 center = vec2(800.0, height * horizon + curve);
    float r = distance(p, center);
    float maxAmp = min(curve * 0.024, 34.0) * relief * (1.0 - orbit);
    // How far above its floor: the ridge's foot with hills, the screen's edge without,
    // measured straight up there so it stands out to the corners
    float up = mix(height - p.y, r - (curve + maxAmp), hills);
    float px = 1.0 / k; // a pixel, in units
    vec4 color = vec4(0.0);

    if (style < 0.5) {
        float angle = atan(p.x - center.x, center.y - p.y);
        float sampleStep = 2.0 * min(3.14159, asin(min(1.0, 1152.0 / curve)) * 1.15) / 340.0;
        float ridgeShape = hills > 0.5 ? heightOf(farA, seed, angle + planetAngle, sampleStep) : 0.0;
        float lit = 0.0;
        for (int i = 0; i < 6; i++) {
            float step = float(i);
            float heard = heardAt(p.x + step * 19.2);
            float line = (step + 1.0) * (5.0 + heard * reach / 9.0) + (hills > 0.5 ? curve + maxAmp * ridgeShape * (1.0 - step * 0.14) : 0.0);
            float d = abs((hills > 0.5 ? r : up) - line) / px;
            lit = max(lit, clamp(0.9 - d + 0.5, 0.0, 1.0) * (1.0 - step / 6.5) * (0.3 + heard * 0.7));
        }
        color = vec4(mix(ink.rgb, light.rgb, 0.5), 1.0) * lit;
    } else if (style < 1.5) {
        // Bars, rounded at the top, lighter as they climb
        float wide = 1600.0 / density;
        float cell = floor(p.x / wide);
        float offset = abs(p.x - (cell + 0.5) * wide);
        float heard = heardAt((cell + 0.5) * wide);
        float half_ = wide * 0.3;
        float top = 2.0 + heard * reach;
        float above = max(up - (top - half_), 0.0);
        float shape = clamp((half_ - length(vec2(offset, above))) / px + 0.5, 0.0, 1.0);
        float rise = clamp(up / reach, 0.0, 1.0);
        color = vec4(mix(ink.rgb, light.rgb, rise * 0.75), 1.0) * shape * (0.55 + 0.4 * rise);
    } else {
        float wide = 1600.0 / 26.0;
        float lift = reach * 1.3;
        vec2 at = vec2(p.x, up);
        color = ghostsAt(at, wide, lift, px);
        color = over(birthsAt(at, wide, px), color);
        color = over(constellationAt(at, wide, lift, px), color);
    }
    fragColor = color * qt_Opacity;
}
