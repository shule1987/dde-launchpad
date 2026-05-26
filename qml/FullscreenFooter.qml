// SPDX-FileCopyrightText: 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15
import QtQuick.Controls 2.15
import org.deepin.dtk 1.0

import org.deepin.launchpad.models 1.0

Item {
    id: root

    required property real bandHeight
    required property real maxSearchWidth
    required property real dimProgress
    required property var pageView
    required property var searchGrid
    required property int searchResultCount
    required property Item glassSourceItem
    required property real glassSampleRevision
    required property bool glassLive
    required property bool glassEffect

    property alias searchEdit: searchEdit

    height: bandHeight

    function pointInSearchEdit(x, y) {
        return x >= searchEdit.x
            && x <= searchEdit.x + searchEdit.width
            && y >= searchEdit.y
            && y <= searchEdit.y + searchEdit.height
    }

    MouseArea {
        anchors.fill: parent
        z: 100
        acceptedButtons: Qt.LeftButton
        onClicked: function(mouse) {
            if (root.pointInSearchEdit(mouse.x, mouse.y)) {
                return
            }
            if (!DebugHelper.avoidHideWindow) {
                LauncherController.visible = false
            }
        }
    }

    SearchEdit {
        id: searchEdit
        z: 101
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(280, root.maxSearchWidth)
        height: 40
        implicitHeight: 40
        opacity: 1

        property Palette iconPalette: Palette {
            normal {
                crystal: Qt.rgba(0, 0, 0, 1)
            }
            normalDark {
                crystal: Qt.rgba(1, 1, 1, 1)
            }
        }

        placeholderTextColor: palette.brightText
        palette.windowText: ColorSelector.iconPalette
        rightPadding: clearButtonSlot.visible ? clearButtonSlot.width + 8 : 10
        background: FrostedGlassBackground {
            implicitWidth: searchEdit.width
            implicitHeight: searchEdit.height
            radius: 12
            sourceItem: root.glassSourceItem
            sampleRevision: root.glassSampleRevision
            live: root.glassLive
            effectEnabled: root.glassEffect
            textureScale: 0.5
            tintColor: Qt.rgba(1, 1, 1, 0.08)
            borderColor: Qt.rgba(1, 1, 1, 0.12)
        }

        KeyNavigation.up: searchEdit.text === "" ? root.pageView : root.searchGrid
        KeyNavigation.down: KeyNavigation.up

        Keys.onReturnPressed: {
            if (searchEdit.text === "") {
                if (root.pageView) {
                    root.pageView.focus = true
                }
            } else {
                root.searchGrid.currentItem?.itemClicked()
            }
        }

        onTextChanged: {
            searchEdit.focus = true
            SearchFilterProxyModel.setFilterRegularExpression(text.trim())
            if (text !== "" && root.searchResultCount > 0) {
                root.searchGrid.currentIndex = 0
            }
        }

        Component.onCompleted: {
            if (clearButton) {
                clearButton.visible = false
            }
        }

        Item {
            id: clearButtonSlot
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            z: 1000
            visible: searchEdit.text.length > 0

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: clearButtonMouseArea.pressed
                    ? Qt.rgba(1, 1, 1, 0.10)
                    : clearButtonMouseArea.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.18)
                        : "transparent"
            }

            Canvas {
                anchors.centerIn: parent
                width: 16
                height: 16
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = "#FFFFFFFF"
                    ctx.lineWidth = 1.8
                    ctx.lineCap = "round"
                    ctx.beginPath()
                    ctx.moveTo(5, 5)
                    ctx.lineTo(11, 11)
                    ctx.moveTo(11, 5)
                    ctx.lineTo(5, 11)
                    ctx.stroke()
                }
            }

            MouseArea {
                id: clearButtonMouseArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                hoverEnabled: true
                preventStealing: true

                onPressed: function(mouse) {
                    mouse.accepted = true
                }

                onClicked: function(mouse) {
                    searchEdit.clear()
                    searchEdit.forceActiveFocus(Qt.MouseFocusReason)
                    mouse.accepted = true
                }
            }
        }
    }

    MouseArea {
        anchors.fill: searchEdit
        z: 102
        enabled: !searchEdit.activeFocus && searchEdit.text === ""
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        preventStealing: true
        onPressed: function(mouse) {
            mouse.accepted = true
            searchEdit.forceActiveFocus()
        }
        onWheel: function(wheel) {
            wheel.accepted = true
        }
    }

}
