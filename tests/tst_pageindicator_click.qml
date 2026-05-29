// SPDX-FileCopyrightText: 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtTest 1.3

TestCase {
    id: testCase
    name: "PageIndicatorClick"
    width: 320
    height: 120
    visible: true
    when: windowShown
    property bool dotPressed: false

    SwipeView {
        id: pagesView
        width: 300
        height: 60

        Repeater {
            model: 3
            Item {
                width: pagesView.width
                height: pagesView.height
            }
        }
    }

    PageIndicator {
        id: pageIndicator
        anchors.top: pagesView.bottom
        anchors.horizontalCenter: pagesView.horizontalCenter
        count: pagesView.count
        currentIndex: pagesView.currentIndex
        interactive: false
        padding: 0
        spacing: 10

        delegate: Rectangle {
            required property int index
            readonly property int pageIndex: index
            objectName: "dot" + pageIndex
            implicitWidth: 8
            implicitHeight: 8
            width: implicitWidth
            height: implicitHeight
            radius: height / 2
            color: pageIndex === pageIndicator.currentIndex ? "white" : "gray"

            MouseArea {
                objectName: "dotMouse" + parent.pageIndex
                anchors.fill: parent
                onPressed: testCase.dotPressed = true
                onClicked: pagesView.setCurrentIndex(parent.pageIndex)
            }
        }
    }

    function test_clickIndicatorSwitchesPage() {
        compare(pagesView.currentIndex, 0)
        waitForRendering(pageIndicator)
        verify(pageIndicator.visible, "pageIndicator visible")
        const targetDot = findChild(pageIndicator, "dotMouse2")
        verify(targetDot !== null)
        verify(targetDot.width > 0, "targetDot width is " + targetDot.width)
        verify(targetDot.height > 0, "targetDot height is " + targetDot.height)
        verify(targetDot.visible, "targetDot visible")
        verify(targetDot.enabled, "targetDot enabled")
        mouseClick(targetDot, targetDot.width / 2, targetDot.height / 2, Qt.LeftButton)
        verify(dotPressed)
        tryCompare(pagesView, "currentIndex", 2)
    }
}
