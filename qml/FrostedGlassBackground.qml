// SPDX-FileCopyrightText: 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Effects

Item {
    id: root

    property Item sourceItem: null
    property real radius: Math.min(width, height) / 2
    property color fallbackColor: Qt.rgba(1, 1, 1, 0.12)
    property color tintColor: Qt.rgba(1, 1, 1, 0.08)
    property color borderColor: Qt.rgba(1, 1, 1, 0.12)
    property real blurMultiplier: 0.22
    property real brightness: 0.0
    property real saturation: 1.0
    property bool live: true
    property real devicePixelRatio: Screen.devicePixelRatio
    property real sampleRevision: 0

    Behavior on brightness {
        NumberAnimation {
            duration: 120 * LauncherController.animationSpeedScale
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.sourceItem === null
        radius: root.radius
        color: root.fallbackColor
        antialiasing: true
    }

    Item {
        id: blurLayer
        anchors.fill: parent
        visible: root.sourceItem !== null
        clip: true

        readonly property point sourceOrigin: root.sourceItem
            ? (root.sampleRevision, root.x, root.y, root.width, root.height, root.mapToItem(root.sourceItem, 0, 0))
            : Qt.point(0, 0)
        readonly property real rawCaptureLeft: sourceOrigin.x
        readonly property real rawCaptureTop: sourceOrigin.y
        readonly property real captureLeft: root.sourceItem
            ? Math.min(
                Math.max(0, root.sourceItem.width - (1 / root.devicePixelRatio)),
                Math.max(0, Math.round(rawCaptureLeft * root.devicePixelRatio) / root.devicePixelRatio)
            )
            : 0
        readonly property real captureTop: root.sourceItem
            ? Math.min(
                Math.max(0, root.sourceItem.height - (1 / root.devicePixelRatio)),
                Math.max(0, Math.round(rawCaptureTop * root.devicePixelRatio) / root.devicePixelRatio)
            )
            : 0
        readonly property real captureRight: root.sourceItem
            ? Math.min(
                root.sourceItem.width,
                Math.max(captureLeft + 1, rawCaptureLeft + root.width)
            )
            : root.width
        readonly property real captureBottom: root.sourceItem
            ? Math.min(
                root.sourceItem.height,
                Math.max(captureTop + 1, rawCaptureTop + root.height)
            )
            : root.height
        readonly property real captureWidth: root.sourceItem
            ? Math.max(1, captureRight - captureLeft)
            : Math.max(1, root.width)
        readonly property real captureHeight: root.sourceItem
            ? Math.max(1, captureBottom - captureTop)
            : Math.max(1, root.height)
        readonly property real captureOffsetX: Math.round((captureLeft - rawCaptureLeft) * root.devicePixelRatio)
            / root.devicePixelRatio
        readonly property real captureOffsetY: Math.round((captureTop - rawCaptureTop) * root.devicePixelRatio)
            / root.devicePixelRatio

        ShaderEffectSource {
            id: backdropCapture
            x: blurLayer.captureOffsetX
            y: blurLayer.captureOffsetY
            width: blurLayer.captureWidth
            height: blurLayer.captureHeight
            visible: false
            live: root.live
            hideSource: false
            recursive: false
            smooth: true
            mipmap: true
            sourceItem: root.sourceItem
            sourceRect: Qt.rect(
                blurLayer.captureLeft,
                blurLayer.captureTop,
                blurLayer.captureWidth,
                blurLayer.captureHeight
            )
            textureSize: Qt.size(
                Math.max(16, Math.ceil(root.width * root.devicePixelRatio)),
                Math.max(16, Math.ceil(root.height * root.devicePixelRatio))
            )
        }

        Item {
            id: glassMask
            anchors.fill: parent
            visible: false
            layer.enabled: true

            Rectangle {
                anchors.fill: parent
                radius: root.radius
                color: "#FFFFFFFF"
                antialiasing: true
            }
        }

        MultiEffect {
            x: blurLayer.captureOffsetX
            y: blurLayer.captureOffsetY
            width: blurLayer.captureWidth
            height: blurLayer.captureHeight
            source: backdropCapture
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blurMultiplier: root.blurMultiplier
            blur: 1.0
            brightness: root.brightness
            saturation: root.saturation
            maskEnabled: true
            maskSource: glassMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.tintColor
        border.width: 1
        border.color: root.borderColor
        antialiasing: true
    }
}
