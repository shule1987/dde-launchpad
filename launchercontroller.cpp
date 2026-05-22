// SPDX-FileCopyrightText: 2023 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

#include "launchercontroller.h"

#include <QDir>
#include <QTimer>
#include <QSettings>
#include <QProcess>
#include <QRegularExpression>
#include <QScreen>
#include <QGuiApplication>
#include <QKeyEvent>
#include <QInputEvent>
#include <QStandardPaths>
#include <DGuiApplicationHelper>
#include <QCommandLineParser>
#include <launcher1adaptor.h>
#include <QDBusMessage>
#include <QDBusConnection>
#include <QLoggingCategory>

#include <private/qguiapplication_p.h>

DGUI_USE_NAMESPACE

namespace {
Q_LOGGING_CATEGORY(logController, "org.deepin.dde.launchpad.controller")

qreal currentXrandrRefreshRate(const QString &screenName)
{
    QProcess xrandr;
    xrandr.start(QStringLiteral("xrandr"), { QStringLiteral("--current") });
    if (!xrandr.waitForFinished(500))
        return 0;

    const QString output = QString::fromLocal8Bit(xrandr.readAllStandardOutput());
    const QStringList lines = output.split(u'\n');
    const QRegularExpression connectedOutputRe(QStringLiteral("^([^\\s]+)\\s+connected\\b"));
    const QRegularExpression activeRefreshRe(QStringLiteral("(\\d+(?:\\.\\d+)?)\\*"));

    QString currentOutput;
    qreal fallbackRate = 0;
    for (const QString &line : lines) {
        const QRegularExpressionMatch outputMatch = connectedOutputRe.match(line);
        if (outputMatch.hasMatch()) {
            currentOutput = outputMatch.captured(1);
            continue;
        }

        const QRegularExpressionMatch refreshMatch = activeRefreshRe.match(line);
        if (!refreshMatch.hasMatch())
            continue;

        const qreal rate = refreshMatch.captured(1).toDouble();
        if (rate <= 0)
            continue;

        if (fallbackRate <= 0)
            fallbackRate = rate;
        if (!screenName.isEmpty() && currentOutput == screenName)
            return rate;
    }

    return fallbackRate;
}
}

LauncherController::LauncherController(QObject *parent)
    : QObject(parent)
    , optShow(QStringList{"s", "show"}, tr("Show launcher (hidden by default)"))
    , optToggle(QStringList{"t", "toggle"}, tr("Toggle launcher visibility"))
    , m_timer(new QTimer(this))
    , m_launcher1Adaptor(new Launcher1Adaptor(this))
    , m_visible(false)
{
    qApp->installEventFilter(this);

    // TODO: settings should be managed in somewhere else.
    const QString settingBasePath(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation));
    const QString settingPath(QDir(settingBasePath).absoluteFilePath("settings.ini"));
    QSettings settings(settingPath, QSettings::NativeFormat);

    m_currentFrame = settings.value("current_frame", "WindowedFrame").toString();
    qCInfo(logController) << "Current frame mode:" << m_currentFrame;
    refreshDisplayRefreshRate();

    // Interval set to 500=>1000ms for issue https://github.com/linuxdeepin/developer-center/issues/8137
    m_timer->setInterval(1000);
    m_timer->setSingleShot(true);
    connect(m_timer, &QTimer::timeout, this, [this] {
        if (m_pendingHide) {
            m_pendingHide = false;
            setVisible(false);
        }
    });

    connect(DGuiApplicationHelper::instance(), &DGuiApplicationHelper::newProcessInstance,
            this, [this](qint64 pid, const QStringList & args) {
        Q_UNUSED(pid)

        QCommandLineParser parser;

        parser.addOption(optShow);
        parser.addOption(optToggle);
        parser.parse(args);

        if (parser.isSet(optShow)) {
            Show();
        } else if (parser.isSet(optToggle)) {
            Toggle();
        }
    });

    // for dbus adapter signals.
    connect(this, &LauncherController::visibleChanged, this, [this](bool isVisible){
        if (isVisible) {
            emit Shown();
        } else {
            emit Closed();
        }
        emit VisibleChanged(isVisible);
    });
}

void LauncherController::Exit()
{
    qApp->quit();
}

void LauncherController::Hide()
{
    updateSlowLaunchAnimationFromKeyboardModifiers();
    setVisible(false);
}

void LauncherController::Show()
{
    updateSlowLaunchAnimationFromKeyboardModifiers();
    setVisible(true);
}

void LauncherController::ShowByMode(qlonglong in0)
{
    Q_UNUSED(in0)
    // the original launcher implementation did nothing while calling this dbus API
    // I guess we can deprecate this API.
}

void LauncherController::Toggle()
{
    toggleFromDock();
}

LauncherController::~LauncherController()
{

}

bool LauncherController::visible() const
{
    return m_visible;
}

bool LauncherController::visibleLongerThan(qint64 milliseconds) const
{
    return m_visible && m_visibleTimer.isValid() && m_visibleTimer.elapsed() >= milliseconds;
}

void LauncherController::setVisible(bool visible)
{
    if (visible == m_visible) return;

    if (!visible
            && m_inputFocusHideSuppressionValid
            && m_inputFocusHideSuppressionTimer.isValid()
            && m_inputFocusHideSuppressionTimer.elapsed() < m_inputFocusHideSuppressionMs) {
        return;
    }
    if (m_inputFocusHideSuppressionValid
            && (!m_inputFocusHideSuppressionTimer.isValid()
                || m_inputFocusHideSuppressionTimer.elapsed() >= m_inputFocusHideSuppressionMs)) {
        m_inputFocusHideSuppressionValid = false;
    }

    if (!visible) {
        m_recentDockDeactivationHideTimer.start();
        m_recentDockDeactivationHideValid = true;
    }

    m_visible = visible;
    if (m_visible) {
        m_visibleTimer.start();
    } else {
        m_visibleTimer.invalidate();
    }

    emit visibleChanged(m_visible);
}

bool LauncherController::isFullScreenFrame() const
{
    return m_currentFrame == QStringLiteral("FullscreenFrame");
}

QString LauncherController::currentFrame() const
{
    return m_currentFrame;
}

void LauncherController::setCurrentFrame(const QString &frame)
{
    if (m_currentFrame == frame) return;

    const QString settingBasePath(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation));
    const QString settingPath(QDir(settingBasePath).absoluteFilePath("settings.ini"));
    QSettings settings(settingPath, QSettings::NativeFormat);

    settings.setValue("current_frame", frame);

    m_currentFrame = frame;
    qDebug() << "set current frame:" << m_currentFrame;
    m_pendingHide = false;
    m_timer->stop();
    emit currentFrameChanged();
}

QString LauncherController::currentScreen() const
{
    return m_currentScreen;
}

qreal LauncherController::displayRefreshRate() const
{
    return m_displayRefreshRate;
}

bool LauncherController::slowLaunchAnimation() const
{
    return m_slowLaunchAnimation;
}

int LauncherController::animationSpeedScale() const
{
    return m_slowLaunchAnimation ? 10 : 1;
}

void LauncherController::setSlowLaunchAnimation(bool slow)
{
    if (m_slowLaunchAnimation == slow)
        return;

    m_slowLaunchAnimation = slow;
    emit slowLaunchAnimationChanged();
}

void LauncherController::setCurrentScreen(const QString &screen)
{
    if (m_currentScreen == screen) return;

    m_currentScreen = screen;
    qCInfo(logController) << "Current screen changed to:" << m_currentScreen;
    refreshDisplayRefreshRate();
    emit currentScreenChanged();
}

void LauncherController::updateSlowLaunchAnimationFromKeyboardModifiers()
{
    setSlowLaunchAnimation(QGuiApplication::queryKeyboardModifiers().testFlag(Qt::ShiftModifier));
}

void LauncherController::suppressNextHideForInputFocus(int milliseconds)
{
    m_inputFocusHideSuppressionMs = qMax(1, milliseconds);
    m_inputFocusHideSuppressionTimer.start();
    m_inputFocusHideSuppressionValid = true;
}

bool LauncherController::eventFilter(QObject *watched, QEvent *event)
{
    switch (event->type()) {
    case QEvent::KeyPress:
    case QEvent::KeyRelease:
    case QEvent::ShortcutOverride: {
        auto *keyEvent = static_cast<QKeyEvent *>(event);
        bool slow = keyEvent->modifiers().testFlag(Qt::ShiftModifier);
        if (event->type() == QEvent::KeyPress && keyEvent->key() == Qt::Key_Shift) {
            slow = true;
        } else if (event->type() == QEvent::KeyRelease && keyEvent->key() == Qt::Key_Shift
                   && !keyEvent->modifiers().testFlag(Qt::ShiftModifier)) {
            slow = false;
        }
        setSlowLaunchAnimation(slow);
        break;
    }
    case QEvent::MouseButtonPress:
    case QEvent::MouseButtonRelease:
    case QEvent::MouseButtonDblClick:
    case QEvent::MouseMove:
    case QEvent::Wheel:
    case QEvent::TouchBegin:
    case QEvent::TouchUpdate:
    case QEvent::TouchEnd: {
        auto *inputEvent = static_cast<QInputEvent *>(event);
        setSlowLaunchAnimation(inputEvent->modifiers().testFlag(Qt::ShiftModifier));
        break;
    }
    default:
        break;
    }

    return QObject::eventFilter(watched, event);
}

void LauncherController::refreshDisplayRefreshRate()
{
    qreal refreshRate = 0;
    for (QScreen *screen : qApp->screens()) {
        if (screen && (m_currentScreen.isEmpty() || screen->name() == m_currentScreen)) {
            refreshRate = qMax(refreshRate, screen->refreshRate());
        }
    }

    refreshRate = qMax(refreshRate, currentXrandrRefreshRate(m_currentScreen));
    refreshRate = qMax<qreal>(60, refreshRate);
    if (qFuzzyCompare(m_displayRefreshRate, refreshRate))
        return;

    m_displayRefreshRate = refreshRate;
    qCInfo(logController) << "Display refresh rate:" << m_displayRefreshRate;
    emit displayRefreshRateChanged();
}

// We need to hide the launcher when it lost focus, but clicking the launcher icon on the taskbar/dock will also trigger
// `Toggle()`, which will show the launcher even if it just get hid caused by losting focus. Thus, we added a timer to
// mark it as we just hide it, and check if the timer is running while calling `Toggle()`. This function will do nothing
// if it's already hidden (`Toggle()` get triggered before `hideWithTimer()` get called).
void LauncherController::hideWithTimer()
{
    if (visible()) {
        if (m_timer->isActive()) {
            m_pendingHide = true;
            return;
        }
        if (m_avoidHide) {
            qDebug() << "hide with timer";
            setVisible(false);
        }
    }
}

void LauncherController::hideFromDockDeactivation()
{
    constexpr qint64 dockShowDeactivationGuardMs = 320;

    if (!visible())
        return;

    if (m_recentDockShowValid && m_recentDockShowTimer.isValid()
        && m_recentDockShowTimer.elapsed() < dockShowDeactivationGuardMs) {
        return;
    }

    updateSlowLaunchAnimationFromKeyboardModifiers();
    m_recentDockDeactivationHideTimer.start();
    m_recentDockDeactivationHideValid = true;
    setVisible(false);
}

void LauncherController::toggleFromDock()
{
    constexpr qint64 duplicateToggleGuardMs = 180;
    constexpr qint64 deactivationToggleGuardMs = 320;

    updateSlowLaunchAnimationFromKeyboardModifiers();

    if (m_recentDockToggleValid && m_recentDockToggleTimer.isValid()
        && m_recentDockToggleTimer.elapsed() < duplicateToggleGuardMs) {
        return;
    }

    if (!visible() && m_recentDockDeactivationHideValid && m_recentDockDeactivationHideTimer.isValid()
        && m_recentDockDeactivationHideTimer.elapsed() < deactivationToggleGuardMs) {
        return;
    }

    m_recentDockToggleTimer.start();
    m_recentDockToggleValid = true;

    if (visible()) {
        setVisible(false);
        return;
    }

    m_recentDockDeactivationHideValid = false;
    m_recentDockShowTimer.start();
    m_recentDockShowValid = true;
    setVisible(true);
}

void LauncherController::toggleFromPanelEdge()
{
    constexpr qint64 deactivationToggleGuardMs = 320;

    if (!visible() && m_recentDockDeactivationHideValid && m_recentDockDeactivationHideTimer.isValid()
        && m_recentDockDeactivationHideTimer.elapsed() < deactivationToggleGuardMs) {
        return;
    }

    toggleFromDock();
}

void LauncherController::cancelHide()
{
    m_pendingHide = false;
}

QFont LauncherController::adjustFontWeight(const QFont &f, QFont::Weight weight)
{
    QFont font(f);
    font.setWeight(weight);
    return font;
}

void LauncherController::closeAllPopups()
{
    QGuiApplicationPrivate *qAppPrivate = QGuiApplicationPrivate::instance();
    Q_ASSERT(qAppPrivate);
    qAppPrivate->closeAllPopups();
}

void LauncherController::setAvoidHide(bool avoidHide)
{
    m_avoidHide = avoidHide;
}

void LauncherController::showHelp()
{
    // 由于当前只有调用 “启动器”，才能跳转到帮助文档的启动器目录。使用launcher 以及launchpad等字段，无法跳转到启动器目录。
    QString helpTitle = "启动器";
    
    const QString &dmanInterface = "com.deepin.Manual.Open";
    QDBusMessage message = QDBusMessage::createMethodCall(dmanInterface, "/com/deepin/Manual/Open", dmanInterface, "OpenTitle");
    message << "dde" << helpTitle;
    QDBusConnection::sessionBus().asyncCall(message);
}

//首次从全屏切换到窗口时候，会出现焦点丢失抖动问题，从而导致启动器窗口不显示，所以采用此方法处理。
void LauncherController::setCurrentFrameToWindowedFrame()
{
    setVisible(false);
    QTimer::singleShot(100, this, [this]() {
        setCurrentFrame("WindowedFrame");
        setVisible(true);
    });
}

void LauncherController::setCurrentFrameToFullscreenFrame()
{
    suppressNextHideForInputFocus(650);
    cancelHide();
    setCurrentFrame(QStringLiteral("FullscreenFrame"));
    setVisible(true);
}
