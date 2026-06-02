// SPDX-FileCopyrightText: 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

#include <QGuiApplication>
#include <QAbstractEventDispatcher>
#include <QNativeGestureEvent>
#include <QPointingDevice>
#include <QTest>
#include <QWindow>
#include <QtGui/qguiapplication_platform.h>

#include "../launchercontroller.h"

#ifndef Q_MOC_RUN
#include <X11/Xlib.h>
#include <X11/extensions/XInput2.h>
#include <X11/extensions/XI2proto.h>
#include <xcb/xcb.h>
#endif

class TestLauncherController : public QObject
{
    Q_OBJECT

private slots:
    void fourFingerContractingPinchShowsLauncher();
    void fiveFingerExpandingPinchHidesLauncher();
    void threeFingerPinchIsIgnored();
    void explicitPinchHideBypassesInputFocusSuppression();
    void xinputPinchControlsLauncher();
};

namespace {
void sendNativeGesture(QWindow *window, Qt::NativeGestureType type, int fingerCount, qreal value)
{
    QNativeGestureEvent gesture(type,
                                QPointingDevice::primaryPointingDevice(),
                                fingerCount,
                                QPointF(10, 10),
                                QPointF(10, 10),
                                QPointF(10, 10),
                                value,
                                QPointF());
    QCoreApplication::sendEvent(window, &gesture);
}

void sendZoomGesture(QWindow *window, int fingerCount, qreal value)
{
    sendNativeGesture(window, Qt::BeginNativeGesture, fingerCount, 0);
    sendNativeGesture(window, Qt::ZoomNativeGesture, fingerCount, value);
    sendNativeGesture(window, Qt::EndNativeGesture, fingerCount, 0);
}

#ifndef Q_MOC_RUN
int queryXInputOpcode()
{
    auto *x11App = qGuiApp->nativeInterface<QNativeInterface::QX11Application>();
    if (!x11App || !x11App->display())
        return -1;

    int eventBase = 0;
    int errorBase = 0;
    int xiOpcode = -1;
    if (!XQueryExtension(x11App->display(), "XInputExtension", &xiOpcode, &eventBase, &errorBase))
        return -1;

    int major = 2;
    int minor = 4;
    if (XIQueryVersion(x11App->display(), &major, &minor) != Success || major < 2 || (major == 2 && minor < 4))
        return -1;

    return xiOpcode;
}

void sendXInputPinchEvent(int xiOpcode, uint16_t eventType, int fingerCount, qreal scale)
{
    xXIGesturePinchEvent event = {};
    event.type = XCB_GE_GENERIC;
    event.extension = static_cast<uint8_t>(xiOpcode);
    event.length = (sizeof(event) - sizeof(xcb_ge_event_t)) / 4;
    event.evtype = eventType;
    event.detail = static_cast<uint32_t>(fingerCount);
    event.scale = static_cast<FP1616>(qRound64(scale * 65536.0));

    qintptr result = 0;
    QAbstractEventDispatcher::instance()->filterNativeEvent(QByteArrayLiteral("xcb_generic_event_t"), &event, &result);
}

void sendXInputPinchGesture(int xiOpcode, int fingerCount, qreal updateScale)
{
    sendXInputPinchEvent(xiOpcode, XI_GesturePinchBegin, fingerCount, 1.0);
    sendXInputPinchEvent(xiOpcode, XI_GesturePinchUpdate, fingerCount, updateScale);
    sendXInputPinchEvent(xiOpcode, XI_GesturePinchEnd, fingerCount, 1.0);
}
#endif
}

void TestLauncherController::fourFingerContractingPinchShowsLauncher()
{
    auto &controller = LauncherController::instance();
    QWindow window;
    window.show();
    QVERIFY(QTest::qWaitForWindowExposed(&window));

    controller.setVisible(false);
    sendZoomGesture(&window, 4, -0.018);

    QCOMPARE(controller.visible(), true);
}

void TestLauncherController::fiveFingerExpandingPinchHidesLauncher()
{
    auto &controller = LauncherController::instance();
    QWindow window;
    window.show();
    QVERIFY(QTest::qWaitForWindowExposed(&window));

    controller.setVisible(true);
    sendZoomGesture(&window, 5, 0.018);

    QCOMPARE(controller.visible(), false);
}

void TestLauncherController::threeFingerPinchIsIgnored()
{
    auto &controller = LauncherController::instance();
    QWindow window;
    window.show();
    QVERIFY(QTest::qWaitForWindowExposed(&window));

    controller.setVisible(false);
    sendZoomGesture(&window, 3, -0.2);
    QCOMPARE(controller.visible(), false);

    controller.setVisible(true);
    sendZoomGesture(&window, 3, 0.2);
    QCOMPARE(controller.visible(), true);
}

void TestLauncherController::explicitPinchHideBypassesInputFocusSuppression()
{
    auto &controller = LauncherController::instance();
    QWindow window;
    window.show();
    QVERIFY(QTest::qWaitForWindowExposed(&window));

    controller.setVisible(true);
    controller.suppressNextHideForInputFocus(10000);
    sendZoomGesture(&window, 5, 0.018);

    QCOMPARE(controller.visible(), false);
}

void TestLauncherController::xinputPinchControlsLauncher()
{
    auto &controller = LauncherController::instance();
    const int xiOpcode = queryXInputOpcode();
    if (xiOpcode < 0)
        QSKIP("XInput 2.4 gesture events are not available");

    controller.setVisible(false);
    sendXInputPinchGesture(xiOpcode, 4, 0.982);
    QCOMPARE(controller.visible(), true);

    controller.setVisible(true);
    controller.suppressNextHideForInputFocus(10000);
    sendXInputPinchGesture(xiOpcode, 5, 1.018);
    QCOMPARE(controller.visible(), false);

    controller.setVisible(false);
    sendXInputPinchGesture(xiOpcode, 3, 0.50);
    QCOMPARE(controller.visible(), false);
}

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    TestLauncherController test;
    return QTest::qExec(&test, argc, argv);
}

#include "launchercontrollertest.moc"
