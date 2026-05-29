// SPDX-FileCopyrightText: 2023 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

#include "appwiz.h"

#include "DaemonLauncher1.h"

#include <DNotifySender>
#include <QDBusPendingCallWatcher>
#include <QFileInfo>
#include <QMetaObject>
#include <QProcess>
#include <QThreadPool>
#include <DDesktopEntry>
#include <QLoggingCategory>

Q_DECLARE_LOGGING_CATEGORY(logDdeIntegration)

using DaemonLauncher1 = __DaemonLauncher1;

DCORE_USE_NAMESPACE

AppWiz::AppWiz(QObject *parent)
    : QObject(parent)
    , m_dbusDaemonLauncherIface(new DaemonLauncher1(DaemonLauncher1::staticInterfaceName(), "/org/deepin/dde/daemon/Launcher1",
                                                    QDBusConnection::sessionBus(), this))
{
    qCDebug(logDdeIntegration) << "Initializing AppWiz";

    connect(m_dbusDaemonLauncherIface, &DaemonLauncher1::UninstallSuccess, this, &AppWiz::notifyUninstallSucceeded);
    connect(m_dbusDaemonLauncherIface, &DaemonLauncher1::UninstallFailed, this, &AppWiz::notifyUninstallFailed);
}

AppWiz::~AppWiz()
{
    qCDebug(logDdeIntegration) << "Destroying AppWiz";
}

// TODO: remove this and the whole m_dbusDaemonLauncherIface thing once we have a modern "appwiz" service for uninstalling apps.
void AppWiz::legacyRequestUninstall(const QString &desktopFileFullPath, const QString &displayName, const QString &iconName)
{
    rememberUninstallInfo(desktopFileFullPath, displayName, iconName);

    QThreadPool::globalInstance()->start([desktopFileFullPath, this]() {

        DDesktopEntry desktopEntry(desktopFileFullPath);
        if (desktopEntry.status() != DDesktopEntry::NoError) {
            qCWarning(logDdeIntegration) << "Desktop file is invalid:" << desktopFileFullPath;
            QMetaObject::invokeMethod(this, [this, desktopFileFullPath]() {
                notifyUninstallFailed(desktopFileFullPath, tr("Invalid desktop file"));
            }, Qt::QueuedConnection);
            return;
        }

        if (!desktopEntry.stringValue("X-Deepin-PreUninstall").isEmpty()) {
            QFileInfo desktopFileInfo(desktopFileFullPath);
            bool writable = desktopFileInfo.isWritable();
            if (writable) {
                qCDebug(logDdeIntegration) << "Desktop file" << desktopFileFullPath << "is writable, it might be a user-level .desktop file, avoiding execute the PreUninstall command.";
            } else {
                const QString & preUninstallScript = desktopEntry.stringValue("X-Deepin-PreUninstall");
                // The script is usually a shell script, we need to execute it and check the return code.
                // We don't need pkexec, execute it directly.
                // If error, we should print the stderr and return.
                QStringList args = QProcess::splitCommand(preUninstallScript);
                QProcess process;
                if (args.size() < 1) {
                    qCDebug(logDdeIntegration) << "Pre-uninstall script" << preUninstallScript << "is invalid, aborting uninstallation for" << desktopFileFullPath;
                    QMetaObject::invokeMethod(this, [this, desktopFileFullPath]() {
                        notifyUninstallFailed(desktopFileFullPath, tr("Invalid pre-uninstall command"));
                    }, Qt::QueuedConnection);
                    return;
                } else if (args.size() == 1) {
                    process.start(args[0]);
                } else {
                    process.start(args[0], args.mid(1));
                }
                bool succ = process.waitForFinished(-1);
                if (!succ || process.exitCode() != 0) {
                    const int exitCode = process.exitCode();
                    qCDebug(logDdeIntegration) << "Pre-uninstall script" << preUninstallScript << "exited with exit code:" << exitCode << process.error();
                    switch (exitCode) {
                    case 101:
                        qCDebug(logDdeIntegration) << "Which means user canceled uninstallation for" << desktopFileFullPath;
                        qCDebug(logDdeIntegration) << "Thus aborting the uninstallation.";
                        QMetaObject::invokeMethod(this, [this, desktopFileFullPath]() {
                            notifyUninstallCanceled(desktopFileFullPath, tr("Canceled by user"));
                        }, Qt::QueuedConnection);
                        return;
                    case 103:
                        qCDebug(logDdeIntegration) << "Which means there is a running instance of the pre-uninstall script for" << desktopFileFullPath;
                        qCDebug(logDdeIntegration) << "Thus aborting the uninstallation.";
                        QMetaObject::invokeMethod(this, [this, desktopFileFullPath]() {
                            notifyUninstallFailed(desktopFileFullPath, tr("Another uninstall task is already running"));
                        }, Qt::QueuedConnection);
                        return;
                    default:
                        qCDebug(logDdeIntegration) << "stderr:" << process.readAllStandardError();
                        qCDebug(logDdeIntegration) << "stdout:" << process.readAllStandardOutput();
                        qCDebug(logDdeIntegration) << "Will continue uninstallation for" << desktopFileFullPath;
                    }
                }
                qCDebug(logDdeIntegration) << "Pre-uninstall script" << preUninstallScript << "succeeded.";
            }
        }

        QMetaObject::invokeMethod(this, [this, desktopFileFullPath]() {
            QDBusPendingReply<> reply = m_dbusDaemonLauncherIface->RequestUninstall(desktopFileFullPath, true);
            auto *watcher = new QDBusPendingCallWatcher(reply, this);
            connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, desktopFileFullPath](QDBusPendingCallWatcher *call) {
                QDBusPendingReply<> finishedReply = *call;
                if (finishedReply.isError()) {
                    qCDebug(logDdeIntegration) << finishedReply.error();
                    notifyUninstallFailed(desktopFileFullPath, finishedReply.error().message());
                }
                call->deleteLater();
            });
        }, Qt::QueuedConnection);
    });
}

void AppWiz::notifyUninstallSucceeded(const QString &appId)
{
    const UninstallInfo info = takeUninstallInfo(appId);
    const QString displayName = info.displayName.isEmpty() ? appId : info.displayName;
    sendUninstallNotification(tr("Uninstall complete"),
                              tr("\"%1\" has been uninstalled.").arg(displayName),
                              info.iconName);
}

void AppWiz::notifyUninstallFailed(const QString &appId, const QString &errorMessage)
{
    const UninstallInfo info = takeUninstallInfo(appId);
    const QString displayName = info.displayName.isEmpty() ? appId : info.displayName;
    const QString detail = errorMessage.isEmpty() ? tr("Unknown error") : errorMessage;
    sendUninstallNotification(tr("Uninstall failed"),
                              tr("Failed to uninstall \"%1\". %2").arg(displayName, detail),
                              info.iconName);
}

void AppWiz::notifyUninstallCanceled(const QString &appId, const QString &reason)
{
    const UninstallInfo info = takeUninstallInfo(appId);
    const QString displayName = info.displayName.isEmpty() ? appId : info.displayName;
    const QString detail = reason.isEmpty() ? tr("The uninstall task was canceled.") : reason;
    sendUninstallNotification(tr("Uninstall canceled"),
                              tr("\"%1\" was not uninstalled. %2").arg(displayName, detail),
                              info.iconName);
}

void AppWiz::sendUninstallNotification(const QString &summary, const QString &body, const QString &iconName)
{
    Dtk::Core::DUtil::DNotifySender(summary)
        .appName(tr("Launcher"))
        .appIcon(iconName.isEmpty() ? QStringLiteral("dde-launchpad") : iconName)
        .appBody(body)
        .timeOut(5000)
        .call();
}

AppWiz::UninstallInfo AppWiz::takeUninstallInfo(const QString &appId)
{
    const QFileInfo appFileInfo(appId);
    const QString fileName = appFileInfo.fileName();
    const QString completeBaseName = appFileInfo.completeBaseName();

    for (const QString &key : { appId, fileName, completeBaseName }) {
        if (!key.isEmpty() && m_pendingUninstalls.contains(key)) {
            return m_pendingUninstalls.take(key);
        }
    }

    return { appId, QString() };
}

void AppWiz::rememberUninstallInfo(const QString &desktopFileFullPath, const QString &displayName, const QString &iconName)
{
    const QFileInfo fileInfo(desktopFileFullPath);
    UninstallInfo info;
    info.displayName = displayName.isEmpty() ? fileInfo.completeBaseName() : displayName;
    info.iconName = iconName;

    const QString fileName = fileInfo.fileName();
    const QString completeBaseName = fileInfo.completeBaseName();
    for (const QString &key : { desktopFileFullPath, fileName, completeBaseName }) {
        if (!key.isEmpty()) {
            m_pendingUninstalls.insert(key, info);
        }
    }
}
