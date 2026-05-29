// SPDX-FileCopyrightText: 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15
import QtTest 1.3
import org.deepin.launchpad 1.0

TestCase {
    id: testCase
    name: "GridViewContainerItemClick"
    width: 260
    height: 260
    visible: true
    when: windowShown

    property int itemClickCount: 0

    ListModel {
        id: testModel
        ListElement { title: "one" }
    }

    Component {
        id: delegateComponent

        Rectangle {
            id: delegateRoot
            objectName: "delegate" + index
            width: 100
            height: 100
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                onClicked: testCase.itemClickCount += 1
            }
        }
    }

    Loader {
        id: containerLoader
        width: testCase.width
        height: testCase.height
    }

    function init() {
        LauncherController.visible = true
        itemClickCount = 0
    }

    function initTestCase() {
        containerLoader.setSource(Qt.resolvedUrl("../qml/GridViewContainer.qml"), {
            width: testCase.width,
            height: testCase.height,
            rows: 2,
            columns: 2,
            cellWidth: 100,
            cellHeight: 100,
            padding: 0,
            interactive: false,
            gridViewFocus: true,
            model: testModel,
            delegate: delegateComponent
        })
    }

    function test_clickingItemDoesNotHideLauncher() {
        verify(containerLoader.item !== null)
        waitForRendering(containerLoader.item)

        const delegate = findChild(containerLoader.item, "delegate0")
        verify(delegate !== null)
        mouseClick(delegate, delegate.width / 2, delegate.height / 2, Qt.LeftButton)

        compare(itemClickCount, 1)
        compare(LauncherController.visible, true)
    }
}
