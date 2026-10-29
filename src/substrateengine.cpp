#include "substrateengine.h"

#include <QColor>
#include <QElapsedTimer>
#include <QPainter>
#include <QPen>

#include <algorithm>
#include <cmath>

namespace {
constexpr float EMPTY = 10001.0f;
constexpr double DEG = M_PI / 180.0;
constexpr size_t MAX_SPARKS = 6000;

QElapsedTimer &stopwatch()
{
    static QElapsedTimer t = [] { QElapsedTimer e; e.start(); return e; }();
    return t;
}

inline void blend(QRgb *px, QRgb c, int a256)
{
    const QRgb d = *px;
    int dr = (d >> 16) & 255, dg = (d >> 8) & 255, db = d & 255;
    dr += ((int(qRed(c)) - dr) * a256) >> 8;
    dg += ((int(qGreen(c)) - dg) * a256) >> 8;
    db += ((int(qBlue(c)) - db) * a256) >> 8;
    *px = qRgb(dr, dg, db);
}
}

SubstrateEngine::SubstrateEngine()
{
    m_rng ^= uint64_t(stopwatch().nsecsElapsed()) * 0x2545F4914F6CDD1Dull + uint64_t(quintptr(this));
}

qint64 SubstrateEngine::nowMs() const { return stopwatch().elapsed(); }

double SubstrateEngine::rnd()
{
    m_rng ^= m_rng >> 12;
    m_rng ^= m_rng << 25;
    m_rng ^= m_rng >> 27;
    return double((m_rng * 0x2545F4914F6CDD1Dull) >> 11) / 9007199254740992.0;
}

void SubstrateEngine::setConfig(const SubstrateConfig &cfg)
{
    m_cfg = cfg;
    if (m_cfg.colors.isEmpty()) m_cfg.colors.push_back(qRgb(255, 255, 255));
    m_needsClear = true;
    reset();
}

void SubstrateEngine::resize(int w, int h)
{
    m_w = std::max(1, w);
    m_h = std::max(1, h);
    hardReset();
}

void SubstrateEngine::hardReset()
{
    m_resetCounter = 0;
    m_fadingIn = false;
    m_needsClear = true;
    m_sparks.clear();
    reset();
}

void SubstrateEngine::startFade(bool switchTheme)
{
    // A fade that is already running is turned into a hard one, so the new pattern starts clean
    m_switchTheme = switchTheme;
    m_fadingIn = false;
    m_fadingOut = true;
    m_hardFading = true;
    m_fadeStart = nowMs();
    m_lastFadeStep = 0;
}

bool SubstrateEngine::takeThemeRequest()
{
    const bool r = m_themeRequest;
    m_themeRequest = false;
    return r;
}

float SubstrateEngine::grid(int x, int y) const
{
    if (x < 0 || x >= m_w || y < 0 || y >= m_h) return EMPTY;
    return m_grid[size_t(y) * m_w + x];
}

void SubstrateEngine::setGrid(int x, int y, float v)
{
    if (x < 0 || x >= m_w || y < 0 || y >= m_h) return;
    float &g = m_grid[size_t(y) * m_w + x];
    if (g == EMPTY) m_covered++;
    g = v;
}

void SubstrateEngine::reset()
{
    m_grid.assign(size_t(m_w) * m_h, EMPTY);
    m_covered = 0;
    m_total = qint64(m_w) * m_h;
    m_cracks.clear();
    m_fadingOut = false;
    m_hardFading = false;
    int initial = int(std::floor(double(m_w) * m_h / 100000.0 * m_cfg.cracksPer100k));
    initial = std::max(m_cfg.minInitialCracks, std::min(m_cfg.maxInitialCracks, initial));
    for (int i = 0; i < initial; i++) makeCrack();
}

void SubstrateEngine::makeCrack()
{
    if (int(m_cracks.size()) < m_cfg.maxCracks) m_cracks.push_back(newCrack());
}

SubstrateEngine::Crack SubstrateEngine::newCrack()
{
    Crack c{};
    c.color = m_cfg.colors[size_t(rnd() * m_cfg.colors.size()) % size_t(m_cfg.colors.size())];
    c.hue = rnd() * 360;
    if (m_cfg.rainbow) c.color = rainbowColor(c.hue);
    c.sandG = rnd() * 0.2 - 0.01;
    c.alive = true;
    c.step = m_cfg.stepMin + rnd() * (m_cfg.stepMax - m_cfg.stepMin);

    // Start on an already drawn pixel so the new crack branches off an old one
    int px = 0, py = 0;
    bool found = false;
    for (int tries = 0; !found && tries < 1000; tries++) {
        px = int(rnd() * m_w);
        py = int(rnd() * m_h);
        if (grid(px, py) < 10000) found = true;
    }
    if (!found) {
        px = int(rnd() * m_w);
        py = int(rnd() * m_h);
    }

    const float oldA = grid(px, py);
    double a;
    if (oldA > 10000) {
        a = rnd() * 360;
    } else {
        switch (m_cfg.branchMode) {
        case SubstrateConfig::Perpendicular: a = oldA + (rnd() < 0.5 ? 90 : -90); break;
        case SubstrateConfig::Opposite: a = oldA + 180 + (rnd() * 10 - 5); break;
        default: a = rnd() * 360;
        }
    }

    if (rnd() * 100 < m_cfg.circlePercent) {
        c.curved = true;
        double r = 10 + rnd() * (m_w + m_h) / 2.0;
        if (rnd() > 0.5) r = -r;
        const double radInc = c.step / r;
        c.tInc = radInc * 180 / M_PI;
        c.ys = r * std::sin(radInc);
        c.xs = r * (1 - std::cos(radInc));
    }

    c.x = px + 0.61 * std::cos(a * DEG);
    c.y = py + 0.61 * std::sin(a * DEG);
    c.t = a;
    c.lastX = c.x;
    c.lastY = c.y;
    return c;
}

void SubstrateEngine::sandRegion(const Crack &c, int dir, QImage &img)
{
    double rx = c.x, ry = c.y;
    const double tRad = c.t * DEG;
    const double sinT = std::sin(tRad), cosT = std::cos(tRad);
    for (;;) {
        rx += dir * 0.81 * sinT;
        ry -= dir * 0.81 * cosT;
        const int cx = int(std::floor(rx)), cy = int(std::floor(ry));
        if (cx < 0 || cx >= m_w || cy < 0 || cy >= m_h || grid(cx, cy) <= 10000) break;
    }

    // Const crack: sandG is advanced by the caller to keep both sides in sync
    const double w = c.sandG / (m_cfg.grains - 1);
    const double sandAlpha = m_cfg.sandAlpha > 0 ? m_cfg.sandAlpha : 0.1;
    for (int i = 0; i < m_cfg.grains; i++) {
        const double alpha = std::floor(sandAlpha * (1.0 - double(i) / m_cfg.grains) * 100) / 100;
        if (alpha <= 0.01) continue;
        const double s = std::sin(std::sin(i * w));
        const int gx = int(std::floor(c.x + (rx - c.x) * s));
        const int gy = int(std::floor(c.y + (ry - c.y) * s));
        if (gx < 0 || gx >= m_w || gy < 0 || gy >= m_h) continue;
        auto *line = reinterpret_cast<QRgb *>(img.scanLine(gy));
        blend(line + gx, c.color, int(alpha * 256));
    }
}

QRgb SubstrateEngine::rainbowColor(double hue) const
{
    return QColor::fromHslF(float(hue / 360.0), float(m_cfg.rainbowSaturation), float(m_cfg.rainbowLightness)).rgb();
}

void SubstrateEngine::moveCrack(Crack &c, std::vector<std::pair<QRgb, QLineF>> &lines, QImage &img)
{
    if (!c.alive) return; // caught in an explosion earlier in this step
    c.lastX = c.x;
    c.lastY = c.y;

    if (m_cfg.rainbow) {
        c.hue = std::fmod(c.hue + m_cfg.rainbowSpeed, 360.0);
        c.color = rainbowColor(c.hue);
    }

    if (m_cfg.driftEnabled && !c.curved && rnd() < m_cfg.driftFrequency)
        c.t += (rnd() * 2 - 1) * m_cfg.driftAmount;

    const double tRad = c.t * DEG;
    if (!c.curved) {
        c.x += c.step * std::cos(tRad);
        c.y += c.step * std::sin(tRad);
    } else {
        c.x += c.ys * std::cos(tRad) + c.xs * std::cos(tRad - M_PI / 2);
        c.y += c.ys * std::sin(tRad) + c.xs * std::sin(tRad - M_PI / 2);
        c.t += c.tInc;
        c.degreesDrawn += std::fabs(c.tInc);
    }

    const double r = rnd();
    const int cx = int(std::floor(c.x + r * 0.33 - 0.165));
    const int cy = int(std::floor(c.y + r * 0.33 - 0.165));

    bool split = false;
    if (cx >= 0 && cx < m_w && cy >= 0 && cy < m_h) {
        if (m_cfg.sandMode != SubstrateConfig::SandNone && m_cfg.grains > 1) {
            c.sandG = std::max(0.0, std::min(1.0, c.sandG + rnd() * 0.1 - 0.05));
            sandRegion(c, 1, img);
            if (m_cfg.sandMode == SubstrateConfig::SandBoth) {
                c.sandG = std::max(0.0, std::min(1.0, c.sandG + rnd() * 0.1 - 0.05));
                sandRegion(c, -1, img);
            }
        }

        lines.emplace_back(c.color, QLineF(std::round(c.lastX * 2) / 2, std::round(c.lastY * 2) / 2,
                                      std::round(c.x * 2) / 2, std::round(c.y * 2) / 2));

        if (m_cfg.sparkler && m_sparksEnabled)
            for (int i = 0; i < m_cfg.sparkSpawnRate; i++) spawnSpark(c.x, c.y, c.color);

        const float g = grid(cx, cy);
        if (c.curved && c.degreesDrawn > 360) {
            c.alive = false;
            split = true;
        } else if (g > 10000 || std::fabs(g - c.t) < 5) {
            setGrid(cx, cy, float(c.t));
        } else if (std::fabs(g) > 2) {
            // Hit another line
            c.alive = false;
            split = true;
            if (m_cfg.explosions && rnd() * 100 < m_cfg.explosionChance) {
                lines.pop_back(); // the last piece of this line is inside the blast
                explode(cx, cy, c.color, img);
            }
        }
    } else {
        c.alive = false;
        split = true;
    }

    if (split && !m_fadingOut) {
        makeCrack();
        makeCrack();
    }
}

void SubstrateEngine::spawnSpark(double x, double y, QRgb color, double speedFactor, int life)
{
    if (m_sparks.size() >= MAX_SPARKS) return;
    const double angle = rnd() * 2 * M_PI;
    const double speed = (m_cfg.sparkSpeedMin + rnd() * (m_cfg.sparkSpeedMax - m_cfg.sparkSpeedMin)) * speedFactor;
    m_sparks.push_back({float(x), float(y), float(std::cos(angle) * speed), float(std::sin(angle) * speed),
                        float(x), float(y),
                        life > 0 ? life : m_cfg.sparkLifetime, color});
}

// Blows a hole into the pattern: lines and sand inside disappear, growing lines in it die,
// and the freed pixels can be grown over again by later lines
void SubstrateEngine::explode(int cx, int cy, QRgb color, QImage &img)
{
    const double radius = std::max(3.0, std::min(m_w, m_h) * m_cfg.explosionRadius / 100.0) * (0.6 + 0.4 * rnd());
    const double solid = radius * 0.8;
    const int x0 = std::max(0, int(std::floor(cx - radius))), x1 = std::min(m_w - 1, int(std::ceil(cx + radius)));
    const int y0 = std::max(0, int(std::floor(cy - radius))), y1 = std::min(m_h - 1, int(std::ceil(cy + radius)));

    for (int y = y0; y <= y1; ++y) {
        auto *line = reinterpret_cast<QRgb *>(img.scanLine(y));
        for (int x = x0; x <= x1; ++x) {
            const double d = std::hypot(double(x - cx), double(y - cy));
            if (d > radius) continue;
            // Soft rim so the hole does not look cut out
            const int amount = d <= solid ? 256 : int((1.0 - (d - solid) / (radius - solid)) * 256.0);
            blend(line + x, m_cfg.bg, amount);
            if (d <= radius * 0.9) {
                // The pixel becomes free again, but the coverage counter keeps what was drawn there:
                // it measures how much has been drawn, so explosions cannot keep a pattern from ever "filling up"
                m_grid[size_t(y) * m_w + x] = EMPTY;
            }
        }
    }

    // Sand flies out of the blast: rays of grains that thin out with the distance, in the color of the line.
    // Each grain leaves a short smear along its ray, so it looks like the fans of sand next to the lines.
    if (m_cfg.explosionSand && m_cfg.explosionSandGrains > 0) {
        const int rays = 120;
        const int perRay = std::max(1, m_cfg.explosionSandGrains / rays);
        const double alphaMax = std::min(0.7, (m_cfg.sandAlpha > 0 ? m_cfg.sandAlpha : 0.1) * 5.0);
        for (int r = 0; r < rays; ++r) {
            const double angle = 2 * M_PI * (r + rnd()) / rays;
            const double reach = radius * (0.9 + 1.2 * rnd());
            const double dx = std::cos(angle), dy = std::sin(angle);
            for (int g = 0; g < perRay; ++g) {
                const double t0 = std::pow(rnd(), 0.8) * reach;
                for (int smear = 0; smear < 4; ++smear) {
                    const double t = t0 + smear * 0.9;
                    const int gx = int(std::floor(cx + dx * t)), gy = int(std::floor(cy + dy * t));
                    if (gx < 0 || gx >= m_w || gy < 0 || gy >= m_h) continue;
                    const double alpha = alphaMax * (1.0 - t / reach) * (1.0 - smear * 0.2);
                    if (alpha < 0.01) continue;
                    blend(reinterpret_cast<QRgb *>(img.scanLine(gy)) + gx, color, int(alpha * 256));
                }
            }
        }
    }

    // Growing lines caught in the blast end here, without the usual new branches
    for (Crack &other : m_cracks)
        if (other.alive && std::hypot(other.x - cx, other.y - cy) <= radius) other.alive = false;

    if (m_cfg.sparkler && m_sparksEnabled) {
        const int life = m_cfg.sparkLifetime * 2;
        for (int i = 0; i < m_cfg.explosionSparks; ++i) spawnSpark(cx, cy, color, 2.5, life);
    }
}

void SubstrateEngine::updateSparks()
{
    for (size_t i = m_sparks.size(); i-- > 0;) {
        Spark &s = m_sparks[i];
        s.px = s.x;
        s.py = s.y;
        s.x += s.vx;
        s.y += s.vy;
        s.vy += 0.05f;
        if (--s.life <= 0) {
            s = m_sparks.back();
            m_sparks.pop_back();
        }
    }
}

// Moves every pixel towards the background by amount/256 of the remaining distance, at least one level,
// so even faint sand fades out completely instead of staying behind as a ghost
void SubstrateEngine::fadeToBackground(QImage &img, int amount) const
{
    // One byte per channel (B, G, R, X): simple integer math the compiler can vectorize.
    // The fourth byte of an opaque pixel already equals its target and stays put.
    const int bytes = img.width() * 4;
    std::vector<uchar> target(static_cast<size_t>(bytes), uchar(0));
    for (int i = 0; i < bytes; i += 4) {
        target[size_t(i)] = uchar(qBlue(m_cfg.bg));
        target[size_t(i) + 1] = uchar(qGreen(m_cfg.bg));
        target[size_t(i) + 2] = uchar(qRed(m_cfg.bg));
        target[size_t(i) + 3] = 0xFF;
    }
    const uchar *t = target.data();
    for (int y = 0; y < img.height(); ++y) {
        uchar *p = img.scanLine(y);
        for (int i = 0; i < bytes; ++i) {
            const int v = p[i];
            const int d = int(t[i]) - v;
            const int step = ((d < 0 ? -d : d) * amount + 255) >> 8;
            p[i] = uchar(d < 0 ? v - step : v + step);
        }
    }
}

double SubstrateEngine::fadeProgress() const
{
    if (!m_fadingOut) return 0;
    const double dur = m_hardFading ? m_cfg.hardFadeSeconds : m_cfg.fadeOutSeconds;
    return std::min((nowMs() - m_fadeStart) / 1000.0 / dur, 1.0);
}

void SubstrateEngine::step(QImage &img)
{
    if (m_needsClear) {
        img.fill(m_cfg.bg);
        m_needsClear = false;
    }

    std::vector<std::pair<QRgb, QLineF>> lines;

    if (m_fadingOut) {
        // The fade is timed, not counted in steps: after the fade time the picture is plain background
        const double seconds = m_hardFading ? m_cfg.hardFadeSeconds : m_cfg.fadeOutSeconds;
        const qint64 now = nowMs();
        const double dtMs = m_lastFadeStep > 0 ? std::clamp<double>(double(now - m_lastFadeStep), 1.0, 100.0) : 16.0;
        m_lastFadeStep = now;
        const int amount = seconds <= 0 ? 256
            : std::clamp(int(std::lround((1.0 - std::pow(256.0, -dtMs / (seconds * 1000.0))) * 256.0)), 1, 256);
        fadeToBackground(img, amount);
        if (fadeProgress() >= 1) {
            fadeToBackground(img, 256);
            if (m_hardFading) {
                img.fill(m_cfg.bg);
                m_sparks.clear();
                m_resetCounter = 0;
                reset();
                m_fadingIn = true;
                m_fadeInStart = nowMs();
                m_themeRequest = m_switchTheme;
                m_switchTheme = true;
            } else {
                m_resetCounter++;
                reset();
            }
        }
    } else {
        // Sand is blended straight into the pixels, lines are collected and stroked afterwards
        lines.reserve(m_cracks.size());
        for (size_t i = m_cracks.size(); i-- > 0;) {
            // Moving a crack can append new ones, so only the index is stable
            Crack c = m_cracks[i];
            moveCrack(c, lines, img);
            m_cracks[i] = c;
            if (!c.alive) {
                m_cracks[i] = m_cracks.back();
                m_cracks.pop_back();
            }
        }

        QPainter p(&img);
        p.setRenderHint(QPainter::Antialiasing, m_cfg.antiAliasing);
        QPen pen;
        pen.setWidthF(m_cfg.lineWidth);
        pen.setCapStyle(Qt::RoundCap);
        const int alpha = m_fadingIn ? 128 : 255;
        QRgb last = 0;
        bool have = false;
        for (const auto &l : lines) {
            if (!have || l.first != last) {
                last = l.first;
                have = true;
                QColor col(last);
                col.setAlpha(alpha);
                pen.setColor(col);
                p.setPen(pen);
            }
            p.drawLine(l.second);
        }
    }

    updateSparks();

    if (m_fadingIn && (nowMs() - m_fadeInStart) / 1000.0 >= m_cfg.hardFadeInSeconds) m_fadingIn = false;

    if (!m_fadingOut && !m_fadingIn
        && (m_cracks.empty() || double(m_covered) / double(m_total) >= m_cfg.coverageResetPercent / 100.0)) {
        if (m_cfg.fadeOutSeconds > 0) {
            m_fadingOut = true;
            m_fadeStart = nowMs();
            m_lastFadeStep = 0;
            m_hardFading = m_cfg.hardResetEvery > 0 && m_resetCounter >= m_cfg.hardResetEvery - 1;
        } else {
            img.fill(m_cfg.bg);
            reset();
        }
    }
}
