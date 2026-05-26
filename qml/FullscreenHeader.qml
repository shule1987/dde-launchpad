// SPDX-FileCopyrightText: 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQml 2.15
import QtQuick 2.15
import QtQuick.Controls 2.15
import org.deepin.dtk 1.0

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

    MouseArea {
        anchors.fill: parent
        z: 100
        acceptedButtons: Qt.LeftButton
        onClicked: {
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
        icon.width: 20
        icon.height: 20
        ToolTip.visible: hovered
        ToolTip.delay: 500
        ToolTip.text: qsTr("Window Mode")
        background: FrostedGlassBackground {
            radius: 20
            sourceItem: root.glassSourceItem
            sampleRevision: root.glassSampleRevision
            live: root.glassLive
            effectEnabled: root.glassEffect
            textureScale: 0.5
            brightness: exitFullscreenBtn.down ? -0.1 : exitFullscreenBtn.hovered ? 0.2 : 0.0
            tintColor: Qt.rgba(1, 1, 1, exitFullscreenBtn.down ? 0.16 : exitFullscreenBtn.hovered ? 0.12 : 0.08)
            borderColor: Qt.rgba(1, 1, 1, 0.12)
        }
        onClicked: root.exitRequested()
    }

    PageIndicator {
        id: indicator
        z: 101
        anchors.centerIn: parent
        visible: !root.searchActive && root.pageView && root.pageView.count > 1
        count: root.pageView ? root.pageView.count : 0
        interactive: visible
        spacing: 10

        Binding {
            target: indicator
            property: "currentIndex"
            value: root.pageView ? root.pageView.currentIndex : 0
        }

        delegate: Rectangle {
            width: index === indicator.currentIndex ? 20 : 8
            height: 8
            radius: height / 2
            color: index === indicator.currentIndex
                ? Qt.rgba(255, 255, 255, 0.9)
                : Qt.rgba(255, 255, 255, pressed ? 0.18 : 0.05)

            FrostedGlassBackground {
                anchors.fill: parent
                visible: index !== indicator.currentIndex
                radius: parent.radius
                sourceItem: root.glassSourceItem
                sampleRevision: root.glassSampleRevision
                live: root.glassLive
                effectEnabled: root.glassEffect
                textureScale: 0.5
                tintColor: Qt.rgba(1, 1, 1, pressed ? 0.14 : 0.08)
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

        onCurrentIndexChanged: {
            if (!root.pageView || root.pageView.currentIndex === currentIndex) {
                return
            }

            root.pageView.changedByNonKeyboard = true
            root.pageView.setCurrentIndex(currentIndex)
        }
    }
}
