// SPDX-FileCopyrightText: 2023 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

#include "appwiz.h"

#include "DaemonLauncher1.h"

#include <DNotifySender>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QElapsedTimer>
#include <QFileInfo>
#include <QMetaObject>
#include <QProcess>
#include <QStandardPaths>
#include <QThreadPool>
#include <DDesktopEntry>
#include <QLoggingCategory>

#include <utility>
#include <functional>

#include <unistd.h>

Q_DECLARE_LOGGING_CATEGORY(logDdeIntegration)

using DaemonLauncher1 = __DaemonLauncher1;

DCORE_USE_NAMESPACE

namespace {
constexpr int UninstallCommandTimeoutMs = 30 * 60 * 1000;
constexpr int PackageLookupTimeoutMs = 30 * 1000;

enum class StartNotifyMode {
    AfterProcessStarted,
    AfterPkexecAuthorized,
};

struct CommandSpec {
    QString program;
    QStringList arguments;
    StartNotifyMode startNotifyMode = StartNotifyMode::AfterProcessStarted;
};

QString desktopEntryValue(const DDesktopEntry &entry, std::initializer_list<const char *> keys)
{
    for (const char *key : keys) {
        const QString value = entry.stringValue(QString::fromLatin1(key)).trimmed();
        if (!value.isEmpty()) {
            return value;
        }
    }

    return {};
}

QString processOutput(QProcess &process)
{
    QString output = QString::fromLocal8Bit(process.readAll()).trimmed();
    if (output.size() > 500) {
        output = output.left(500) + QStringLiteral("...");
    }
    return output;
}

QString packageNameFromDpkgOutput(const QString &output)
{
    const QStringList lines = output.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (const QString &line : lines) {
        const int colon = line.indexOf(QLatin1Char(':'));
        if (colon <= 0) {
            continue;
        }

        const QString packageNames = line.left(colon).trimmed();
        for (const QString &packageName : packageNames.split(QLatin1Char(','), Qt::SkipEmptyParts)) {
            const QString trimmedPackageName = packageName.trimmed();
            if (!trimmedPackageName.isEmpty()) {
                return trimmedPackageName;
            }
        }
    }

    return {};
}

QString queryDpkgPackageForPath(const QString &path)
{
    if (path.isEmpty() || QStandardPaths::findExecutable(QStringLiteral("dpkg-query")).isEmpty()) {
        return {};
    }

    QProcess process;
    process.setProcessChannelMode(QProcess::MergedChannels);
    process.start(QStringLiteral("dpkg-query"), { QStringLiteral("-S"), path });
    if (!process.waitForStarted()) {
        qCWarning(logDdeIntegration) << "Launchpad uninstall package lookup failed to start for" << path << process.errorString();
        return {};
    }

    if (!process.waitForFinished(PackageLookupTimeoutMs)) {
        process.kill();
        process.waitForFinished();
        qCWarning(logDdeIntegration) << "Launchpad uninstall package lookup timed out for" << path;
        return {};
    }

    const QString output = processOutput(process);
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        qCWarning(logDdeIntegration) << "Launchpad uninstall package lookup found no dpkg owner for" << path << output;
        return {};
    }

    return packageNameFromDpkgOutput(output);
}

QString dpkgPackageForDesktopFile(const QString &desktopFileFullPath)
{
    QStringList candidates;
    const auto addCandidate = [&candidates](const QString &path) {
        if (!path.isEmpty() && !candidates.contains(path)) {
            candidates.append(path);
        }
    };

    QFileInfo desktopFileInfo(desktopFileFullPath);
    addCandidate(desktopFileFullPath);
    addCandidate(desktopFileInfo.absoluteFilePath());
    if (desktopFileInfo.isSymLink()) {
        addCandidate(desktopFileInfo.symLinkTarget());
    }
    addCandidate(desktopFileInfo.canonicalFilePath());

    for (const QString &candidate : std::as_const(candidates)) {
        const QString packageName = queryDpkgPackageForPath(candidate);
        if (!packageName.isEmpty()) {
            qCWarning(logDdeIntegration) << "Launchpad uninstall dpkg package resolved:" << packageName << "from" << candidate;
            return packageName;
        }
    }

    return {};
}

CommandSpec dpkgUninstallCommand(const QString &packageName)
{
    if (geteuid() == 0) {
        return { QStringLiteral("apt"), { QStringLiteral("purge"), QStringLiteral("-y"), packageName } };
    }

    return { QStringLiteral("pkexec"),
             { QStringLiteral("apt"), QStringLiteral("purge"), QStringLiteral("-y"), packageName },
             StartNotifyMode::AfterPkexecAuthorized };
}

bool pkexecTargetStarted(qint64 pid)
{
    if (pid <= 0) {
        return false;
    }

    const QString executable = QFileInfo(QStringLiteral("/proc/%1/exe").arg(pid)).symLinkTarget();
    if (executable.isEmpty()) {
        return false;
    }

    return QFileInfo(executable).fileName() != QStringLiteral("pkexec");
}

bool runUninstallCommand(const QString &program,
                         const QStringList &arguments,
                         QString *errorMessage,
                         int timeoutMs = UninstallCommandTimeoutMs,
                         const std::function<void()> &startedCallback = {},
                         StartNotifyMode startNotifyMode = StartNotifyMode::AfterProcessStarted)
{
    if (QStandardPaths::findExecutable(program).isEmpty()) {
        if (errorMessage) {
            *errorMessage = AppWiz::tr("%1 is not installed").arg(program);
        }
        return false;
    }

    qCWarning(logDdeIntegration) << "Launchpad uninstall command starting:" << program << arguments;

    QProcess process;
    process.setProcessChannelMode(QProcess::MergedChannels);
    process.start(program, arguments);
    if (!process.waitForStarted()) {
        if (errorMessage) {
            *errorMessage = process.errorString();
        }
        return false;
    }

    bool startedCallbackCalled = false;
    const auto notifyStarted = [&startedCallback, &startedCallbackCalled]() {
        if (!startedCallbackCalled && startedCallback) {
            startedCallbackCalled = true;
            startedCallback();
        }
    };

    if (startNotifyMode == StartNotifyMode::AfterProcessStarted) {
        notifyStarted();
    }

    QElapsedTimer elapsed;
    elapsed.start();
    while (!process.waitForFinished(50)) {
        if (startNotifyMode == StartNotifyMode::AfterPkexecAuthorized && pkexecTargetStarted(process.processId())) {
            notifyStarted();
        }

        if (elapsed.elapsed() <= timeoutMs) {
            continue;
        }

        process.kill();
        process.waitForFinished();
        if (errorMessage) {
            *errorMessage = AppWiz::tr("Uninstall command timed out");
        }
        qCWarning(logDdeIntegration) << "Launchpad uninstall command timed out:" << program << arguments;
        return false;
    }

    const QString output = processOutput(process);
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        if (errorMessage) {
            *errorMessage = output.isEmpty()
                ? AppWiz::tr("Exit code: %1").arg(process.exitCode())
                : output;
        }
        qCWarning(logDdeIntegration) << "Launchpad uninstall command failed:" << program << arguments << "exit:" << process.exitCode() << output;
        return false;
    }

    notifyStarted();
    qCWarning(logDdeIntegration) << "Launchpad uninstall command succeeded:" << program << arguments << output;
    return true;
}
}

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

void AppWiz::legacyRequestUninstall(const QString &desktopFileFullPath, const QString &displayName, const QString &iconName)
{
    requestUninstall(QString(), desktopFileFullPath, displayName, iconName);
}

// Keep the backend local so build-run dde-shell paths are not rejected by the legacy daemon permission check.
void AppWiz::requestUninstall(const QString &desktopId, const QString &desktopFileFullPath, const QString &displayName, const QString &iconName)
{
    qCWarning(logDdeIntegration) << "Launchpad uninstall backend request:" << desktopId << desktopFileFullPath << displayName << iconName;
    rememberUninstallInfo(desktopId, desktopFileFullPath, displayName, iconName);
    const QString visualDesktopId = desktopId.isEmpty() ? QFileInfo(desktopFileFullPath).fileName() : desktopId;
    const auto emitStarted = [this, visualDesktopId]() {
        if (visualDesktopId.isEmpty()) {
            return;
        }

        QMetaObject::invokeMethod(this, [this, visualDesktopId]() {
            emit uninstallExecutionStarted(visualDesktopId);
        }, Qt::QueuedConnection);
    };
    const auto emitFinished = [this, visualDesktopId](bool success) {
        if (visualDesktopId.isEmpty()) {
            return;
        }

        QMetaObject::invokeMethod(this, [this, visualDesktopId, success]() {
            emit uninstallFinished(visualDesktopId, success);
        }, Qt::QueuedConnection);
    };

    if (desktopFileFullPath.isEmpty()) {
        emitFinished(false);
        notifyUninstallFailed(desktopId, tr("Desktop file was not found"));
        return;
    }

    QThreadPool::globalInstance()->start([desktopId, desktopFileFullPath, emitStarted, emitFinished, this]() {

        DDesktopEntry desktopEntry(desktopFileFullPath);
        if (desktopEntry.status() != DDesktopEntry::NoError) {
            qCWarning(logDdeIntegration) << "Desktop file is invalid:" << desktopFileFullPath;
            QMetaObject::invokeMethod(this, [this, desktopId, desktopFileFullPath, emitFinished]() {
                emitFinished(false);
                notifyUninstallFailed(desktopFileFullPath.isEmpty() ? desktopId : desktopFileFullPath,
                                      tr("Invalid desktop file"));
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
                    QMetaObject::invokeMethod(this, [this, desktopFileFullPath, emitFinished]() {
                        emitFinished(false);
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
                        QMetaObject::invokeMethod(this, [this, desktopFileFullPath, emitFinished]() {
                            emitFinished(false);
                            notifyUninstallCanceled(desktopFileFullPath, tr("Canceled by user"));
                        }, Qt::QueuedConnection);
                        return;
                    case 103:
                        qCDebug(logDdeIntegration) << "Which means there is a running instance of the pre-uninstall script for" << desktopFileFullPath;
                        qCDebug(logDdeIntegration) << "Thus aborting the uninstallation.";
                        QMetaObject::invokeMethod(this, [this, desktopFileFullPath, emitFinished]() {
                            emitFinished(false);
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

        const QString linglongId = desktopEntryValue(desktopEntry, { "X-linglong", "X-Linglong" });
        if (!linglongId.isEmpty()) {
            qCWarning(logDdeIntegration) << "Launchpad uninstall using Linglong backend:" << linglongId << "from" << desktopFileFullPath;
            QString errorMessage;
            const bool ok = runUninstallCommand(QStringLiteral("ll-cli"),
                                                { QStringLiteral("--no-progress"), QStringLiteral("uninstall"), linglongId },
                                                &errorMessage,
                                                UninstallCommandTimeoutMs,
                                                emitStarted);
            QMetaObject::invokeMethod(this, [this, desktopFileFullPath, linglongId, ok, errorMessage, emitFinished]() {
                emitFinished(ok);
                if (ok) {
                    notifyUninstallSucceeded(linglongId);
                } else {
                    notifyUninstallFailed(desktopFileFullPath, errorMessage);
                }
            }, Qt::QueuedConnection);
            return;
        }

        const QString flatpakId = desktopEntryValue(desktopEntry, { "X-Flatpak", "X-flatpak" });
        if (!flatpakId.isEmpty()) {
            qCWarning(logDdeIntegration) << "Launchpad uninstall using Flatpak backend:" << flatpakId << "from" << desktopFileFullPath;
            QString errorMessage;
            const bool ok = runUninstallCommand(QStringLiteral("flatpak"),
                                                { QStringLiteral("uninstall"), QStringLiteral("--noninteractive"), QStringLiteral("-y"), flatpakId },
                                                &errorMessage,
                                                UninstallCommandTimeoutMs,
                                                emitStarted);
            QMetaObject::invokeMethod(this, [this, desktopFileFullPath, flatpakId, ok, errorMessage, emitFinished]() {
                emitFinished(ok);
                if (ok) {
                    notifyUninstallSucceeded(flatpakId);
                } else {
                    notifyUninstallFailed(desktopFileFullPath, errorMessage);
                }
            }, Qt::QueuedConnection);
            return;
        }

        const QString removeCommand = desktopEntryValue(desktopEntry, { "RemoveCommand" });
        if (!removeCommand.isEmpty()) {
            QFileInfo desktopFileInfo(desktopFileFullPath);
            if (desktopFileInfo.isWritable()) {
                qCWarning(logDdeIntegration) << "Launchpad uninstall skipped writable desktop RemoveCommand:" << desktopFileFullPath;
            } else {
                qCWarning(logDdeIntegration) << "Launchpad uninstall using RemoveCommand backend:" << removeCommand << "from" << desktopFileFullPath;
                QString errorMessage;
                const bool ok = runUninstallCommand(QStringLiteral("sh"),
                                                    { QStringLiteral("-c"), removeCommand },
                                                    &errorMessage,
                                                    UninstallCommandTimeoutMs,
                                                    emitStarted);
                QMetaObject::invokeMethod(this, [this, desktopFileFullPath, ok, errorMessage, emitFinished]() {
                    emitFinished(ok);
                    if (ok) {
                        notifyUninstallSucceeded(desktopFileFullPath);
                    } else {
                        notifyUninstallFailed(desktopFileFullPath, errorMessage);
                    }
                }, Qt::QueuedConnection);
                return;
            }
        }

        const QString packageName = dpkgPackageForDesktopFile(desktopFileFullPath);
        if (!packageName.isEmpty()) {
            qCWarning(logDdeIntegration) << "Launchpad uninstall using dpkg backend:" << packageName << "from" << desktopFileFullPath;
            const CommandSpec command = dpkgUninstallCommand(packageName);
            QString errorMessage;
            const bool ok = runUninstallCommand(command.program,
                                                command.arguments,
                                                &errorMessage,
                                                UninstallCommandTimeoutMs,
                                                emitStarted,
                                                command.startNotifyMode);
            QMetaObject::invokeMethod(this, [this, desktopFileFullPath, ok, errorMessage, emitFinished]() {
                emitFinished(ok);
                if (ok) {
                    notifyUninstallSucceeded(desktopFileFullPath);
                } else {
                    notifyUninstallFailed(desktopFileFullPath, errorMessage);
                }
            }, Qt::QueuedConnection);
            return;
        }

        qCWarning(logDdeIntegration) << "Launchpad uninstall found no supported backend for" << desktopFileFullPath;
        QMetaObject::invokeMethod(this, [this, desktopFileFullPath, emitFinished]() {
            emitFinished(false);
            notifyUninstallFailed(desktopFileFullPath, tr("No supported uninstall method was found"));
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
    qCWarning(logDdeIntegration) << "Launchpad uninstall notification:" << summary << body << iconName;
    QDBusPendingCall call = Dtk::Core::DUtil::DNotifySender(summary)
        .appName(tr("Launcher"))
        .appIcon(iconName.isEmpty() ? QStringLiteral("dde-launchpad") : iconName)
        .appBody(body)
        .timeOut(5000)
        .call();
    auto *watcher = new QDBusPendingCallWatcher(call, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [summary](QDBusPendingCallWatcher *call) {
        QDBusPendingReply<uint> reply = *call;
        if (reply.isError()) {
            qCWarning(logDdeIntegration) << "Launchpad uninstall notification failed:" << summary << reply.error().message();
        }
        call->deleteLater();
    });
}

AppWiz::UninstallInfo AppWiz::takeUninstallInfo(const QString &appId)
{
    const QFileInfo appFileInfo(appId);
    const QString fileName = appFileInfo.fileName();
    const QString completeBaseName = appFileInfo.completeBaseName();

    for (const QString &key : { appId, fileName, completeBaseName }) {
        if (!key.isEmpty() && m_pendingUninstalls.contains(key)) {
            const UninstallInfo info = m_pendingUninstalls.take(key);
            for (const QString &alias : info.aliases) {
                m_pendingUninstalls.remove(alias);
            }
            return info;
        }
    }

    return { appId, QString(), {} };
}

void AppWiz::rememberUninstallInfo(const QString &desktopId, const QString &desktopFileFullPath, const QString &displayName, const QString &iconName)
{
    const QFileInfo fileInfo(desktopFileFullPath);
    UninstallInfo info;
    info.displayName = displayName.isEmpty() ? (desktopId.isEmpty() ? fileInfo.completeBaseName() : desktopId) : displayName;
    info.iconName = iconName;

    const QString fileName = fileInfo.fileName();
    const QString completeBaseName = fileInfo.completeBaseName();
    const QString desktopIdBaseName = desktopId.endsWith(QStringLiteral(".desktop")) ? QString(desktopId).chopped(8) : desktopId;
    info.aliases = { desktopId, desktopIdBaseName, desktopFileFullPath, fileName, completeBaseName };
    info.aliases.removeAll(QString());
    info.aliases.removeDuplicates();

    DDesktopEntry entry(desktopFileFullPath);
    if (entry.status() == DDesktopEntry::NoError) {
        const QString linglongId = desktopEntryValue(entry, { "X-linglong", "X-Linglong" });
        const QString flatpakId = desktopEntryValue(entry, { "X-Flatpak", "X-flatpak" });
        if (!linglongId.isEmpty()) {
            info.aliases.append(linglongId);
        }
        if (!flatpakId.isEmpty()) {
            info.aliases.append(flatpakId);
        }
    }

    info.aliases.removeDuplicates();
    for (const QString &key : std::as_const(info.aliases)) {
        m_pendingUninstalls.insert(key, info);
    }
}
