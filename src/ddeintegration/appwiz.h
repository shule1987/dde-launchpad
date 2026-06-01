// SPDX-FileCopyrightText: 2023 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QObject>
#include <QHash>
#include <QStringList>

class __DaemonLauncher1;
class AppWiz : public QObject
{
    Q_OBJECT

public:
    explicit AppWiz(QObject *parent = nullptr);
    ~AppWiz();

    void requestUninstall(const QString &desktopId,
                          const QString &desktopFileFullPath,
                          const QString &displayName = QString(),
                          const QString &iconName = QString());
    void legacyRequestUninstall(const QString &desktopFileFullPath,
                                const QString &displayName = QString(),
                                const QString &iconName = QString());

signals:
    void uninstallExecutionStarted(const QString &desktopId);
    void uninstallFinished(const QString &desktopId, bool success);

private:
    struct UninstallInfo {
        QString displayName;
        QString iconName;
        QStringList aliases;
    };

    void notifyUninstallSucceeded(const QString &appId);
    void notifyUninstallFailed(const QString &appId, const QString &errorMessage);
    void notifyUninstallCanceled(const QString &appId, const QString &reason);
    void sendUninstallNotification(const QString &summary, const QString &body, const QString &iconName);
    UninstallInfo takeUninstallInfo(const QString &appId);
    void rememberUninstallInfo(const QString &desktopId,
                               const QString &desktopFileFullPath,
                               const QString &displayName,
                               const QString &iconName);
    void updateCurrentWallpaperBlurhash();

    __DaemonLauncher1 * m_dbusDaemonLauncherIface;
    QHash<QString, UninstallInfo> m_pendingUninstalls;
};
