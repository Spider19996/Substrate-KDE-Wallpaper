#pragma once

#include <QImage>
#include <QRgb>
#include <QVector>

#include <cstdint>
#include <vector>

// Simulation of the Substrate screensaver (cracks, sand, sparks).
// Pure C++ without any Qt Quick dependency so it can be benchmarked headless.

struct SubstrateConfig {
    enum SandMode { SandBoth, SandOne, SandNone };
    enum BranchMode { Perpendicular, Opposite, Random };

    double stepMin = 0.1, stepMax = 1.5;
    double cracksPer100k = 1;
    int minInitialCracks = 2, maxInitialCracks = 20, maxCracks = 100;
    double circlePercent = 40;

    int grains = 64;
    SandMode sandMode = SandBoth;
    double sandAlpha = 0.1;
    double lineWidth = 1;
    bool antiAliasing = true;

    double coverageResetPercent = 10;
    double fadeOutSeconds = 3;
    int hardResetEvery = 3;
    double hardFadeSeconds = 2;
    double hardFadeInSeconds = 2;

    BranchMode branchMode = Perpendicular;

    bool driftEnabled = false;
    double driftAmount = 2, driftFrequency = 0.3;

    bool sparkler = true;
    int sparkSpawnRate = 3;
    double sparkSpeedMin = 0.5, sparkSpeedMax = 2.5;
    int sparkLifetime = 15;
    double sparkSize = 1.3, sparkGlow = 2.0;

    // Rainbow: lines (and their sand and sparks) run through all hues while they grow
    bool rainbow = false;
    double rainbowSpeed = 0.6;      // degrees of hue per step
    double rainbowSaturation = 1.0;
    double rainbowLightness = 0.55;

    // Explosions: a line that hits another line can blow up, erasing everything around the impact
    bool explosions = false;
    double explosionChance = 10;    // percent of impacts
    double explosionRadius = 4;     // percent of the shorter screen side
    int explosionSparks = 60;
    bool explosionSand = false;     // a burst of sand at the impact, like the sand along the lines
    int explosionSandGrains = 3000;

    QRgb bg = qRgb(0, 0, 0);
    QVector<QRgb> colors{qRgb(255, 255, 255)};
};

struct Spark {
    float x, y, vx, vy;
    float px, py; // position one step earlier, for interpolated drawing
    int life;
    QRgb color;
};

class SubstrateEngine
{
public:
    SubstrateEngine();

    // Applies a theme and restarts the pattern (the fade-in state is kept)
    void setConfig(const SubstrateConfig &cfg);
    void setSparksEnabled(bool on) { m_sparksEnabled = on; }
    // New size: starts from scratch, the caller has to hand in an image of that size
    void resize(int w, int h);
    void hardReset();
    // Ends the pattern like a full one: it fades out, then a new one fades in.
    // With switchTheme the owner is asked for another theme afterwards (takeThemeRequest).
    void startFade(bool switchTheme);

    // Advances one frame and paints into the persistent image
    void step(QImage &img);

    const SubstrateConfig &config() const { return m_cfg; }
    const std::vector<Spark> &sparks() const { return m_sparks; }
    bool fadingIn() const { return m_fadingIn; }
    bool fading() const { return m_fadingOut; }
    int width() const { return m_w; }
    int height() const { return m_h; }
    // True once after a hard reset, the owner may then switch to the next theme
    bool takeThemeRequest();

private:
    struct Crack {
        double x, y, lastX, lastY, t;
        double step, tInc, xs, ys, degreesDrawn, sandG, hue;
        bool curved, alive;
        QRgb color;
    };

    double rnd();
    float grid(int x, int y) const;
    void setGrid(int x, int y, float v);
    void reset();
    void makeCrack();
    Crack newCrack();
    void sandRegion(const Crack &c, int dir, QImage &img);
    void moveCrack(Crack &c, std::vector<std::pair<QRgb, QLineF>> &lines, QImage &img);
    void updateSparks();
    void spawnSpark(double x, double y, QRgb color, double speedFactor = 1.0, int life = 0);
    void explode(int x, int y, QRgb color, QImage &img);
    QRgb rainbowColor(double hue) const;
    double fadeProgress() const;
    void fadeToBackground(QImage &img, int amount256) const;
    qint64 nowMs() const;

    SubstrateConfig m_cfg;
    int m_w = 1, m_h = 1;
    std::vector<float> m_grid;
    qint64 m_covered = 0, m_total = 1; // pixels drawn so far (also those erased by explosions again)
    std::vector<Crack> m_cracks;
    std::vector<Spark> m_sparks;

    bool m_sparksEnabled = true;
    bool m_fadingOut = false, m_hardFading = false, m_fadingIn = false;
    bool m_needsClear = true, m_themeRequest = false, m_switchTheme = true;
    int m_resetCounter = 0;
    qint64 m_fadeStart = 0, m_fadeInStart = 0, m_lastFadeStep = 0;
    uint64_t m_rng = 0x9E3779B97F4A7C15ull;
};
