// SPDX-FileCopyrightText: 2023 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

#include "desktopintegration.h"

#include <DConfig>
#include <DDBusSender>
#include <DDesktopEntry>
#include <DStandardPaths>
#include <DDesktopServices>
#include <DDialog>
#include <DMenu>
#include <QAction>
#include <QApplication>
#include <QCursor>
#include <QMenu>
#include <QPixmap>
#include <QRect>
#include <QGuiApplication>
#include <QLoggingCategory>
#include <QScreen>
#include <QWindow>
#include <appinfo.h>
#include <appmgr.h>
#include <appsmodel.h>

#include <algorithm>

#include <AppStreamQt/pool.h>

#include "appwiz.h"
#include "ddedock.h"
#include "appearance.h"
#include "iconutils.h"

DCORE_USE_NAMESPACE
DWIDGET_USE_NAMESPACE

namespace {
Q_LOGGING_CATEGORY(logDesktopIntegration, "org.deepin.dde.launchpad.desktop")

constexpr char kTaskManagerDConfigAppId[] = "org.deepin.dde.shell";
constexpr char kTaskManagerDConfigName[] = "org.deepin.ds.dock.taskmanager";
constexpr char kDockedElementsKey[] = "dockedElements";

bool isLauncherFolderId(const QString &desktopId)
{
    return desktopId.startsWith(QStringLiteral("internal/folder/")) ||
           desktopId.startsWith(QStringLiteral("internal/folders/")) ||
           desktopId.startsWith(QStringLiteral("internal/group/"));
}

QString launcherFolderSuffix(const QString &desktopId)
{
    if (!isLauncherFolderId(desktopId)) {
        return {};
    }

    return desktopId.section(QLatin1Char('/'), -1);
}

QStringList launcherFolderDockElementCandidates(const QString &desktopId)
{
    const QString suffix = launcherFolderSuffix(desktopId);
    if (suffix.isEmpty() || suffix == QLatin1String("0")) {
        return {};
    }

    QStringList candidates;
    const auto appendUnique = [&candidates](const QString &element) {
        if (!element.isEmpty() && !candidates.contains(element)) {
            candidates.append(element);
        }
    };

    appendUnique(QStringLiteral("group/%1").arg(desktopId));
    appendUnique(QStringLiteral("group/internal/folders/%1").arg(suffix));
    appendUnique(QStringLiteral("group/internal/folder/%1").arg(suffix));
    appendUnique(QStringLiteral("group/internal/group/%1").arg(suffix));
    appendUnique(QStringLiteral("group/%1").arg(suffix));
    return candidates;
}

QStringList dockedElementsFromTaskManagerConfig(DConfig *config)
{
    if (!config || !config->isValid()) {
        return {};
    }

    return config->value(QString::fromLatin1(kDockedElementsKey), {}).toStringList();
}

void appendStandardContextMenuItems(QMenu *menu, const QVariantList &items)
{
    for (const QVariant &item : items) {
        const QVariantMap itemMap = item.toMap();
        if (!itemMap.value(QStringLiteral("visible"), true).toBool()) {
            continue;
        }

        if (itemMap.value(QStringLiteral("separator")).toBool()) {
            menu->addSeparator();
            continue;
        }

        const QString text = itemMap.value(QStringLiteral("text")).toString();
        const QVariantList childItems = itemMap.value(QStringLiteral("items")).toList();
        if (!childItems.isEmpty()) {
            auto *subMenu = new DMenu(menu);
            subMenu->setTitle(text);
            appendStandardContextMenuItems(subMenu, childItems);
            if (subMenu->actions().isEmpty()) {
                delete subMenu;
                continue;
            }

            QAction *menuAction = menu->addMenu(subMenu);
            menuAction->setEnabled(itemMap.value(QStringLiteral("enabled"), true).toBool());
            continue;
        }

        QAction *action = menu->addAction(text);
        action->setData(itemMap.value(QStringLiteral("command")).toString());
        action->setEnabled(itemMap.value(QStringLiteral("enabled"), true).toBool());

        if (itemMap.value(QStringLiteral("checkable")).toBool()) {
            action->setCheckable(true);
            action->setChecked(itemMap.value(QStringLiteral("checked")).toBool());
        }
    }
}
}

QString DesktopIntegration::currentDE()
{
    return qEnvironmentVariable("XDG_CURRENT_DESKTOP", QStringLiteral("DDE")).split(':').constFirst();
}

bool DesktopIntegration::isTreeLand()
{
    return QGuiApplication::platformName() == "wayland";
}

void DesktopIntegration::openSystemSettings()
{
    DDBusSender()
        .service("org.deepin.dde.ControlCenter1")
        .interface("org.deepin.dde.ControlCenter1")
        .path("/org/deepin/dde/ControlCenter1")
        .method(QString("Show"))
        .call();
}

void DesktopIntegration::launchByDesktopId(const QString &desktopId)
{
    qCInfo(logDesktopIntegration) << "Launching app by desktop ID:" << desktopId;
    if (!AppMgr::launchApp(desktopId)) {
        qCDebug(logDesktopIntegration) << "AppMgr launch failed, trying AppInfo launch";
        AppInfo::launchByDesktopId(desktopId);
    }
}

QString DesktopIntegration::environmentVariable(const QString &env)
{
    return qEnvironmentVariable(env.toStdString().c_str());
}

double DesktopIntegration::disableScale(const QString &desktopId)
{
    return AppMgr::disableScale(desktopId);
}

void DesktopIntegration::setDisableScale(const QString &desktopId, double disableScale)
{
    return AppMgr::setDisableScale(desktopId, disableScale);
}

void DesktopIntegration::showFolder(QStandardPaths::StandardLocation location)
{
    QStringList paths(QStandardPaths::standardLocations(location));
    if (!paths.isEmpty()) {
        Dtk::Gui::DDesktopServices::showFolder(paths.constFirst());
    }
}

void DesktopIntegration::showUrl(const QString &url)
{
    Dtk::Gui::DDesktopServices::showFolder(QUrl(url));
}

bool DesktopIntegration::appIsCompulsoryForDesktop(const QString &desktopId)
{
    if (m_compulsoryAppIdList.contains(desktopId)) return true;

#ifdef NO_APPSTREAM_QT
    Q_UNUSED(desktopId)
#else
    const QString currentDE(DesktopIntegration::currentDE());

    AppStream::Pool pool;
    // qDebug() << pool.flags() << currentDE;
    pool.load();

    const AppStream::ComponentBox components = pool.componentsByLaunchable(AppStream::Launchable::KindDesktopId, desktopId);
    for (const AppStream::Component & component : components) {
        return component.compulsoryForDesktops().contains(currentDE);
    }
#endif

    return false;
}

bool DesktopIntegration::appIsDummyPackage(const QString &desktopId)
{
#ifdef NO_APPSTREAM_QT
    Q_UNUSED(desktopId)
#else
    AppStream::Pool pool;
    // qDebug() << pool.flags();
    pool.load();

    const AppStream::ComponentBox components = pool.componentsByLaunchable(AppStream::Launchable::KindDesktopId, desktopId);
    for (const AppStream::Component & component : components) {
        return component.customValue("DDE::is_dummy_package") == "true";
    }
#endif

    return false;
}

Qt::ArrowType DesktopIntegration::dockPosition() const
{
    return m_dockIntegration->direction();
}

// If position (x, y) is unknown, it's okay to return -1 as position value.
QRect DesktopIntegration::dockGeometry() const
{
    return m_dockIntegration->geometry();
}

uint DesktopIntegration::dockSpacing() const
{
    return 10;
}

QString DesktopIntegration::backgroundUrl() const
{
    return QString("image://blurhash/%1").arg(m_appearanceIntegration->wallpaperBlurhash());
}

QString DesktopIntegration::wallpaperUrl() const
{
    return m_appearanceIntegration->wallpaperUrl();
}

bool DesktopIntegration::isDockedApp(const QString &desktopId) const
{
    if (isLauncherFolderId(desktopId)) {
        QScopedPointer<DConfig> config(DConfig::create(QString::fromLatin1(kTaskManagerDConfigAppId),
                                                       QString::fromLatin1(kTaskManagerDConfigName)));
        const QStringList dockedElements = dockedElementsFromTaskManagerConfig(config.data());
        for (const QString &candidate : launcherFolderDockElementCandidates(desktopId)) {
            if (dockedElements.contains(candidate)) {
                return true;
            }
        }

        return false;
    }

    // This is something we shouldn't do but anyway...
    const QString & fullPath = AppInfo::fullPathByDesktopId(desktopId);
    // Seems QML's list type doesn't have a contains() method...
    return m_dockIntegration->isDocked(fullPath);
}

void DesktopIntegration::sendToDock(const QString &desktopId)
{
    if (isLauncherFolderId(desktopId)) {
        QScopedPointer<DConfig> config(DConfig::create(QString::fromLatin1(kTaskManagerDConfigAppId),
                                                       QString::fromLatin1(kTaskManagerDConfigName)));
        QStringList dockedElements = dockedElementsFromTaskManagerConfig(config.data());
        const QStringList candidates = launcherFolderDockElementCandidates(desktopId);
        for (const QString &candidate : candidates) {
            if (dockedElements.contains(candidate)) {
                qCInfo(logDesktopIntegration) << "Launcher folder already docked:" << desktopId << candidate;
                return;
            }
        }

        if (config && config->isValid() && !candidates.isEmpty()) {
            dockedElements.append(candidates.constFirst());
            config->setValue(QString::fromLatin1(kDockedElementsKey), dockedElements);
            qCInfo(logDesktopIntegration) << "Docked launcher folder:" << desktopId << candidates.constFirst();
        } else {
            qCWarning(logDesktopIntegration) << "Cannot dock launcher folder due to invalid taskmanager config:" << desktopId;
        }
        return;
    }

    qCInfo(logDesktopIntegration) << "Sending app to dock:" << desktopId;
    const QString & fullPath = AppInfo::fullPathByDesktopId(desktopId);
    return m_dockIntegration->sendToDock(fullPath);
}

void DesktopIntegration::removeFromDock(const QString &desktopId)
{
    if (isLauncherFolderId(desktopId)) {
        QScopedPointer<DConfig> config(DConfig::create(QString::fromLatin1(kTaskManagerDConfigAppId),
                                                       QString::fromLatin1(kTaskManagerDConfigName)));
        QStringList dockedElements = dockedElementsFromTaskManagerConfig(config.data());
        const QStringList candidates = launcherFolderDockElementCandidates(desktopId);
        bool changed = false;
        for (const QString &candidate : candidates) {
            const int removed = dockedElements.removeAll(candidate);
            changed = changed || removed > 0;
        }

        if (config && config->isValid() && changed) {
            config->setValue(QString::fromLatin1(kDockedElementsKey), dockedElements);
            qCInfo(logDesktopIntegration) << "Undocked launcher folder:" << desktopId;
        } else if (!config || !config->isValid()) {
            qCWarning(logDesktopIntegration) << "Cannot undock launcher folder due to invalid taskmanager config:" << desktopId;
        }
        return;
    }

    qCInfo(logDesktopIntegration) << "Removing app from dock:" << desktopId;
    const QString & fullPath = AppInfo::fullPathByDesktopId(desktopId);
    return m_dockIntegration->removeFromDock(fullPath);
}

inline QString desktopItemFilePath(const QString &desktopId)
{
    QString desktopPath = QStandardPaths::writableLocation(QStandardPaths::DesktopLocation);
    if (desktopPath.isEmpty()) return QString();

    QDir desktopDir(desktopPath);
    return desktopDir.filePath(desktopId);
}

bool DesktopIntegration::isOnDesktop(const QString &desktopId) const
{
    QString desktopItemPath = desktopItemFilePath(desktopId);
    if (desktopItemPath.isEmpty()) return false;
    return QFileInfo::exists(desktopItemPath);
}

void DesktopIntegration::sendToDesktop(const QString &desktopId)
{
    if (AppMgr::sendToDesktop(desktopId)) {
        Dtk::Gui::DDesktopServices::playSystemSoundEffect(Dtk::Gui::DDesktopServices::SSE_SendFileComplete);
    }
}

void DesktopIntegration::removeFromDesktop(const QString &desktopId)
{
    AppMgr::removeFromDesktop(desktopId);
}

bool DesktopIntegration::isAutoStart(const QString &desktopId) const
{
    return AppMgr::autoStart(desktopId);
}

// only affect the one in XDG_CONFIG_HOME, don't care about the system one (even if there is one).
void DesktopIntegration::setAutoStart(const QString &desktopId, bool on)
{
    return AppMgr::setAutoStart(desktopId, on);
}

bool DesktopIntegration::shouldSkipConfirmUninstallDialog(const QString &desktopId) const
{
    bool result = false;
    const QString & fullPath = AppInfo::fullPathByDesktopId(desktopId);
    if (fullPath.isEmpty()) return result;

    DDesktopEntry entry(fullPath);
    if (!entry.stringValue("X-Deepin-PreUninstall").isEmpty()) {
        result = true;
    }

    return result;
}

void DesktopIntegration::uninstallApp(const QString &desktopId, const QString &displayName, const QString &iconName)
{
    const QString & fullPath = AppInfo::fullPathByDesktopId(desktopId);
    qCWarning(logDesktopIntegration) << "Launchpad uninstall requested:" << desktopId << "desktop path:" << fullPath;
    m_appWizIntegration->requestUninstall(desktopId, fullPath, displayName, iconName);
}

bool DesktopIntegration::confirmUninstallApp(const QString &desktopId, const QString &displayName, const QString &iconName)
{
    DDialog dialog(qApp->activeWindow());
    dialog.setTitle(tr("Uninstall"));
    dialog.setMessage(tr("Are you sure you want to uninstall \"%1\"?").arg(displayName));
    dialog.setWordWrapMessage(true);
    dialog.setCloseButtonVisible(true);
    dialog.setWindowModality(Qt::ApplicationModal);
    dialog.setWindowFlag(Qt::WindowStaysOnTopHint, true);

    QPixmap iconPixmap;
    IconUtils::getThemeIcon(iconPixmap, iconName, 32);
    if (!iconPixmap.isNull()) {
        dialog.setIcon(QIcon(iconPixmap));
    }

    const int cancelButton = dialog.addButton(tr("Cancel"));
    const int confirmButton = dialog.addButton(tr("Confirm"), true, DDialog::ButtonWarning);
    bool confirmed = false;

    connect(&dialog, &DDialog::buttonClicked, &dialog, [this, desktopId, displayName, iconName, confirmButton, &confirmed](int index) {
        if (index != confirmButton) {
            return;
        }

        confirmed = true;
        uninstallApp(desktopId, displayName, iconName);
    });

    if (QWindow *parentWindow = QGuiApplication::focusWindow()) {
        dialog.winId();
        if (dialog.windowHandle()) {
            dialog.windowHandle()->setTransientParent(parentWindow);
        }
        dialog.moveToCenterByRect(parentWindow->geometry());
    }

    const int result = dialog.exec();
    if (!confirmed && result == confirmButton) {
        confirmed = true;
        uninstallApp(desktopId, displayName, iconName);
    }
    qCWarning(logDesktopIntegration) << "Launchpad uninstall confirmation finished:" << desktopId << "confirmed:" << confirmed << "result:" << result;

    Q_UNUSED(cancelButton)
    return confirmed;
}

QString DesktopIntegration::popupStandardContextMenu(const QVariantList &items, int topMargin, int rightMargin, int bottomMargin, int leftMargin)
{
    DMenu menu;
    m_contextMenu = &menu;
    appendStandardContextMenuItems(&menu, items);

    if (menu.actions().isEmpty()) {
        m_contextMenu.clear();
        return {};
    }

    QPoint pos = QCursor::pos();
    QScreen *screen = QGuiApplication::screenAt(pos);
    if (!screen) {
        screen = QGuiApplication::primaryScreen();
    }

    if (screen) {
        const QRect availableGeometry = screen->geometry().adjusted(leftMargin, topMargin, -rightMargin, -bottomMargin);
        if (!availableGeometry.isEmpty()) {
            const QSize menuSize = menu.sizeHint();
            const int maxX = std::max(availableGeometry.left(), availableGeometry.right() - menuSize.width() + 1);
            const int maxY = std::max(availableGeometry.top(), availableGeometry.bottom() - menuSize.height() + 1);
            pos.setX(std::clamp(pos.x(), availableGeometry.left(), maxX));
            pos.setY(std::clamp(pos.y(), availableGeometry.top(), maxY));
        }
    }

    QAction *selectedAction = menu.exec(pos);
    m_contextMenu.clear();

    if (!selectedAction) {
        return {};
    }

    return selectedAction->data().toString();
}

void DesktopIntegration::closeStandardContextMenu()
{
    if (m_contextMenu) {
        m_contextMenu->close();
    }
}

DesktopIntegration::DesktopIntegration(QObject *parent)
    : QObject(parent)
    , m_appWizIntegration(new AppWiz(this))
    , m_dockIntegration(new DdeDock(this))
    , m_appearanceIntegration(new Appearance(this))
    , m_iconScaleFactor(1.0)
{
    qCDebug(logDesktopIntegration) << "Initializing DesktopIntegration";
    QScopedPointer<DConfig> dconfig(DConfig::create("org.deepin.dde.shell", "org.deepin.ds.launchpad"));
    Q_ASSERT_X(dconfig->isValid(), "DConfig", "DConfig file is missing or invalid");
    // TODO:
    //   1. ensure dde-control-center, deepin-calendar, dde-file-manager ship their AppStream MetaInfo file
    //   2. remove the hard-coded list below
    static const QStringList defaultCompulsoryAppIdList{
        "org.deepin.dde.control-center.desktop",
        "dde-computer.desktop",
        "dde-trash.desktop",
        "dde-file-manager.desktop",
        "deepin-terminal.desktop",
        "deepin-manual.desktop",
        "deepin-system-monitor.desktop",
        "deepin-devicemanager.desktop",
        "dde-printer.desktop",
        "deepin-app-store.desktop",
        "dde-calendar.desktop"
    };
    m_compulsoryAppIdList = dconfig->value("compulsoryAppIdList", defaultCompulsoryAppIdList).toStringList();
    qCInfo(logDesktopIntegration) << "Compulsory apps loaded:" << m_compulsoryAppIdList.size() << "apps";
    
    m_iconScaleFactor = dconfig->value("iconScaleFactor", 1.0).toReal();
    qCInfo(logDesktopIntegration) << "Icon scale factor loaded:" << m_iconScaleFactor;

    connect(m_dockIntegration, &DdeDock::directionChanged, this, &DesktopIntegration::dockPositionChanged);
    connect(m_dockIntegration, &DdeDock::geometryChanged, this, &DesktopIntegration::dockGeometryChanged);
    connect(m_appearanceIntegration, &Appearance::wallpaperBlurhashChanged, this, &DesktopIntegration::backgroundUrlChanged);
    connect(m_appearanceIntegration, &Appearance::wallpaperUrlChanged, this, &DesktopIntegration::wallpaperUrlChanged);
    connect(m_appearanceIntegration, &Appearance::opacityChanged, this, &DesktopIntegration::opacityChanged);
    connect(m_appWizIntegration, &AppWiz::uninstallExecutionStarted, this, [](const QString &desktopId) {
        AppsModel::instance().setAppTemporarilyHidden(desktopId, true);
    });
    connect(m_appWizIntegration, &AppWiz::uninstallFinished, this, [](const QString &desktopId, bool success) {
        if (!success) {
            AppsModel::instance().setAppTemporarilyHidden(desktopId, false);
        }
    });
}

double DesktopIntegration::scaleFactor() const
{
    return m_appearanceIntegration->scaleFactor();
}

qreal DesktopIntegration::opacity() const
{
    return m_appearanceIntegration->opacity();
}

qreal DesktopIntegration::iconScaleFactor() const
{
    return m_iconScaleFactor;
}

void DesktopIntegration::setIconScaleFactor(qreal factor)
{
    if (qFuzzyCompare(m_iconScaleFactor, factor)) {
        return;
    }
    
    m_iconScaleFactor = factor;
    
    // 保存到 dconfig
    QScopedPointer<DConfig> dconfig(DConfig::create("org.deepin.dde.shell", "org.deepin.ds.launchpad"));
    if (dconfig->isValid()) {
        dconfig->setValue("iconScaleFactor", factor);
        qCInfo(logDesktopIntegration) << "Icon scale factor saved:" << factor;
    }
    
    emit iconScaleFactorChanged();
}
