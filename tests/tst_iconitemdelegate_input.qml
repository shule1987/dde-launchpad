// SPDX-FileCopyrightText: 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtTest 1.3
import org.deepin.launchpad 1.0
import org.deepin.launchpad.models 1.0
import "../qml"

TestCase {
    id: testCase
    name: "IconItemDelegateInput"
    width: 320
    height: 220
    visible: true
    when: windowShown

    property int itemClickCount: 0
    property int menuTriggerCount: 0
    property string dropEnteredId: ""

    Label {
        id: dndItem
        visible: currentlyDraggedId !== "" || Drag.active
        opacity: 0
        z: 10000
        width: Math.max(1, mergeSize)
        height: Math.max(1, mergeSize)

        property string currentlyDraggedId: ""
        property string currentlyDraggedIconName: ""
        property bool mergeAnimPending: false
        property string mergeAnimTargetIcon: ""
        property string mergeAnimTargetIcon2: ""
        property real mergeAnimStartX: 0
        property real mergeAnimStartY: 0
        property string liveReorderKey: ""
        property real mergeSize: 0

        signal dragEnded()

        Drag.onActiveChanged: {
            if (!Drag.active) {
                currentlyDraggedId = ""
                currentlyDraggedIconName = ""
                liveReorderKey = ""
                dragEnded()
            }
        }
    }

    ListModel {
        id: testModel
        ListElement {
            display: "Demo"
            desktopId: "demo.desktop"
            iconName: "application-x-desktop"
            itemType: 0
            lastLaunchedTime: 1
            installedTime: 1
            autoStart: false
        }
    }

    GridView {
        id: grid
        anchors.centerIn: parent
        width: 140
        height: 140
        cellWidth: 140
        cellHeight: 140
        model: testModel
        interactive: false

        delegate: IconItemDelegate {
            objectName: "iconDelegate"
            width: grid.cellWidth
            height: grid.cellHeight
            padding: 5
            iconSource: iconName
            dndEnabled: true
            Drag.mimeData: Helper.generateDragMimeData(model.desktopId)

            onItemClicked: testCase.itemClickCount += 1
            onMenuTriggered: testCase.menuTriggerCount += 1
        }
    }

    DropArea {
        id: dropProbe
        x: 240
        y: 40
        width: 70
        height: 140
        z: 10000
        keys: ["text/x-dde-launcher-dnd-desktopId"]

        onEntered: function(drag) {
            testCase.dropEnteredId = Helper.dragDesktopId(drag)
        }

        onPositionChanged: function(drag) {
            testCase.dropEnteredId = Helper.dragDesktopId(drag)
        }
    }

    function init() {
        itemClickCount = 0
        menuTriggerCount = 0
        dropEnteredId = ""
        dndItem.Drag.active = false
        dndItem.currentlyDraggedId = ""
        dndItem.currentlyDraggedIconName = ""
        dndItem.liveReorderKey = ""
    }

    function cleanup() {
        mouseRelease(testCase, width / 2, height / 2, Qt.LeftButton)
        dndItem.Drag.active = false
        dndItem.currentlyDraggedId = ""
        dndItem.currentlyDraggedIconName = ""
        dndItem.liveReorderKey = ""
    }

    function delegateItem() {
        const item = findChild(grid, "iconDelegate")
        verify(item !== null)
        return item
    }

    function test_rightButtonLayerDoesNotBlockLeftClick() {
        waitForRendering(grid)
        const item = delegateItem()

        mouseClick(item, item.width / 2, item.height / 2, Qt.LeftButton)

        compare(itemClickCount, 1)
        compare(menuTriggerCount, 0)
    }

    function test_rightClickTriggersMenu() {
        waitForRendering(grid)
        const item = delegateItem()

        mouseClick(item, item.width / 2, item.height / 2, Qt.RightButton)

        compare(itemClickCount, 0)
        compare(menuTriggerCount, 1)
    }

    function test_centerPressCanStartProxyDrag() {
        waitForRendering(grid)
        const item = delegateItem()

        mousePress(item, item.width / 2, item.height / 2, Qt.LeftButton)
        mouseMove(item, item.width / 2 + 28, item.height / 2, 20)
        tryCompare(dndItem, "currentlyDraggedId", "demo.desktop", 1000)
        tryVerify(function() { return dndItem.visible }, 1000)
        tryVerify(function() { return dndItem.Drag.active }, 1000)
        verify(dndItem.Drag.keys.indexOf("text/x-dde-launcher-dnd-desktopId") !== -1)
        compare(Helper.dragDesktopId({
            getDataAsString: function() { return "" },
            source: dndItem
        }), "demo.desktop")
        mouseRelease(item, item.width / 2 + 28, item.height / 2, Qt.LeftButton)
        tryVerify(function() { return !dndItem.Drag.active }, 1000)
        tryCompare(dndItem, "currentlyDraggedId", "", 1000)
    }
}
