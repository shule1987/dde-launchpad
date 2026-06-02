// SPDX-FileCopyrightText: 2023 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QtQml/qqml.h>
#include <QAbstractNativeEventFilter>
#include <QCommandLineOption>
#include <QElapsedTimer>
#include <QFont>
#include <QObject>

class QTimer;
class Launcher1Adaptor;
class QNativeGestureEvent;
class LauncherController : public QObject, public QAbstractNativeEventFilter
{
    Q_OBJECT

    Q_PROPERTY(bool visible READ visible WRITE setVisible NOTIFY visibleChanged)
    Q_PROPERTY(QString currentFrame READ currentFrame WRITE setCurrentFrame NOTIFY currentFrameChanged)
    Q_PROPERTY(QString currentScreen READ currentScreen WRITE setCurrentScreen NOTIFY currentScreenChanged)
    Q_PROPERTY(qreal displayRefreshRate READ displayRefreshRate NOTIFY displayRefreshRateChanged)
    Q_PROPERTY(bool slowLaunchAnimation READ slowLaunchAnimation WRITE setSlowLaunchAnimation NOTIFY slowLaunchAnimationChanged)
    Q_PROPERTY(int animationSpeedScale READ animationSpeedScale NOTIFY slowLaunchAnimationChanged)

    QML_NAMED_ELEMENT(LauncherController)
    QML_SINGLETON
    // I really don't want to expose those dbus API as public function...
    friend class Launcher1Adaptor;

public:

    static LauncherController &instance()
    {
        static LauncherController _instance;
        return _instance;
    }

    static LauncherController *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine)
    {
        Q_UNUSED(qmlEngine)
        Q_UNUSED(jsEngine)
        return &instance();
    }

    ~LauncherController();

    bool visible() const;
    bool visibleLongerThan(qint64 milliseconds) const;
    void setVisible(bool visible);
    bool isFullScreenFrame() const;
    QString currentFrame() const;
    void setCurrentFrame(const QString & frame);
    QString currentScreen() const;
    void setCurrentScreen(const QString & screen);
    qreal displayRefreshRate() const;
    bool slowLaunchAnimation() const;
    int animationSpeedScale() const;
    void setSlowLaunchAnimation(bool slow);

    Q_INVOKABLE void hideWithTimer();
    Q_INVOKABLE void hideFromDockDeactivation();
    Q_INVOKABLE void toggleFromPanelEdge();
    Q_INVOKABLE void toggleFromDock();
    Q_INVOKABLE void updateSlowLaunchAnimationFromKeyboardModifiers();
    Q_INVOKABLE void suppressNextHideForInputFocus(int milliseconds = 350);
    Q_INVOKABLE void setAvoidHide(bool avoidHide);
    Q_INVOKABLE void cancelHide();
    Q_INVOKABLE QFont adjustFontWeight(const QFont& f, QFont::Weight weight);

    Q_INVOKABLE void closeAllPopups();
    Q_INVOKABLE void showHelp();
    Q_INVOKABLE void setCurrentFrameToWindowedFrame();
    Q_INVOKABLE void setCurrentFrameToFullscreenFrame();

signals:
    void currentFrameChanged();
    void currentScreenChanged();
    void displayRefreshRateChanged();
    void slowLaunchAnimationChanged();
    void visibleChanged(bool visible);

public:
    QCommandLineOption optShow;
    QCommandLineOption optToggle;

    // called by dbus adapter
private:
    Q_PROPERTY(bool Visible READ visible NOTIFY VisibleChanged)
    void Exit();
    void Hide();
    void Show();
    void ShowByMode(qlonglong in0);
    void Toggle();
signals:
    void Closed();
    void Shown();
    void VisibleChanged(bool visible);

private:
    explicit LauncherController(QObject *parent=nullptr);
    bool eventFilter(QObject *watched, QEvent *event) override;
    bool nativeEventFilter(const QByteArray &eventType, void *message, qintptr *result) override;
    void refreshDisplayRefreshRate();
    void initializeX11TouchpadGesture();
    bool handleX11TouchpadGestureEvent(void *message);
    bool handleTouchpadLauncherGesture(QNativeGestureEvent *event);
    bool updateTouchpadLauncherGesture(int fingerCount, qreal zoomAmount, bool cumulative);
    void resetTouchpadLauncherGesture();

    QTimer *m_timer;
    Launcher1Adaptor * m_launcher1Adaptor;
    bool m_visible;
    QElapsedTimer m_visibleTimer;
    QString m_currentFrame;
    QString m_currentScreen;
    qreal m_displayRefreshRate = 60;
    bool m_slowLaunchAnimation = false;
    bool m_pendingHide = false;
    bool m_avoidHide = true; 
    bool m_recentDockDeactivationHideValid = false;
    QElapsedTimer m_recentDockDeactivationHideTimer;
    bool m_recentDockToggleValid = false;
    QElapsedTimer m_recentDockToggleTimer;
    bool m_recentDockShowValid = false;
    QElapsedTimer m_recentDockShowTimer;
    bool m_inputFocusHideSuppressionValid = false;
    int m_inputFocusHideSuppressionMs = 0;
    QElapsedTimer m_inputFocusHideSuppressionTimer;
    bool m_touchpadLauncherGestureActive = false;
    bool m_touchpadLauncherGestureTriggered = false;
    qreal m_touchpadLauncherGestureZoom = 0;
    QElapsedTimer m_touchpadLauncherGestureUpdateTimer;
    int m_xinput2Opcode = -1;
};
