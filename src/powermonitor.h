#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantMap>
#include <qqmlintegration.h>

// Power state for pausing the wallpaper: running on battery (UPower) and a locked screen
class PowerMonitor : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool onBattery READ onBattery NOTIFY onBatteryChanged)
    Q_PROPERTY(bool screenLocked READ screenLocked NOTIFY screenLockedChanged)

public:
    explicit PowerMonitor(QObject *parent = nullptr);

    bool onBattery() const { return m_onBattery; }
    bool screenLocked() const { return m_screenLocked; }

signals:
    void onBatteryChanged();
    void screenLockedChanged();

private slots:
    void upowerChanged(const QString &interface, const QVariantMap &changed, const QStringList &);
    void screenSaverActiveChanged(bool active);

private:
    bool m_onBattery = false;
    bool m_screenLocked = false;
};
