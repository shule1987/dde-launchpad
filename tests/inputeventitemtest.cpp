// SPDX-FileCopyrightText: 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

#include <QGuiApplication>
#include <QInputMethodEvent>
#include <QKeyEvent>
#include <QQuickItem>
#include <QQuickWindow>
#include <QSignalSpy>
#include <QTest>
#include <QWheelEvent>

#include "../inputeventitem.h"

class TestInputEventItem : public QObject
{
    Q_OBJECT

private slots:
    void printableKeyStartsSearchWhenNoEditableItemHasFocus();
    void printableKeyDoesNotStealEditableFocus();
    void inputMethodCommitDoesNotStartSearchWhileEditingText();
    void windowWheelEventIsForwardedWithPixelDelta();
};

void TestInputEventItem::printableKeyStartsSearchWhenNoEditableItemHasFocus()
{
    QQuickWindow window;
    InputEventItem root;
    QQuickItem searchEdit;

    root.setParentItem(window.contentItem());
    root.setSize(QSizeF(200, 200));
    searchEdit.setParentItem(&root);
    searchEdit.setProperty("text", QString());
    root.setInputMethodSource(&searchEdit);

    window.show();
    QVERIFY(QTest::qWaitForWindowExposed(&window));

    QKeyEvent keyPress(QEvent::KeyPress, Qt::Key_A, Qt::NoModifier, QStringLiteral("a"));
    QCoreApplication::sendEvent(&window, &keyPress);

    QCOMPARE(searchEdit.property("text").toString(), QStringLiteral("a"));
}

void TestInputEventItem::printableKeyDoesNotStealEditableFocus()
{
    QQuickWindow window;
    InputEventItem root;
    QQuickItem searchEdit;
    QQuickItem titleEdit;

    root.setParentItem(window.contentItem());
    root.setSize(QSizeF(200, 200));
    searchEdit.setParentItem(&root);
    searchEdit.setProperty("text", QString());
    root.setInputMethodSource(&searchEdit);

    titleEdit.setParentItem(&root);
    titleEdit.setProperty("text", QStringLiteral("Folder"));
    titleEdit.setProperty("cursorPosition", 6);
    titleEdit.setProperty("readOnly", false);

    window.show();
    QVERIFY(QTest::qWaitForWindowExposed(&window));
    titleEdit.forceActiveFocus();
    QCOMPARE(window.activeFocusItem(), &titleEdit);

    QKeyEvent keyPress(QEvent::KeyPress, Qt::Key_B, Qt::NoModifier, QStringLiteral("b"));
    QCoreApplication::sendEvent(&window, &keyPress);

    QCOMPARE(window.activeFocusItem(), &titleEdit);
    QCOMPARE(searchEdit.property("text").toString(), QString());
}

void TestInputEventItem::inputMethodCommitDoesNotStartSearchWhileEditingText()
{
    QQuickWindow window;
    InputEventItem root;
    QQuickItem searchEdit;
    QQuickItem titleEdit;
    QSignalSpy inputSpy(&root, &InputEventItem::inputReceived);

    root.setParentItem(window.contentItem());
    root.setSize(QSizeF(200, 200));
    searchEdit.setParentItem(&root);
    searchEdit.setProperty("text", QString());
    root.setInputMethodSource(&searchEdit);

    titleEdit.setParentItem(&root);
    titleEdit.setProperty("text", QStringLiteral("Folder"));
    titleEdit.setProperty("cursorPosition", 6);
    titleEdit.setProperty("readOnly", false);

    window.show();
    QVERIFY(QTest::qWaitForWindowExposed(&window));
    titleEdit.forceActiveFocus();
    QCOMPARE(window.activeFocusItem(), &titleEdit);

    QInputMethodEvent inputEvent(QStringLiteral("中"), {});
    QCoreApplication::sendEvent(&root, &inputEvent);

    QCOMPARE(inputSpy.count(), 0);
    QCOMPARE(searchEdit.property("text").toString(), QString());
}

void TestInputEventItem::windowWheelEventIsForwardedWithPixelDelta()
{
    QQuickWindow window;
    InputEventItem root;
    QSignalSpy wheelSpy(&root, &InputEventItem::wheelReceived);

    root.setParentItem(window.contentItem());
    root.setSize(QSizeF(200, 200));

    window.show();
    QVERIFY(QTest::qWaitForWindowExposed(&window));

    QWheelEvent wheelEvent(QPointF(40, 50),
                           QPointF(140, 150),
                           QPoint(18, 0),
                           QPoint(0, 0),
                           Qt::NoButton,
                           Qt::NoModifier,
                           Qt::ScrollUpdate,
                           false);
    QCoreApplication::sendEvent(&window, &wheelEvent);

    QCOMPARE(wheelSpy.count(), 1);
    const QList<QVariant> arguments = wheelSpy.takeFirst();
    QCOMPARE(arguments.at(0).toPointF(), QPointF(40, 50));
    QCOMPARE(arguments.at(1).toPoint(), QPoint(18, 0));
    QCOMPARE(arguments.at(2).toPoint(), QPoint(0, 0));
    QCOMPARE(arguments.at(3).toInt(), int(Qt::NoModifier));
    QVERIFY(wheelEvent.isAccepted());
}

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    TestInputEventItem test;
    return QTest::qExec(&test, argc, argv);
}

#include "inputeventitemtest.moc"
