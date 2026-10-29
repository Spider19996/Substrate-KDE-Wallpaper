#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QSet>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include <qqmlintegration.h>

// Theme files on disk: built-in themes from the wallpaper package (read-only) and
// user themes in ~/.local/share/substrate-wallpaper/themes/<collection>/<name>.json.
// A user theme with the same collection and name replaces the built-in one.
//
// Collections can be nested ("oled/dark/blue") and hand down defaults: a collection folder may contain
// "_collection.json" with settings that every theme in it and in its subcollections inherits.
// A theme file only needs the settings that differ from that; the resolved result is "config".
// Theme files are the CONFIG object of the HTML original, either as JSON or as the original .js file.
class ThemeStore : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QUrl builtinDir READ builtinDir WRITE setBuiltinDir NOTIFY builtinDirChanged)
    Q_PROPERTY(QString userDir READ userDir CONSTANT)
    // Version of this build, shown on the settings page
    Q_PROPERTY(QString version READ version CONSTANT)
    // [{ key: "a/b/name", collection: "a/b", name, builtin, overridesBuiltin, path,
    //    own (settings of the theme file), config (own on top of everything inherited) }]
    Q_PROPERTY(QVariantList themes READ themes NOTIFY themesChanged)
    // All collection paths ("a", "a/b"), parents before their children
    Q_PROPERTY(QStringList collections READ collections NOTIFY themesChanged)
    // [{ path, name, depth, builtin, system, hasUserDefaults, hasBuiltinDefaults, defaults }]
    Q_PROPERTY(QVariantList collectionData READ collectionData NOTIFY themesChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    // Hides the built-in themes everywhere; own themes (also modified copies of built-in ones) stay.
    // Stored in ~/.local/share/substrate-wallpaper/settings.ini, so it is shared by all screens.
    Q_PROPERTY(bool hideBuiltin READ hideBuiltin WRITE setHideBuiltin NOTIFY hideBuiltinChanged)

public:
    explicit ThemeStore(QObject *parent = nullptr);

    QUrl builtinDir() const { return m_builtinDir; }
    void setBuiltinDir(const QUrl &dir);
    QString userDir() const { return m_userDir; }
#ifdef SUBSTRATE_VERSION
    QString version() const { return QStringLiteral(SUBSTRATE_VERSION); }
#else
    QString version() const { return QStringLiteral("dev"); }
#endif
    QVariantList themes() const { return m_themes; }
    QStringList collections() const { return m_collections; }
    QVariantList collectionData() const { return m_collectionData; }
    QString lastError() const { return m_lastError; }
    bool hideBuiltin() const { return m_hideBuiltin; }
    void setHideBuiltin(bool hide);

    Q_INVOKABLE QVariantMap theme(const QString &key) const;
    Q_INVOKABLE QVariantMap collectionInfo(const QString &path) const;
    // What a theme of this collection inherits: { values, sources }. sources maps every setting to the
    // collection that sets it. With includeSelf = false the collection's own defaults are left out
    // (what the collection itself inherits from its parents).
    Q_INVOKABLE QVariantMap inheritedFor(const QString &collection, bool includeSelf = true) const;
    // The settings of config that differ from what the collection hands down
    Q_INVOKABLE QVariantMap rebase(const QVariantMap &config, const QString &collection) const;
    // Writes a user theme with only the given settings; oldKey is removed afterwards if it was
    // a different user theme (rename/move)
    Q_INVOKABLE bool saveTheme(const QString &collection, const QString &name, const QVariantMap &own,
                               const QString &oldKey = QString());
    // Writes the defaults of a collection, deleteCollectionDefaults removes the user's file again
    Q_INVOKABLE bool saveCollectionDefaults(const QString &collection, const QVariantMap &defaults);
    Q_INVOKABLE bool deleteCollectionDefaults(const QString &collection);
    // Removes the user file; a built-in theme behind it becomes visible again
    Q_INVOKABLE bool deleteTheme(const QString &key);
    // Collection paths may be nested ("a/b"); missing parents are created
    Q_INVOKABLE bool createCollection(const QString &path);
    // Removes the user folder of a collection including its themes and subcollections
    Q_INVOKABLE bool deleteCollection(const QString &path);
    // Copies a collection with its defaults, themes and subcollections (built-in ones too) to a new path of
    // your own, returns the number of copied themes
    Q_INVOKABLE int duplicateCollection(const QString &source, const QString &newPath);
    // True if the collection has a folder in the user theme directory
    Q_INVOKABLE bool hasUserCollection(const QString &name) const;
    Q_INVOKABLE QUrl folderUrl(const QString &collection = QString()) const;
    // Which collections are folded in a list ("selector", "manager"), remembered between sessions
    Q_INVOKABLE QStringList collapsedCollections(const QString &list) const;
    Q_INVOKABLE void setCollapsedCollections(const QString &list, const QStringList &collections);
    // Shows the theme folder (of a collection) in the file manager
    Q_INVOKABLE bool openFolder(const QString &collection = QString());
    Q_INVOKABLE bool isValidName(const QString &name) const;
    // A collection path like "a/b/c": every part is a valid name
    Q_INVOKABLE bool isValidPath(const QString &path) const { return validPath(path); }
    // Built-in collections (folders of the package) only take changes to their own themes, nothing new
    Q_INVOKABLE bool isBuiltinCollection(const QString &name) const;
    // False if saving collection/name would add a new theme to a built-in collection
    Q_INVOKABLE bool canStore(const QString &collection, const QString &name) const;
    Q_INVOKABLE void reload();

    // Parses a theme file (JSON or the original "const CONFIG = {...};" JavaScript)
    static QVariantMap parseThemeFile(const QString &path, QString *error = nullptr);

signals:
    void builtinDirChanged();
    void themesChanged();
    void lastErrorChanged();
    void hideBuiltinChanged();

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    void setError(const QString &e);
    struct Scan {
        QMap<QString, QVariantMap> themes;
        QMap<QString, QVariantMap> defaults; // collection -> _collection.json
        QSet<QString> collections;
    };
    void scanDir(const QString &root, const QString &relative, bool builtin, Scan &out) const;
    QVariantMap defaultsOf(const QString &collection) const;
    bool validPath(const QString &path) const;
    void updateWatcher();
    void addSystemThemes(QMap<QString, QVariantMap> &out);

    QUrl m_builtinDir;
    QString m_userDir;
    QVariantList m_themes;
    QStringList m_collections;
    QVariantList m_collectionData;
    // Defaults per collection as they apply (a user file replaces the built-in one)
    QMap<QString, QVariantMap> m_defaults;
    QSet<QString> m_builtinDefaultCollections, m_userDefaultCollections;
    QString m_lastError;
    bool m_hideBuiltin = false;
    QSet<QString> m_builtinKeys;
    QSet<QString> m_builtinCollections;
    QSet<QString> m_systemKeys;
    QFileSystemWatcher m_watcher;
    QTimer m_reloadTimer;
};
