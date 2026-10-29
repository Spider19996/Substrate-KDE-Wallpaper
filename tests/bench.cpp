// Headless benchmark: runs the engine for N frames and stores a snapshot.
#include "../src/substrateengine.h"

#include <QElapsedTimer>
#include <QGuiApplication>
#include <cstdio>

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    const int w = argc > 1 ? atoi(argv[1]) : 1920, h = argc > 2 ? atoi(argv[2]) : 1080;
    const int frames = argc > 3 ? atoi(argv[3]) : 600;

    SubstrateConfig cfg;
    cfg.colors = {qRgb(255, 50, 50), qRgb(50, 255, 50), qRgb(50, 50, 255), qRgb(255, 255, 0)};
    SubstrateEngine e;
    e.setConfig(cfg);
    e.resize(w, h);
    QImage img(w, h, QImage::Format_RGB32);

    QElapsedTimer t;
    t.start();
    for (int i = 0; i < frames; i++) e.step(img);
    const double ms = t.nsecsElapsed() / 1e6 / frames;
    printf("%dx%d: %.3f ms/frame, sparks=%zu\n", w, h, ms, e.sparks().size());
    img.save(argc > 4 ? argv[4] : "bench.png");
}
