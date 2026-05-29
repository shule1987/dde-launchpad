// SPDX-FileCopyrightText: 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQml 2.15
import QtQuick 2.15
import QtQuick.Controls 2.15
import org.deepin.dtk 1.0
import org.deepin.launchpad 1.0

Item {
    id: root

    required property real bandHeight
    required property bool searchActive
    required property var pageView
    required property Item glassSourceItem
    required property real glassSampleRevision
    required property bool glassLive
    required property bool glassEffect

    signal exitRequested()
    height: bandHeight
    readonly property real indicatorHitPadding: 4
    readonly property real indicatorHoverScale: 1.5
    readonly property real indicatorSpacing: 10
    readonly property real indicatorActiveWidth: 20
    readonly property real indicatorInactiveWidth: 8
    readonly property real indicatorDotHeight: 8
    readonly property int indicatorPageCount: root.pageView ? root.pageView.count : 0
    readonly property int indicatorCurrentIndex: root.pageView ? root.pageView.currentIndex : 0
    readonly property real indicatorBaseWidth: indicatorPageCount > 0
        ? indicatorActiveWidth + Math.max(0, indicatorPageCount - 1) * (indicatorInactiveWidth + indicatorSpacing)
        : 0

    function pointInPageIndicator(x, y) {
        const shellPoint = indicatorShell.mapFromItem(root, x, y)
        return indicatorShell.visible
            && shellPoint.x >= 0
            && shellPoint.x <= indicatorShell.width
            && shellPoint.y >= 0
            && shellPoint.y <= indicatorShell.height
    }

    function pointInInteractiveArea(x, y) {
        return pointInPageIndicator(x, y)
            || (x >= exitFullscreenBtn.x
                && x <= exitFullscreenBtn.x + exitFullscreenBtn.width
                && y >= exitFullscreenBtn.y
                && y <= exitFullscreenBtn.y + exitFullscreenBtn.height)
    }

    function switchPageIndicatorAt(x, y) {
        if (!pointInPageIndicator(x, y)) {
            return false
        }

        indicator.switchToPage(indicator.pageIndexAtPoint(x, y))
        return true
    }

    MouseArea {
        anchors.fill: parent
        z: 100
        acceptedButtons: Qt.LeftButton
        onClicked: function(mouse) {
            if (root.switchPageIndicatorAt(mouse.x, mouse.y)) {
                mouse.accepted = true
                return
            }
            if (root.pointInInteractiveArea(mouse.x, mouse.y)) {
                mouse.accepted = true
                return
            }
            if (!DebugHelper.avoidHideWindow) {
                LauncherController.visible = false
            }
        }
    }

    ToolButton {
        id: exitFullscreenBtn
        z: 101
        anchors.right: parent.right
        anchors.rightMargin: 30
        anchors.top: parent.top
        anchors.topMargin: 30
        width: 40
        height: 40
        hoverEnabled: true
        Accessible.name: "Exit fullscreen"
        ColorSelector.family: Palette.CrystalColor
        icon.name: "launcher_exit_fullscreen"
        icon.width: 16
        icon.height: 16
        ToolTip.visible: hovered
        ToolTip.delay: 500
        ToolTip.text: qsTr("Window Mode")
        background: FrostedGlassBackground {
            radius: 20
            visible: exitFullscreenBtn.down || exitFullscreenBtn.hovered || exitFullscreenBtn.visualFocus
            sourceItem: root.glassSourceItem
            sampleRevision: root.glassSampleRevision
            live: root.glassLive
            effectEnabled: root.glassEffect
            textureScale: 0.5
            brightness: exitFullscreenBtn.down ? -0.1 : exitFullscreenBtn.hovered ? 0.2 : 0.0
            tintColor: Qt.rgba(1, 1, 1, exitFullscreenBtn.down ? 0.16 : exitFullscreenBtn.hovered ? 0.12 : 0.0)
            borderColor: exitFullscreenBtn.down || exitFullscreenBtn.hovered || exitFullscreenBtn.visualFocus ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
        }
        onClicked: root.exitRequested()
    }

    Item {
        id: indicatorShell
        z: 101
        anchors.centerIn: parent
        visible: root.indicatorPageCount > 1
        width: (root.indicatorBaseWidth + root.indicatorHitPadding * 2) * root.indicatorHoverScale
        height: (root.indicatorDotHeight + root.indicatorHitPadding * 2) * root.indicatorHoverScale

        FrostedGlassBackground {
            id: indicatorHoverBackground
            objectName: "fullscreenPageIndicatorHoverBackground"
            z: 0
            anchors.centerIn: parent
            width: root.indicatorBaseWidth + root.indicatorHitPadding * 2
            height: root.indicatorDotHeight + root.indicatorHitPadding * 2
            scale: indicatorMouseArea.containsMouse || indicatorMouseArea.pressed ? root.indicatorHoverScale : 1
            transformOrigin: Item.Center
            visible: opacity > 0
            opacity: indicatorMouseArea.containsMouse || indicatorMouseArea.pressed ? 1 : 0
            radius: height / 2
            sourceItem: root.glassSourceItem
            sampleRevision: root.glassSampleRevision
            live: root.glassLive
            effectEnabled: root.glassEffect
            textureScale: 0.5
            tintColor: Qt.rgba(1, 1, 1, indicatorMouseArea.pressed ? 0.14 : 0.08)
            borderColor: Qt.rgba(1, 1, 1, 0.12)

            Behavior on scale {
                NumberAnimation {
                    duration: 140 * LauncherController.animationSpeedScale
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 120 * LauncherController.animationSpeedScale
                    easing.type: Easing.OutCubic
                }
            }
        }

        MouseArea {
            id: indicatorMouseArea
            z: 100
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            preventStealing: true

            onPressed: function(mouse) {
                LauncherController.suppressNextHideForInputFocus()
                indicator.switchToPage(indicator.pageIndexAtPoint(mouse.x, mouse.y, indicatorShell))
                mouse.accepted = true
            }

            onClicked: function(mouse) {
                indicator.switchToPage(indicator.pageIndexAtPoint(mouse.x, mouse.y, indicatorShell))
                mouse.accepted = true
            }
        }
    }

    PageIndicator {
        id: indicator
        objectName: "fullscreenPageIndicator"
        z: 20
        parent: indicatorShell
        anchors.centerIn: parent
        width: root.indicatorBaseWidth
        height: root.indicatorDotHeight
        scale: indicatorMouseArea.containsMouse || indicatorMouseArea.pressed ? root.indicatorHoverScale : 1
        transformOrigin: Item.Center
        count: root.indicatorPageCount
        currentIndex: root.indicatorCurrentIndex
        interactive: false
        padding: 0
        spacing: root.indicatorSpacing

        Behavior on scale {
            NumberAnimation {
                duration: 140 * LauncherController.animationSpeedScale
                easing.type: Easing.OutCubic
            }
        }

        function switchToPage(pageIndex) {
            if (!root.pageView || pageIndex < 0 || pageIndex >= root.pageView.count) {
                return
            }
            if (root.pageView.currentIndex !== pageIndex) {
                root.pageView.changedByNonKeyboard = true
                root.pageView.setCurrentIndex(pageIndex)
            }
        }

        function pageIndexAtPoint(x, y, sourceItem) {
            const indicatorPoint = sourceItem
                ? indicator.mapFromItem(sourceItem, x, y)
                : indicator.mapFromItem(root, x, y)
            if (root.indicatorPageCount <= 0
                    || indicatorPoint.x < -root.indicatorHitPadding / indicator.scale
                    || indicatorPoint.x > indicator.width + root.indicatorHitPadding / indicator.scale
                    || indicatorPoint.y < -root.indicatorHitPadding / indicator.scale
                    || indicatorPoint.y > indicator.height + root.indicatorHitPadding / indicator.scale) {
                return -1
            }

            const rowLocalX = Math.max(0, Math.min(indicator.width, indicatorPoint.x))
            let itemLeft = 0
            let nearestIndex = 0
            let nearestDistance = Number.MAX_VALUE
            for (let i = 0; i < root.indicatorPageCount; i += 1) {
                const itemWidth = i === root.indicatorCurrentIndex
                    ? root.indicatorActiveWidth
                    : root.indicatorInactiveWidth
                const itemCenter = itemLeft + itemWidth / 2
                const distance = Math.abs(rowLocalX - itemCenter)
                if (distance < nearestDistance) {
                    nearestDistance = distance
                    nearestIndex = i
                }
                itemLeft += itemWidth + root.indicatorSpacing
            }

            return nearestIndex
        }

        delegate: Rectangle {
            id: indicatorDelegate
            required property int index
            readonly property bool selected: index === indicator.currentIndex

            width: selected ? root.indicatorActiveWidth : root.indicatorInactiveWidth
            height: root.indicatorDotHeight
            radius: height / 2
            color: selected
                ? Qt.rgba(255, 255, 255, 0.9)
                : Qt.rgba(255, 255, 255, indicatorMouseArea.pressed ? 0.18 : 0.05)

            FrostedGlassBackground {
                anchors.fill: parent
                visible: !indicatorDelegate.selected
                radius: parent.radius
                sourceItem: root.glassSourceItem
                sampleRevision: root.glassSampleRevision
                live: root.glassLive
                effectEnabled: root.glassEffect
                textureScale: 0.5
                tintColor: Qt.rgba(1, 1, 1, indicatorMouseArea.pressed ? 0.14 : 0.08)
                borderColor: Qt.rgba(1, 1, 1, 0.12)
            }

            Behavior on width {
                NumberAnimation {
                    duration: 160 * LauncherController.animationSpeedScale
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: 160 * LauncherController.animationSpeedScale
                    easing.type: Easing.OutCubic
                }
            }

            OutsideBoxBorder {
                anchors.fill: parent
                radius: parent.radius
                width: 1
                color: Qt.rgba(0, 0, 0, 0.1)
            }

        }
    }
}
