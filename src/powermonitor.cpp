#include "powermonitor.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusVariant>

PowerMonitor::PowerMonitor(QObject *parent)
    : QObject(parent)
{
    // Both buses may be missing (no UPower, no screen saver service): the state then stays "mains, unlocked"
    QDBusConnection system = QDBusConnection::systemBus();
    if (system.isConnected()) {
        QDBusInterface upower(QStringLiteral("org.freedesktop.UPower"), QStringLiteral("/org/freedesktop/UPower"),
                              QStringLiteral("org.freedesktop.DBus.Properties"), system);
        if (upower.isValid()) {
            const QDBusReply<QDBusVariant> reply = upower.call(
                QStringLiteral("Get"), QStringLiteral("org.freedesktop.UPower"), QStringLiteral("OnBattery"));
            if (reply.isValid()) m_onBattery = reply.value().variant().toBool();
        }
        system.connect(QStringLiteral("org.freedesktop.UPower"), QStringLiteral("/org/freedesktop/UPower"),
                       QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("PropertiesChanged"), this,
                       SLOT(upowerChanged(QString, QVariantMap, QStringList)));
    }

    QDBusConnection session = QDBusConnection::sessionBus();
    if (session.isConnected()) {
        QDBusInterface saver(QStringLiteral("org.freedesktop.ScreenSaver"), QStringLiteral("/ScreenSaver"),
                             QStringLiteral("org.freedesktop.ScreenSaver"), session);
        if (saver.isValid()) {
            const QDBusReply<bool> reply = saver.call(QStringLiteral("GetActive"));
            if (reply.isValid()) m_screenLocked = reply.value();
        }
        // KDE emits the signal on /ScreenSaver, other desktops on the long path: listen on any path
        session.connect(QStringLiteral("org.freedesktop.ScreenSaver"), QString(),
                        QStringLiteral("org.freedesktop.ScreenSaver"), QStringLiteral("ActiveChanged"), this,
                        SLOT(screenSaverActiveChanged(bool)));
    }
}

void PowerMonitor::upowerChanged(const QString &interface, const QVariantMap &changed, const QStringList &)
{
    if (interface != QLatin1String("org.freedesktop.UPower") || !changed.contains(QStringLiteral("OnBattery"))) return;
    const bool on = changed.value(QStringLiteral("OnBattery")).toBool();
    if (on == m_onBattery) return;
    m_onBattery = on;
    emit onBatteryChanged();
}

void PowerMonitor::screenSaverActiveChanged(bool active)
{
    if (active == m_screenLocked) return;
    m_screenLocked = active;
    emit screenLockedChanged();
}
