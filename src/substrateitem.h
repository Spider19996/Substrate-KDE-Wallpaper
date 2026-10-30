#pragma once

#include "substrateengine.h"

#include <QQuickItem>
#include <QElapsedTimer>
#include <QTimer>
#include <QVariantList>
#include <qqmlintegration.h>

class SubstrateItem : public QQuickItem
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Substrate)
    // List of { key, collection, config } objects, usually ThemeStore.themes
    Q_PROPERTY(QVariantList themes READ themes WRITE setThemes NOTIFY themesChanged)
    // What runs: any mix of "all", "c:<collection>" and "t:<collection>/<name>" (empty = all)
    Q_PROPERTY(QStringList selection READ selection WRITE setSelection NOTIFY selectionChanged)
    // Simulation steps per second, i.e. the animation speed (TARGET_FPS of the original)
    Q_PROPERTY(int fps READ fps WRITE setFps NOTIFY fpsChanged)
    // Upper limit for rendered frames per second, 0 = refresh rate of the screen
    Q_PROPERTY(int maxFps READ maxFps WRITE setMaxFps NOTIFY maxFpsChanged)
    // Rendered frames per second, updated once a second
    Q_PROPERTY(int renderFps READ renderFps NOTIFY renderFpsChanged)
    // What the wallpaper costs, updated once a second together with renderFps:
    // simMs      average time of one simulation step in milliseconds
    // simLoad    share of one CPU core spent on simulation steps, in percent
    // memoryMb   memory for the picture: grid, image and the copy on the GPU
    // uploadMb   megabytes of picture sent to the GPU per second
    // sparkCount sparks flying right now
    Q_PROPERTY(QVariantMap usage READ usage NOTIFY renderFpsChanged)
    Q_PROPERTY(bool sparks READ sparks WRITE setSparks NOTIFY sparksChanged)
    Q_PROPERTY(qreal resolutionScale READ resolutionScale WRITE setResolutionScale NOTIFY resolutionScaleChanged)
    Q_PROPERTY(bool running READ running WRITE setRunning NOTIFY runningChanged)

public:
    explicit SubstrateItem(QQuickItem *parent = nullptr);

    QVariantList themes() const { return m_themeData; }
    void setThemes(const QVariantList &t);
    QStringList selection() const { return m_selection; }
    void setSelection(const QStringList &s);

    // Switches to another theme of the selection right away
    Q_INVOKABLE void nextTheme();
    // Starts the pattern from scratch
    Q_INVOKABLE void restart();
    int fps() const { return m_fps; }
    void setFps(int f);
    int maxFps() const { return m_maxFps; }
    void setMaxFps(int f);
    int renderFps() const { return m_renderFps; }
    QVariantMap usage() const { return m_usage; }
    bool sparks() const { return m_sparks; }
    void setSparks(bool s);
    qreal resolutionScale() const { return m_scale; }
    void setResolutionScale(qreal s);
    bool running() const { return m_running; }
    void setRunning(bool r);

signals:
    void themesChanged();
    void selectionChanged();
    void fpsChanged();
    void maxFpsChanged();
    void renderFpsChanged();
    void sparksChanged();
    void resolutionScaleChanged();
    void runningChanged();

protected:
    QSGNode *updatePaintNode(QSGNode *old, UpdatePaintNodeData *) override;
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;
    void itemChange(ItemChange change, const ItemChangeData &value) override;

private:
    struct Theme {
        QString key, collection;
        QVariantMap raw;
        SubstrateConfig config;
    };

    void parseThemes();
    bool matchesMode(const Theme &t) const;
    void applyTheme(bool avoidCurrent);
    void rebuildSurface();
    bool isActive() const;
    void updateActive();
    void advance();
    void scheduleFrame(double interval);
    void tick();

    QVariantList m_themeData;
    std::vector<Theme> m_themes;
    QStringList m_selection{QStringLiteral("c:oled")};
    QString m_currentKey;
    QVariantMap m_currentRaw;
    int m_fps = 60;
    int m_maxFps = 0;
    int m_renderFps = 0;
    QVariantMap m_usage;
    qint64 m_stepNanos = 0;
    int m_steps = 0, m_uploads = 0;
    bool m_sparks = true;
    bool m_running = true;
    qreal m_scale = 1.0;

    SubstrateEngine m_engine;
    QImage m_image;
    QTimer m_resizeTimer;
    // Simulation runs at a fixed rate, driven by the window's vsync; sparks are
    // interpolated between the last two steps so they move smoothly at any refresh rate
    QMetaObject::Connection m_frameConnection;
    QElapsedTimer m_clock;
    double m_accumulator = 0;
    float m_alpha = 1;
    bool m_imageDirty = true;
    // Nothing is drawn before a theme has been chosen, so the engine's plain default never shows up
    bool m_configApplied = false;
    // Requests the next frame; also used with 0 ms, since update() from within a frame can get lost
    QTimer m_frameTimer;
    // Restarts the frame loop if a frame request got lost anyway (e.g. while the window was hidden)
    QTimer m_watchdog;
    QElapsedTimer m_lastFrame;
    // Frame limit: time of the next frame on m_timeline, so the average rate is exact
    QElapsedTimer m_timeline;
    double m_nextFrameAt = -1;
    QElapsedTimer m_fpsClock;
    int m_frames = 0;

    // SUBSTRATE_DEBUG=1: frame timing statistics on stderr every 5 seconds
    struct Stats {
        QElapsedTimer window, frame;
        std::vector<float> intervals;
        int steps[5] = {};
        double stepMs = 0, syncMs = 0, syncMax = 0;
        int syncs = 0, uploads = 0;
    };
    bool m_debug = false;
    Stats m_stats;
    void reportStats();
};
