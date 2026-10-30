#include "substrateitem.h"

#include <QQuickWindow>
#include <QScreen>
#include <QRandomGenerator>
#include <QSGGeometryNode>
#include <QSGSimpleTextureNode>
#include <QSGVertexColorMaterial>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstring>

namespace {
SubstrateConfig parseConfig(const QVariantMap &m)
{
    SubstrateConfig c;
    auto num = [&](const char *k, double def) { return m.contains(k) ? m.value(k).toDouble() : def; };
    auto flag = [&](const char *k, bool def) { return m.contains(k) ? m.value(k).toBool() : def; };
    auto rgb = [](const QVariant &v) {
        const QVariantList l = v.toList();
        return l.size() >= 3 ? qRgb(l[0].toInt(), l[1].toInt(), l[2].toInt()) : qRgb(0, 0, 0);
    };

    c.stepMin = num("STEP_MIN", c.stepMin);
    c.stepMax = num("STEP_MAX", c.stepMax);
    c.cracksPer100k = num("CRACKS_PER_100K_PIXELS", c.cracksPer100k);
    c.minInitialCracks = int(num("MIN_INITIAL_CRACKS", c.minInitialCracks));
    c.maxInitialCracks = int(num("MAX_INITIAL_CRACKS", c.maxInitialCracks));
    c.maxCracks = int(num("MAX_CRACKS", c.maxCracks));
    c.circlePercent = num("CIRCLE_PERCENT", c.circlePercent);
    c.grains = int(num("GRAINS", c.grains));
    c.sandAlpha = num("SAND_ALPHA", c.sandAlpha);
    c.lineWidth = num("LINE_WIDTH", c.lineWidth);
    c.antiAliasing = flag("ANTI_ALIASING", c.antiAliasing);
    c.coverageResetPercent = num("COVERAGE_RESET_PERCENT", c.coverageResetPercent);
    c.fadeOutSeconds = num("FADE_OUT_SECONDS", c.fadeOutSeconds);
    c.hardResetEvery = int(num("HARD_RESET_EVERY", c.hardResetEvery));
    c.hardFadeSeconds = num("HARD_FADE_SECONDS", c.hardFadeSeconds);
    c.hardFadeInSeconds = num("HARD_FADE_IN_SECONDS", c.hardFadeInSeconds);
    c.driftEnabled = flag("LINE_DRIFT_ENABLED", c.driftEnabled);
    c.driftAmount = num("LINE_DRIFT_AMOUNT", c.driftAmount);
    c.driftFrequency = num("LINE_DRIFT_FREQUENCY", c.driftFrequency);
    c.sparkler = flag("SPARKLER_ENABLED", c.sparkler);
    c.sparkSpawnRate = int(num("SPARK_SPAWN_RATE", c.sparkSpawnRate));
    c.sparkSpeedMin = num("SPARK_SPEED_MIN", c.sparkSpeedMin);
    c.sparkSpeedMax = num("SPARK_SPEED_MAX", c.sparkSpeedMax);
    c.sparkLifetime = std::max(1, int(num("SPARK_LIFETIME", c.sparkLifetime)));
    c.sparkSize = num("SPARK_SIZE", c.sparkSize);
    c.sparkGlow = num("SPARK_GLOW", c.sparkGlow);
    c.explosions = flag("EXPLOSIONS", c.explosions);
    c.explosionChance = std::clamp(num("EXPLOSION_CHANCE", c.explosionChance), 0.0, 100.0);
    c.explosionRadius = std::clamp(num("EXPLOSION_RADIUS", c.explosionRadius), 0.5, 50.0);
    c.explosionSparks = std::max(0, int(num("EXPLOSION_SPARKS", c.explosionSparks)));
    c.explosionSand = flag("EXPLOSION_SAND", c.explosionSand);
    c.explosionSandGrains = std::max(0, int(num("EXPLOSION_SAND_GRAINS", c.explosionSandGrains)));
    c.rainbow = flag("RAINBOW", c.rainbow);
    c.rainbowSpeed = num("RAINBOW_SPEED", c.rainbowSpeed);
    c.rainbowSaturation = std::clamp(num("RAINBOW_SATURATION", c.rainbowSaturation), 0.0, 1.0);
    c.rainbowLightness = std::clamp(num("RAINBOW_LIGHTNESS", c.rainbowLightness), 0.0, 1.0);

    const QString sand = m.value("SAND_MODE").toString();
    c.sandMode = sand == "none" ? SubstrateConfig::SandNone
               : sand == "one"  ? SubstrateConfig::SandOne
                                : SubstrateConfig::SandBoth;
    const QString branch = m.value("BRANCH_MODE").toString();
    c.branchMode = branch == "opposite" ? SubstrateConfig::Opposite
                 : branch == "perpendicular" || branch.isEmpty() ? SubstrateConfig::Perpendicular
                                                                 : SubstrateConfig::Random;

    if (m.contains("BG_COLOR")) c.bg = rgb(m.value("BG_COLOR"));
    c.colors.clear();
    for (const QVariant &v : m.value("COLORS").toList()) c.colors.push_back(rgb(v));
    if (c.colors.isEmpty()) c.colors.push_back(qRgb(255, 255, 255));
    return c;
}

struct SceneNode : QSGNode {
    QSGSimpleTextureNode *texture = nullptr;
    QSGGeometryNode *sparks = nullptr;
    QSGGeometry *geometry = nullptr;
    int capacity = 0;
};

// Premultiplied vertex colour
inline void setColor(QSGGeometry::ColoredPoint2D &v, QRgb c, float a)
{
    v.r = uchar(qRed(c) * a);
    v.g = uchar(qGreen(c) * a);
    v.b = uchar(qBlue(c) * a);
    v.a = uchar(255 * a);
}
}

SubstrateItem::SubstrateItem(QQuickItem *parent)
    : QQuickItem(parent)
{
    setFlag(ItemHasContents, true);
    m_debug = qEnvironmentVariableIntValue("SUBSTRATE_DEBUG") > 0;
    m_resizeTimer.setSingleShot(true);
    m_resizeTimer.setInterval(300);
    connect(&m_resizeTimer, &QTimer::timeout, this, &SubstrateItem::rebuildSurface);
    // If no theme list ever arrives (nothing installed, all hidden), the plain default runs after a short wait
    QTimer::singleShot(1000, this, [this] { if (!m_configApplied) applyTheme(false); });
    m_frameTimer.setSingleShot(true);
    m_frameTimer.setTimerType(Qt::PreciseTimer);
    connect(&m_frameTimer, &QTimer::timeout, this, [this] {
        if (isActive()) update();
    });
    m_timeline.start();
    m_watchdog.setInterval(500);
    connect(&m_watchdog, &QTimer::timeout, this, [this] {
        if (isActive() && (!m_lastFrame.isValid() || m_lastFrame.elapsed() > 400)) update();
    });
}

void SubstrateItem::setThemes(const QVariantList &t)
{
    m_themeData = t;
    parseThemes();
    emit themesChanged();

    // Theme files change while editing: keep the running pattern unless its own theme changed
    for (const Theme &th : m_themes) {
        if (th.key != m_currentKey || !matchesMode(th)) continue;
        if (th.raw != m_currentRaw) {
            m_currentRaw = th.raw;
            m_configApplied = true;
            m_engine.setConfig(th.config);
            m_engine.setSparksEnabled(m_sparks);
            if (!m_image.isNull()) m_image.fill(th.config.bg);
            m_imageDirty = true;
        }
        return;
    }
    applyTheme(false);
}

bool SubstrateItem::matchesMode(const Theme &t) const
{
    if (m_selection.isEmpty()) return true;
    for (const QString &entry : m_selection) {
        if (entry == QLatin1String("all")) return true;
        // A collection covers its subcollections too
        if (entry.startsWith(QLatin1String("c:"))
            && (entry.mid(2) == t.collection || t.collection.startsWith(entry.mid(2) + QLatin1Char('/')))) return true;
        if (entry.startsWith(QLatin1String("t:")) && entry.mid(2) == t.key) return true;
    }
    return false;
}

void SubstrateItem::parseThemes()
{
    m_themes.clear();
    for (const QVariant &v : std::as_const(m_themeData)) {
        const QVariantMap m = v.toMap();
        const QVariantMap raw = m.value("config").toMap();
        m_themes.push_back({m.value("key").toString(), m.value("collection").toString(), raw, parseConfig(raw)});
    }
}

void SubstrateItem::setSelection(const QStringList &s)
{
    if (s == m_selection) return;
    m_selection = s;
    emit selectionChanged();
    // Keep the running theme if it is still part of the selection
    for (const Theme &t : m_themes)
        if (t.key == m_currentKey && matchesMode(t)) return;
    applyTheme(false);
}

// Both fade the current picture out first, like a full one, then the new pattern fades in
void SubstrateItem::nextTheme()
{
    if (m_image.isNull()) return;
    m_engine.startFade(true);
    update();
}

void SubstrateItem::restart()
{
    if (m_image.isNull()) return;
    m_engine.startFade(false);
    update();
}

void SubstrateItem::setFps(int f)
{
    f = std::clamp(f, 1, 240);
    if (f == m_fps) return;
    m_fps = f;
    emit fpsChanged();
}

void SubstrateItem::setMaxFps(int f)
{
    f = std::clamp(f, 0, 1000);
    if (f == m_maxFps) return;
    m_maxFps = f;
    emit maxFpsChanged();
    updateActive();
}

void SubstrateItem::setSparks(bool s)
{
    if (s == m_sparks) return;
    m_sparks = s;
    m_engine.setSparksEnabled(s);
    emit sparksChanged();
}

void SubstrateItem::setResolutionScale(qreal s)
{
    s = std::clamp(s, 0.1, 2.0);
    if (qFuzzyCompare(s, m_scale)) return;
    m_scale = s;
    emit resolutionScaleChanged();
    rebuildSurface();
}

void SubstrateItem::setRunning(bool r)
{
    if (r == m_running) return;
    m_running = r;
    emit runningChanged();
    updateActive();
}

// Picks a theme matching the mode, preferring a different one than the current
void SubstrateItem::applyTheme(bool avoidCurrent)
{
    std::vector<const Theme *> pool;
    for (const Theme &t : m_themes)
        if (matchesMode(t)) pool.push_back(&t);
    if (pool.empty())
        for (const Theme &t : m_themes) pool.push_back(&t);
    if (pool.empty()) {
        // No theme at all (e.g. built-in themes hidden and none of your own): plain default colors
        SubstrateConfig fallback;
        fallback.colors = {qRgb(255, 50, 50), qRgb(50, 255, 50), qRgb(50, 50, 255),
                           qRgb(255, 255, 0), qRgb(255, 0, 255), qRgb(0, 255, 255)};
        m_currentKey.clear();
        m_currentRaw.clear();
        m_configApplied = true;
        m_engine.setConfig(fallback);
        m_engine.setSparksEnabled(m_sparks);
        if (!m_image.isNull()) m_image.fill(fallback.bg);
        m_imageDirty = true;
        return;
    }

    if (pool.size() > 1 && !m_currentKey.isEmpty())
        pool.erase(std::remove_if(pool.begin(), pool.end(),
                                  [&](const Theme *t) { return t->key == m_currentKey; }),
                   pool.end());
    const Theme *t = pool[QRandomGenerator::global()->bounded(quint32(pool.size()))];
    if (avoidCurrent && t->key == m_currentKey) return;

    m_currentKey = t->key;
    m_currentRaw = t->raw;
    m_configApplied = true;
    m_engine.setConfig(t->config);
    m_engine.setSparksEnabled(m_sparks);
    if (!m_image.isNull()) m_image.fill(t->config.bg);
    m_imageDirty = true;
}

void SubstrateItem::rebuildSurface()
{
    const int w = std::max(1, int(std::lround(width() * m_scale)));
    const int h = std::max(1, int(std::lround(height() * m_scale)));
    if (width() < 1 || height() < 1) return;
    if (m_image.isNull() || m_image.width() != w || m_image.height() != h) {
        m_image = QImage(w, h, QImage::Format_RGB32);
        m_engine.resize(w, h);
        if (!m_themes.empty()) m_image.fill(m_engine.config().bg);
        m_imageDirty = true;
    }
    updateActive();
}

bool SubstrateItem::isActive() const
{
    return m_running && isVisible() && window() && !m_image.isNull();
}

// Requesting a frame starts the loop: every rendered frame calls advance(), which requests the next
void SubstrateItem::updateActive()
{
    if (isActive()) {
        update();
        m_watchdog.start();
    } else {
        m_clock.invalidate();
        m_frameTimer.stop();
        m_watchdog.stop();
    }
}

void SubstrateItem::advance()
{
    if (!isActive()) {
        m_clock.invalidate();
        return;
    }
    m_lastFrame.start();

    const double interval = 1000.0 / m_fps;
    if (!m_clock.isValid()) {
        m_clock.start();
        m_accumulator = interval; // step right away
    } else {
        m_accumulator += m_clock.nsecsElapsed() / 1e6;
        m_clock.restart();
    }

    // At most a few catch-up steps, a longer stall is simply skipped
    QElapsedTimer stepTime;
    if (m_debug) stepTime.start();
    int steps = 0;
    for (; m_accumulator >= interval && steps < 4; ++steps) {
        tick();
        m_accumulator -= interval;
    }
    if (m_debug) {
        m_stats.steps[steps]++;
        m_stats.stepMs += stepTime.nsecsElapsed() / 1e6;
        if (m_stats.frame.isValid()) m_stats.intervals.push_back(m_stats.frame.nsecsElapsed() / 1e6f);
        m_stats.frame.start();
        if (!m_stats.window.isValid()) m_stats.window.start();
        if (m_stats.window.elapsed() > 5000) reportStats();
    }
    m_accumulator = std::min(m_accumulator, interval);
    m_alpha = float(m_accumulator / interval);

    m_frames++;
    if (!m_fpsClock.isValid()) m_fpsClock.start();
    if (m_fpsClock.elapsed() >= 1000) {
        const qint64 elapsedMs = std::max<qint64>(1, m_fpsClock.restart());
        m_renderFps = int(std::lround(m_frames * 1000.0 / elapsedMs));
        m_frames = 0;

        const double imageMb = m_image.sizeInBytes() / 1048576.0;
        m_usage[QStringLiteral("simMs")] = m_steps > 0 ? m_stepNanos / 1e6 / m_steps : 0.0;
        m_usage[QStringLiteral("simLoad")] = m_stepNanos / 1e6 / elapsedMs * 100.0;
        m_usage[QStringLiteral("memoryMb")] = (m_engine.memoryBytes() / 1048576.0) + 2 * imageMb;
        m_usage[QStringLiteral("uploadMb")] = m_uploads * imageMb * 1000.0 / elapsedMs;
        m_usage[QStringLiteral("sparkCount")] = int(m_engine.sparks().size());
        m_stepNanos = 0;
        m_steps = 0;
        m_uploads = 0;
        emit renderFpsChanged();
    }
    scheduleFrame(interval);
}

void SubstrateItem::scheduleFrame(double interval)
{
    // Sparks move in every frame; without them only the next simulation step changes the picture
    const bool moving = m_sparks && !m_engine.sparks().empty();
    double wait = moving ? 0.0 : interval - m_accumulator;
    if (m_maxFps > 0) {
        // Frames follow a fixed timeline, so rates that don't divide the refresh rate still average out.
        // The timer fires a little early; the frame itself is shown at the following vsync.
        const double frameMs = 1000.0 / m_maxFps;
        const double now = m_timeline.nsecsElapsed() / 1e6;
        if (m_nextFrameAt < 0 || now - m_nextFrameAt > frameMs) m_nextFrameAt = now;
        m_nextFrameAt += frameMs;
        wait = std::max(wait, m_nextFrameAt - now - 1.0);
    } else {
        m_nextFrameAt = -1;
    }
    m_frameTimer.start(std::max(0, int(wait)));
}

void SubstrateItem::tick()
{
    if (m_image.isNull() || !m_configApplied) return;
    QElapsedTimer stepTime;
    stepTime.start();
    m_engine.step(m_image);
    m_stepNanos += stepTime.nsecsElapsed();
    m_steps++;
    m_imageDirty = true;
    if (m_engine.takeThemeRequest()) applyTheme(true);
}

void SubstrateItem::geometryChange(const QRectF &n, const QRectF &o)
{
    QQuickItem::geometryChange(n, o);
    if (n.size() == o.size()) return;
    // First size is applied immediately, later changes (e.g. monitor setup) are debounced
    if (m_image.isNull()) rebuildSurface();
    else m_resizeTimer.start();
}

void SubstrateItem::itemChange(ItemChange change, const ItemChangeData &value)
{
    QQuickItem::itemChange(change, value);
    if (change == ItemVisibleHasChanged || change == ItemSceneChange) {
        if (change == ItemSceneChange) {
            disconnect(m_frameConnection);
            if (value.window)
                m_frameConnection = connect(value.window, &QQuickWindow::afterAnimating, this,
                                            &SubstrateItem::advance, Qt::DirectConnection);
            if (value.window && m_image.isNull()) rebuildSurface();
        }
        updateActive();
    }
}

void SubstrateItem::reportStats()
{
    auto &s = m_stats;
    std::vector<float> d = s.intervals;
    std::sort(d.begin(), d.end());
    auto q = [&](double p) { return d.empty() ? 0.0f : d[size_t(p * (d.size() - 1))]; };
    int slow = 0;
    for (float x : d) if (x > 2 * q(0.5)) slow++;
    fprintf(stderr,
            "substrate[%s %dx%d img %dx%d]: %.1f fps, frame p50 %.2f p99 %.2f max %.2f ms, >2x median %d | "
            "steps/frame 0:%d 1:%d 2:%d 3+:%d, step %.2f ms/frame | sync avg %.2f max %.2f ms, uploads %d | sparks %zu\n",
            window() && window()->screen() ? qPrintable(window()->screen()->name()) : "?", int(width()), int(height()),
            m_image.width(), m_image.height(), d.size() / (s.window.elapsed() / 1000.0), q(0.5), q(0.99),
            d.empty() ? 0.0f : d.back(), slow, s.steps[0], s.steps[1], s.steps[2], s.steps[3] + s.steps[4],
            s.stepMs / std::max<size_t>(1, d.size()), s.syncMs / std::max(1, s.syncs), s.syncMax, s.uploads,
            m_engine.sparks().size());
    s = Stats();
}

QSGNode *SubstrateItem::updatePaintNode(QSGNode *old, UpdatePaintNodeData *)
{
    QElapsedTimer syncTime;
    if (m_debug) syncTime.start();
    auto *root = static_cast<SceneNode *>(old);
    if (!root) {
        root = new SceneNode;
        root->texture = new QSGSimpleTextureNode;
        root->texture->setOwnsTexture(true);
        root->texture->setFiltering(QSGTexture::Linear);

        // Never empty and rarely reallocated: unused vertices are degenerate triangles
        root->capacity = 1024;
        root->geometry = new QSGGeometry(QSGGeometry::defaultAttributes_ColoredPoint2D(), root->capacity);
        root->geometry->setDrawingMode(QSGGeometry::DrawTriangles);
        root->geometry->setVertexDataPattern(QSGGeometry::DynamicPattern);
        memset(root->geometry->vertexData(), 0, size_t(root->capacity) * root->geometry->sizeOfVertex());
        auto *mat = new QSGVertexColorMaterial;
        mat->setFlag(QSGMaterial::Blending, true);
        root->sparks = new QSGGeometryNode;
        root->sparks->setGeometry(root->geometry);
        root->sparks->setFlag(QSGNode::OwnsGeometry);
        root->sparks->setMaterial(mat);
        root->sparks->setFlag(QSGNode::OwnsMaterial);
        root->appendChildNode(root->sparks);
    }

    // The GUI thread is blocked while we sync, so image and spark state are stable here.
    // Until the first frame exists a black pixel keeps the scene graph structure fixed.
    if (window() && (m_imageDirty || !root->texture->texture())) {
        QImage fallback;
        if (m_image.isNull()) {
            fallback = QImage(1, 1, QImage::Format_RGB32);
            fallback.fill(Qt::black);
        }
        QSGTexture *tex = window()->createTextureFromImage(m_image.isNull() ? fallback : m_image,
                                                           QQuickWindow::TextureIsOpaque);
        root->texture->setTexture(tex); // the node owns its textures and frees the previous one
        if (!root->texture->parent()) root->prependChildNode(root->texture);
        m_imageDirty = m_image.isNull();
        m_uploads++;
        if (m_debug) m_stats.uploads++;
    }
    root->texture->setRect(boundingRect());

    const auto &sparks = m_engine.sparks();
    const SubstrateConfig &cfg = m_engine.config();
    const float sx = m_image.isNull() ? 1.0f : float(width()) / m_image.width();
    const float sy = m_image.isNull() ? 1.0f : float(height()) / m_image.height();
    const float fade = m_engine.fadingIn() ? 0.5f : 1.0f;
    const float size = float(cfg.sparkSize), glow = float(cfg.sparkGlow);
    const bool drawGlow = glow > 0;
    const int perSpark = (drawGlow ? 12 : 0) + 6;

    const int count = m_sparks ? int(sparks.size()) * perSpark : 0;
    if (count > root->capacity || count < root->capacity / 4) {
        int cap = 1024;
        while (cap < count) cap *= 2;
        root->capacity = cap;
        root->geometry->allocate(cap);
    }
    auto *const first = root->geometry->vertexDataAsColoredPoint2D();
    auto *v = first;
    for (size_t i = 0; i < size_t(count / perSpark); ++i) {
        const Spark &s = sparks[i];
        const float a = float(s.life) / cfg.sparkLifetime * fade;
        const float x = (s.px + (s.x - s.px) * m_alpha) * sx;
        const float y = (s.py + (s.y - s.py) * m_alpha) * sy;
        auto vtx = [&](float px, float py, float alpha) {
            v->x = px; v->y = py;
            setColor(*v, s.color, alpha);
            ++v;
        };
        if (drawGlow) {
            // Soft glow: bright centre fading to transparent corners
            const float cx = x + size * sx * 0.5f, cy = y + size * sy * 0.5f;
            const float gx = glow * sx, gy = glow * sy;
            const float c[4][2] = {{cx - gx, cy - gy}, {cx + gx, cy - gy}, {cx + gx, cy + gy}, {cx - gx, cy + gy}};
            for (int k = 0; k < 4; ++k) {
                vtx(cx, cy, a * 0.3f);
                vtx(c[k][0], c[k][1], 0.0f);
                vtx(c[(k + 1) % 4][0], c[(k + 1) % 4][1], 0.0f);
            }
        }
        const float x1 = x + size * sx, y1 = y + size * sy;
        vtx(x, y, a); vtx(x1, y, a); vtx(x1, y1, a);
        vtx(x, y, a); vtx(x1, y1, a); vtx(x, y1, a);
    }
    memset(v, 0, size_t(first + root->capacity - v) * sizeof(QSGGeometry::ColoredPoint2D));
    root->geometry->markVertexDataDirty();
    root->sparks->markDirty(QSGNode::DirtyGeometry);
    if (m_debug) {
        const double ms = syncTime.nsecsElapsed() / 1e6;
        m_stats.syncMs += ms;
        m_stats.syncMax = std::max(m_stats.syncMax, ms);
        m_stats.syncs++;
    }
    return root;
}
