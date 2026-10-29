#include "themestore.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QDesktopServices>
#include <QColor>
#include <algorithm>
#include <cmath>
#include <QFileInfo>
#include <QGuiApplication>
#include <QPalette>
#include <QProcess>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSettings>
#include <QStandardPaths>

ThemeStore::ThemeStore(QObject *parent)
    : QObject(parent)
    , m_userDir(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
                + QStringLiteral("/substrate-wallpaper/themes"))
{
    QSettings settings(m_userDir + QStringLiteral("/../settings.ini"), QSettings::IniFormat);
    m_hideBuiltin = settings.value(QStringLiteral("hideBuiltin"), false).toBool();

    // Editors save in several steps, so changes on disk are collected briefly before reloading
    m_reloadTimer.setSingleShot(true);
    m_reloadTimer.setInterval(200);
    connect(&m_reloadTimer, &QTimer::timeout, this, &ThemeStore::reload);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, &m_reloadTimer, qOverload<>(&QTimer::start));
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, &m_reloadTimer, qOverload<>(&QTimer::start));
    // Themes of the "system" collection follow the Plasma color scheme
    if (auto *app = qobject_cast<QGuiApplication *>(QCoreApplication::instance())) app->installEventFilter(this);
    reload();
}

bool ThemeStore::eventFilter(QObject *watched, QEvent *event)
{
    if (event->type() == QEvent::ApplicationPaletteChange && watched == QCoreApplication::instance())
        m_reloadTimer.start();
    return QObject::eventFilter(watched, event);
}

void ThemeStore::setBuiltinDir(const QUrl &dir)
{
    if (dir == m_builtinDir) return;
    m_builtinDir = dir;
    emit builtinDirChanged();
    reload();
}

void ThemeStore::setHideBuiltin(bool hide)
{
    if (hide == m_hideBuiltin) return;
    m_hideBuiltin = hide;
    QDir().mkpath(m_userDir);
    QSettings settings(m_userDir + QStringLiteral("/../settings.ini"), QSettings::IniFormat);
    settings.setValue(QStringLiteral("hideBuiltin"), hide);
    emit hideBuiltinChanged();
    reload();
}

QStringList ThemeStore::collapsedCollections(const QString &list) const
{
    QSettings settings(m_userDir + QStringLiteral("/../settings.ini"), QSettings::IniFormat);
    return settings.value(QStringLiteral("collapsed/") + list).toStringList();
}

void ThemeStore::setCollapsedCollections(const QString &list, const QStringList &collections)
{
    QDir().mkpath(m_userDir);
    QSettings settings(m_userDir + QStringLiteral("/../settings.ini"), QSettings::IniFormat);
    settings.setValue(QStringLiteral("collapsed/") + list, collections);
}

// A collection belongs to a built-in one if its first path segment is a built-in collection
bool ThemeStore::isBuiltinCollection(const QString &name) const
{
    const QString top = name.trimmed().section('/', 0, 0);
    return m_builtinCollections.contains(top);
}

bool ThemeStore::canStore(const QString &collection, const QString &name) const
{
    const QString key = collection.trimmed() + '/' + name.trimmed();
    if (m_systemKeys.contains(key)) return false;
    if (!isBuiltinCollection(collection)) return true;
    return m_builtinKeys.contains(key);
}

void ThemeStore::setError(const QString &e)
{
    m_lastError = e;
    emit lastErrorChanged();
}

bool ThemeStore::isValidName(const QString &name) const
{
    static const QRegularExpression bad(QStringLiteral(R"([/\\:*?"<>|\x00-\x1f])"));
    const QString n = name.trimmed();
    return !n.isEmpty() && n != QLatin1String(".") && n != QLatin1String("..") && !n.startsWith('.')
        && !n.contains(bad) && n.size() <= 100;
}

bool ThemeStore::validPath(const QString &path) const
{
    const QStringList parts = path.trimmed().split('/');
    if (parts.isEmpty() || parts.size() > 8) return false;
    for (const QString &p : parts)
        if (!isValidName(p)) return false;
    return true;
}

QVariantMap ThemeStore::parseThemeFile(const QString &path, QString *error)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) {
        if (error) *error = f.errorString();
        return {};
    }
    QString text = QString::fromUtf8(f.readAll());

    if (path.endsWith(QLatin1String(".js"), Qt::CaseInsensitive)) {
        // Turn the JavaScript object literal of the original theme files into JSON
        text.remove(QRegularExpression(QStringLiteral(R"(/\*.*?\*/)"), QRegularExpression::DotMatchesEverythingOption));
        text.remove(QRegularExpression(QStringLiteral(R"((?<![:"'])//[^\n]*)")));
        const int start = text.indexOf('{'), end = text.lastIndexOf('}');
        if (start < 0 || end <= start) {
            if (error) *error = QStringLiteral("No object found");
            return {};
        }
        text = text.mid(start, end - start + 1);
        text.replace(QRegularExpression(QStringLiteral(R"(([{,]\s*)([A-Za-z_][A-Za-z0-9_]*)\s*:)")),
                     QStringLiteral(R"(\1"\2":)"));
        text.replace('\'', '"');
        text.replace(QRegularExpression(QStringLiteral(R"(,(\s*[}\]]))")), QStringLiteral(R"(\1)"));
    }

    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(text.toUtf8(), &err);
    if (!doc.isObject()) {
        if (error) *error = err.errorString();
        return {};
    }
    return doc.object().toVariantMap();
}

void ThemeStore::scanDir(const QString &root, const QString &relative, bool builtin, Scan &out) const
{
    const QDir dir(relative.isEmpty() ? root : root + '/' + relative);
    if (!relative.isEmpty()) out.collections.insert(relative);

    for (const QFileInfo &fi : dir.entryInfoList({QStringLiteral("*.json"), QStringLiteral("*.js")}, QDir::Files, QDir::Name)) {
        if (relative.isEmpty()) continue; // files outside of a collection are ignored
        const QString name = fi.completeBaseName();
        // An empty file is fine (a theme that inherits everything), only unreadable ones are skipped
        QString error;
        const QVariantMap content = parseThemeFile(fi.absoluteFilePath(), &error);
        if (!error.isEmpty()) continue;
        if (fi.fileName() == QLatin1String("_collection.json")) {
            out.defaults[relative] = content;
            continue;
        }
        if (name.startsWith('_')) continue;
        const QString key = relative + '/' + name;
        QVariantMap t;
        t[QStringLiteral("key")] = key;
        t[QStringLiteral("collection")] = relative;
        t[QStringLiteral("name")] = name;
        t[QStringLiteral("builtin")] = builtin;
        t[QStringLiteral("overridesBuiltin")] = !builtin && m_builtinKeys.contains(key);
        t[QStringLiteral("path")] = fi.absoluteFilePath();
        t[QStringLiteral("own")] = content;
        out.themes[key] = t;
    }
    for (const QString &sub : dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name))
        scanDir(root, relative.isEmpty() ? sub : relative + '/' + sub, builtin, out);
}

// Colors derived from the accent color of the current Plasma color scheme
void ThemeStore::addSystemThemes(QMap<QString, QVariantMap> &out)
{
    const QPalette palette = QGuiApplication::palette();
    const QColor accent = palette.color(QPalette::Highlight);
    const QColor window = palette.color(QPalette::Window);

    auto rgb = [](const QColor &c) { return QVariantList{c.red(), c.green(), c.blue()}; };
    // Hue neighbours of the accent, lightness kept readable on the ground color
    auto palette6 = [&](bool darkGround) {
        QVariantList colors;
        const int hueShift[6] = {0, 25, -25, 50, -50, 0};
        for (int i = 0; i < 6; ++i) {
            float h, s, l, a;
            accent.getHslF(&h, &s, &l, &a);
            h = std::fmod(h * 360.0f + hueShift[i] + 360.0f, 360.0f) / 360.0f;
            s = std::max(s, 0.55f);
            l = darkGround ? std::max(l, 0.58f) : std::min(l, 0.42f);
            if (i == 5) l = darkGround ? std::min(l + 0.15f, 0.85f) : std::max(l - 0.12f, 0.2f);
            colors.push_back(rgb(QColor::fromHslF(h, s, l)));
        }
        return colors;
    };

    struct Def { const char *name; QColor ground; bool dark; };
    const Def defs[] = {
        {"Accent", window, window.lightnessF() < 0.5},
        {"Accent black", QColor(Qt::black), true},
        {"Accent white", QColor(Qt::white), false},
    };
    for (const Def &d : defs) {
        const QString key = QStringLiteral("system/") + QLatin1String(d.name);
        QVariantMap config;
        config[QStringLiteral("BG_COLOR")] = rgb(d.ground);
        config[QStringLiteral("COLORS")] = palette6(d.dark);
        QVariantMap t;
        t[QStringLiteral("key")] = key;
        t[QStringLiteral("collection")] = QStringLiteral("system");
        t[QStringLiteral("name")] = QLatin1String(d.name);
        t[QStringLiteral("builtin")] = true;
        t[QStringLiteral("overridesBuiltin")] = false;
        t[QStringLiteral("path")] = QString();
        t[QStringLiteral("own")] = config;
        out[key] = t;
        m_systemKeys.insert(key);
    }
}

QVariantMap ThemeStore::defaultsOf(const QString &collection) const
{
    return m_defaults.value(collection);
}

QVariantMap ThemeStore::inheritedFor(const QString &collection, bool includeSelf) const
{
    QVariantMap values, sources;
    const QStringList parts = collection.trimmed().split('/', Qt::SkipEmptyParts);
    QString path;
    for (int i = 0; i < parts.size(); ++i) {
        path = i == 0 ? parts[0] : path + '/' + parts[i];
        if (i == parts.size() - 1 && !includeSelf) break;
        const QVariantMap d = defaultsOf(path);
        for (auto it = d.cbegin(); it != d.cend(); ++it) {
            values[it.key()] = it.value();
            sources[it.key()] = path;
        }
    }
    QVariantMap result;
    result[QStringLiteral("values")] = values;
    result[QStringLiteral("sources")] = sources;
    return result;
}

QVariantMap ThemeStore::rebase(const QVariantMap &config, const QString &collection) const
{
    const QVariantMap inherited = inheritedFor(collection, true).value(QStringLiteral("values")).toMap();
    QVariantMap own;
    for (auto it = config.cbegin(); it != config.cend(); ++it)
        if (!inherited.contains(it.key()) || inherited.value(it.key()) != it.value()) own[it.key()] = it.value();
    return own;
}

void ThemeStore::reload()
{
    m_builtinKeys.clear();
    m_builtinCollections.clear();
    m_systemKeys.clear();

    Scan builtin, user;
    if (m_builtinDir.isValid()) {
        const QString root = m_builtinDir.toLocalFile();
        for (const QString &c : QDir(root).entryList(QDir::Dirs | QDir::NoDotAndDotDot)) m_builtinCollections.insert(c);
        scanDir(root, QString(), true, builtin);
    }
    for (auto it = builtin.themes.cbegin(); it != builtin.themes.cend(); ++it) m_builtinKeys.insert(it.key());
    QMap<QString, QVariantMap> systemThemes;
    addSystemThemes(systemThemes);
    m_builtinCollections.insert(QStringLiteral("system"));
    for (auto it = systemThemes.cbegin(); it != systemThemes.cend(); ++it) m_builtinKeys.insert(it.key());
    scanDir(m_userDir, QString(), false, user);

    // Defaults as they apply: a user file replaces the built-in one of the same collection
    m_defaults = builtin.defaults;
    m_builtinDefaultCollections = QSet<QString>(builtin.defaults.keyBegin(), builtin.defaults.keyEnd());
    m_userDefaultCollections = QSet<QString>(user.defaults.keyBegin(), user.defaults.keyEnd());
    for (auto it = user.defaults.cbegin(); it != user.defaults.cend(); ++it) m_defaults[it.key()] = it.value();

    // Themes: built-in first (unless hidden), user themes replace built-in ones of the same key
    QMap<QString, QVariantMap> all;
    if (!m_hideBuiltin) all = builtin.themes;
    if (!m_hideBuiltin) all.insert(systemThemes);
    for (auto it = user.themes.cbegin(); it != user.themes.cend(); ++it) all[it.key()] = it.value();

    QVariantList themes;
    QSet<QString> collectionSet = user.collections;
    for (QVariantMap t : std::as_const(all)) {
        const QString collection = t.value("collection").toString();
        const QVariantMap inherited = collection == QLatin1String("system")
            ? QVariantMap() : inheritedFor(collection, true).value(QStringLiteral("values")).toMap();
        QVariantMap config = inherited;
        const QVariantMap own = t.value("own").toMap();
        for (auto it = own.cbegin(); it != own.cend(); ++it) config[it.key()] = it.value();
        t[QStringLiteral("config")] = config;
        themes.push_back(t);
        collectionSet.insert(collection);
    }
    // Every collection brings its parents along
    const QSet<QString> direct = collectionSet;
    for (const QString &c : direct) {
        QString path;
        for (const QString &part : c.split('/')) {
            path = path.isEmpty() ? part : path + '/' + part;
            collectionSet.insert(path);
        }
    }
    QStringList collections(collectionSet.cbegin(), collectionSet.cend());
    // Tree order: compare segment by segment so a parent is followed by all of its children
    std::sort(collections.begin(), collections.end(), [](const QString &a, const QString &b) {
        const QStringList pa = a.split('/'), pb = b.split('/');
        for (int i = 0; i < std::min(pa.size(), pb.size()); ++i) {
            const int c = QString::compare(pa[i], pb[i], Qt::CaseInsensitive);
            if (c != 0) return c < 0;
        }
        return pa.size() < pb.size();
    });

    QVariantList collectionData;
    for (const QString &c : collections) {
        QVariantMap info;
        info[QStringLiteral("path")] = c;
        info[QStringLiteral("name")] = c.section('/', -1);
        info[QStringLiteral("depth")] = int(c.count('/'));
        info[QStringLiteral("builtin")] = isBuiltinCollection(c);
        info[QStringLiteral("system")] = c == QLatin1String("system") || c.startsWith(QLatin1String("system/"));
        info[QStringLiteral("hasUserDefaults")] = m_userDefaultCollections.contains(c);
        info[QStringLiteral("hasBuiltinDefaults")] = m_builtinDefaultCollections.contains(c);
        info[QStringLiteral("defaults")] = defaultsOf(c);
        collectionData.push_back(info);
    }

    updateWatcher();
    if (themes == m_themes && collections == m_collections && collectionData == m_collectionData) return;
    m_themes = themes;
    m_collections = collections;
    m_collectionData = collectionData;
    emit themesChanged();
}

void ThemeStore::updateWatcher()
{
    QStringList paths;
    QDir().mkpath(m_userDir);
    QDirIterator it(m_userDir, QDir::Dirs | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
    paths.push_back(m_userDir);
    while (it.hasNext()) paths.push_back(it.next());
    if (!m_watcher.directories().isEmpty()) m_watcher.removePaths(m_watcher.directories());
    m_watcher.addPaths(paths);
}

QVariantMap ThemeStore::theme(const QString &key) const
{
    for (const QVariant &v : m_themes)
        if (v.toMap().value("key").toString() == key) return v.toMap();
    return {};
}

QVariantMap ThemeStore::collectionInfo(const QString &path) const
{
    for (const QVariant &v : m_collectionData)
        if (v.toMap().value("path").toString() == path) return v.toMap();
    return {};
}

static bool writeJson(const QString &path, const QVariantMap &content, QString *error)
{
    QSaveFile f(path);
    if (!f.open(QIODevice::WriteOnly)) {
        *error = f.errorString();
        return false;
    }
    f.write(QJsonDocument(QJsonObject::fromVariantMap(content)).toJson(QJsonDocument::Indented));
    if (!f.commit()) {
        *error = f.errorString();
        return false;
    }
    return true;
}

bool ThemeStore::saveTheme(const QString &collection, const QString &name, const QVariantMap &own,
                           const QString &oldKey)
{
    if (!validPath(collection) || !isValidName(name)) {
        setError(tr("Invalid name: %1 / %2").arg(collection, name));
        return false;
    }
    if (!canStore(collection, name)) {
        setError(tr("The built-in collection \"%1\" takes no new themes, choose another collection").arg(collection.trimmed()));
        return false;
    }
    const QString dir = m_userDir + '/' + collection.trimmed();
    const QString base = dir + '/' + name.trimmed();
    if (!QDir().mkpath(dir)) {
        setError(tr("Cannot create folder %1").arg(dir));
        return false;
    }
    QString error;
    if (!writeJson(base + QStringLiteral(".json"), own, &error)) {
        setError(error);
        return false;
    }
    // An imported original .js of the same name would shadow nothing but confuse, the JSON replaces it
    QFile::remove(base + QStringLiteral(".js"));

    const QString newKey = collection.trimmed() + '/' + name.trimmed();
    if (!oldKey.isEmpty() && oldKey != newKey) {
        const QVariantMap old = theme(oldKey);
        if (!old.isEmpty() && !old.value("builtin").toBool()) QFile::remove(old.value("path").toString());
    }
    setError(QString());
    reload();
    return true;
}

bool ThemeStore::saveCollectionDefaults(const QString &collection, const QVariantMap &defaults)
{
    if (!validPath(collection) || collection.trimmed().section('/', 0, 0) == QLatin1String("system")) {
        setError(tr("The defaults of \"%1\" cannot be changed").arg(collection));
        return false;
    }
    const QString dir = m_userDir + '/' + collection.trimmed();
    if (!QDir().mkpath(dir)) {
        setError(tr("Cannot create folder %1").arg(dir));
        return false;
    }
    QString error;
    if (!writeJson(dir + QStringLiteral("/_collection.json"), defaults, &error)) {
        setError(error);
        return false;
    }
    setError(QString());
    reload();
    return true;
}

bool ThemeStore::deleteCollectionDefaults(const QString &collection)
{
    if (!validPath(collection)) return false;
    QFile::remove(m_userDir + '/' + collection.trimmed() + QStringLiteral("/_collection.json"));
    setError(QString());
    reload();
    return true;
}

bool ThemeStore::deleteTheme(const QString &key)
{
    const QVariantMap t = theme(key);
    if (t.isEmpty() || t.value("builtin").toBool()) {
        setError(tr("Built-in themes cannot be deleted"));
        return false;
    }
    if (!QFile::remove(t.value("path").toString())) {
        setError(tr("Cannot delete %1").arg(t.value("path").toString()));
        return false;
    }
    setError(QString());
    reload();
    return true;
}

bool ThemeStore::createCollection(const QString &path)
{
    if (!validPath(path)) {
        setError(tr("Invalid name: %1").arg(path));
        return false;
    }
    if (isBuiltinCollection(path)) {
        setError(tr("\"%1\" belongs to a built-in collection, which takes nothing new").arg(path.trimmed()));
        return false;
    }
    if (!QDir().mkpath(m_userDir + '/' + path.trimmed())) {
        setError(tr("Cannot create folder"));
        return false;
    }
    setError(QString());
    reload();
    return true;
}

bool ThemeStore::deleteCollection(const QString &path)
{
    if (!validPath(path)) return false;
    QDir dir(m_userDir + '/' + path.trimmed());
    if (!dir.exists()) {
        setError(tr("Only own collections can be deleted"));
        return false;
    }
    if (!dir.removeRecursively()) {
        setError(tr("Cannot delete %1").arg(dir.path()));
        return false;
    }
    setError(QString());
    reload();
    return true;
}

int ThemeStore::duplicateCollection(const QString &source, const QString &newPath)
{
    const QString target = newPath.trimmed();
    if (!validPath(target)) {
        setError(tr("Invalid name: %1").arg(newPath));
        return 0;
    }
    if (isBuiltinCollection(target)) {
        setError(tr("\"%1\" belongs to a built-in collection, which takes nothing new").arg(target));
        return 0;
    }
    if (target == source || target.startsWith(source + '/')) {
        setError(tr("A collection cannot be copied into itself"));
        return 0;
    }
    if (QDir(m_userDir + '/' + target).exists() && !QDir(m_userDir + '/' + target).isEmpty()) {
        setError(tr("The collection \"%1\" already exists").arg(target));
        return 0;
    }

    setError(QString());
    // What the source inherits from its parents becomes part of the copy's own defaults,
    // minus what the new parent hands down anyway
    QVariantMap rootDefaults = inheritedFor(source, false).value(QStringLiteral("values")).toMap();
    const QVariantMap own = defaultsOf(source);
    for (auto it = own.cbegin(); it != own.cend(); ++it) rootDefaults[it.key()] = it.value();
    const QString newParent = target.contains('/') ? target.section('/', 0, -2) : QString();
    const QVariantMap parentValues = newParent.isEmpty()
        ? QVariantMap() : inheritedFor(newParent, true).value(QStringLiteral("values")).toMap();
    QVariantMap rebased;
    for (auto it = rootDefaults.cbegin(); it != rootDefaults.cend(); ++it)
        if (!parentValues.contains(it.key()) || parentValues.value(it.key()) != it.value()) rebased[it.key()] = it.value();

    QString error;
    QDir().mkpath(m_userDir + '/' + target);
    if (!rebased.isEmpty() && !writeJson(m_userDir + '/' + target + QStringLiteral("/_collection.json"), rebased, &error)) {
        setError(error);
        return 0;
    }
    int count = 0;
    for (const QString &c : std::as_const(m_collections)) {
        if (c != source && !c.startsWith(source + '/')) continue;
        const QString copy = target + c.mid(source.size());
        QDir().mkpath(m_userDir + '/' + copy);
        if (c != source && m_defaults.contains(c)
            && !writeJson(m_userDir + '/' + copy + QStringLiteral("/_collection.json"), m_defaults.value(c), &error)) {
            setError(error);
            return count;
        }
    }
    for (const QVariant &v : std::as_const(m_themes)) {
        const QVariantMap t = v.toMap();
        const QString c = t.value("collection").toString();
        if (c != source && !c.startsWith(source + '/')) continue;
        const QString copy = target + c.mid(source.size());
        // The virtual system themes have no file: their whole config is written
        const QVariantMap content = c == QLatin1String("system") ? t.value("config").toMap() : t.value("own").toMap();
        if (!writeJson(m_userDir + '/' + copy + '/' + t.value("name").toString() + QStringLiteral(".json"), content, &error)) {
            setError(error);
            return count;
        }
        count++;
    }
    if (count == 0) setError(tr("The collection \"%1\" has no themes").arg(source));
    reload();
    return count;
}

bool ThemeStore::hasUserCollection(const QString &name) const
{
    return validPath(name) && QDir(m_userDir + '/' + name.trimmed()).exists();
}

bool ThemeStore::openFolder(const QString &collection)
{
    const QUrl url = folderUrl(collection);
    if (QDesktopServices::openUrl(url)) return true;
    if (QProcess::startDetached(QStringLiteral("xdg-open"), {url.toLocalFile()})) return true;
    setError(tr("Cannot open %1").arg(url.toLocalFile()));
    return false;
}

QUrl ThemeStore::folderUrl(const QString &collection) const
{
    QString path = m_userDir;
    if (!collection.isEmpty() && QDir(m_userDir + '/' + collection).exists()) path += '/' + collection;
    QDir().mkpath(path);
    return QUrl::fromLocalFile(path);
}
