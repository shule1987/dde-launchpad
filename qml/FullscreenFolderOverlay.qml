// SPDX-FileCopyrightText: 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import QtQuick.Effects
import org.deepin.dtk 1.0

import org.deepin.launchpad 1.0
import org.deepin.launchpad.models 1.0

FocusScope {
    id: root

    property int currentFolderId: -1
    property alias innerItem: folderLoader.item
    property string folderName: "Sample Text"
    property var currentDragItem: null
    property Item backgroundSourceItem: null
    property Item iconBlurSourceItem: null
    property real contentRevealProgress: 0
    property real backgroundMorphProgress: 0
    property real externalDimProgress: 0
    property real sourcePreviewOpacity: 0
    property var sourceIcons: []
    property var sourcePreviewIconRects: []
    property var folderNameFont: DTK.fontManager.t2
    property int cs: 110
    property real folderCellWidth: cs
    property real folderCellHeight: cs
    property real startPointX: 0
    property real startPointY: 0
    property point endPoint: Qt.point(width / 2, height / 2)
    property real sourceRectX: 0
    property real sourceRectY: 0
    property real sourceRectWidth: Math.max(cs * 0.5, 1)
    property real sourceRectHeight: sourceRectWidth
    property real sourceCornerRadius: 12
    property real panelX: sourceRectX
    property real panelY: sourceRectY
    property real panelCurrentWidth: sourceRectWidth
    property real panelCurrentHeight: sourceRectHeight
    property real panelRadius: sourceCornerRadius
    property real iconMorphProgress: 0
    property bool iconMorphClosing: false
    property bool opened: visible && !closeAnimation.running
    readonly property bool animationRunning: openAnimation.running || closeAnimation.running
    property bool folderItemMoveEnabled: false
    property var dndItem: null
    property var focusTarget: null
    property var launchAppFn: null
    property var showContextMenuFn: null
    property var dropOnPageFn: null
    property var dropOnItemFn: null
    property var decrementPageIndexFn: null
    property var incrementPageIndexFn: null
    property var refreshBackgroundSourceFn: null
    property var captureBackgroundSourceFn: null
    property var prepareContentBlurSourceFn: null
    property Item folderInternalIconBlurSourceItem: null
    property real backgroundSourceOriginX: 0
    property real backgroundSourceOriginY: 0
    property real iconBlurSourceOriginX: 0
    property real iconBlurSourceOriginY: 0
    property url backgroundSnapshotUrl: ""
    property url iconBlurSnapshotUrl: ""
    property bool pendingOpenAfterSnapshot: false
    property int pendingOpenSnapshotCount: 0
    property int activeAnimationSpeedScale: 1
    property real sourceIconScaleFactor: 1.0
    readonly property real iconBlurLayerOpacity: 0.5
    readonly property int sourcePreviewGridSize: 3
    readonly property int sourcePreviewMaxIcons: sourcePreviewGridSize * sourcePreviewGridSize

    signal itemDropped(string dragId)

    function animationDuration(milliseconds) {
        return Math.max(1, Math.round(milliseconds * activeAnimationSpeedScale))
    }

    readonly property int openDuration: 178
    readonly property int closeDuration: 152
    readonly property int previewFadeDuration: 72
    readonly property int contentRevealDelay: 58
    readonly property int contentRevealDuration: 94
    readonly property int backgroundCloseDuration: 132
    readonly property int dimOpenDuration: openDuration
    readonly property int dimCloseDuration: 78
    readonly property int contentHideDuration: 78
    readonly property int previewReturnDelay: 18
    readonly property int previewReturnDuration: 92
    readonly property real panelWidth: folderCellWidth * 4 + 20
    readonly property real panelHeight: ((folderCellHeight * 3) % 2 === 0 ? (folderCellHeight * 3) : (folderCellHeight * 3 + 1)) + 130
    readonly property real devicePixelRatio: {
        const hostWindow = root.Window.window
        if (hostWindow && hostWindow.devicePixelRatio) {
            return Number(hostWindow.devicePixelRatio)
        }
        return Screen.devicePixelRatio ? Number(Screen.devicePixelRatio) : 1
    }
    readonly property real targetPanelX: Math.round(
        Math.min(
            Math.max(root.endPoint.x - root.panelWidth / 2, 0),
            Math.max(root.width - root.panelWidth, 0)
        ) * root.devicePixelRatio
    ) / root.devicePixelRatio
    readonly property real targetPanelY: Math.round(
        Math.min(
            Math.max(root.endPoint.y - root.panelHeight / 2, 0),
            Math.max(root.height - root.panelHeight, 0)
        ) * root.devicePixelRatio
    ) / root.devicePixelRatio

    anchors.fill: parent
    visible: false
    enabled: visible
    focus: visible
    z: 100

    function sourcePreviewCount() {
        return sourceIcons && sourceIcons.length !== undefined ? Math.min(sourcePreviewMaxIcons, sourceIcons.length) : 0
    }

    function finishOpenSnapshot() {
        if (!pendingOpenAfterSnapshot) {
            return
        }
        pendingOpenSnapshotCount = Math.max(0, pendingOpenSnapshotCount - 1)
        if (pendingOpenSnapshotCount === 0) {
            deferredOpenTimer.restart()
        }
    }

    function sourcePreviewIconName(index) {
        if (!sourceIcons || sourceIcons.length === undefined || index >= sourceIcons.length) {
            return ""
        }
        return sourceIcons[index]
    }

    function sourceIconRect(index) {
        if (sourcePreviewIconRects
                && sourcePreviewIconRects.length !== undefined
                && index < sourcePreviewIconRects.length) {
            return sourcePreviewIconRects[index]
        }

        const spacing = 5
        const itemWidth = Math.max(1, (sourceRectWidth - spacing * (sourcePreviewGridSize + 1)) / sourcePreviewGridSize)
        const itemHeight = Math.max(1, (sourceRectHeight - spacing * (sourcePreviewGridSize + 1)) / sourcePreviewGridSize)
        const column = index % sourcePreviewGridSize
        const row = Math.floor(index / sourcePreviewGridSize)
        const itemX = sourceRectX + spacing + column * (itemWidth + spacing)
        const itemY = sourceRectY + spacing + row * (itemHeight + spacing)
        const visualScale = Math.max(0.01, (Math.min(itemWidth, itemHeight) / 64) * sourceIconScaleFactor)
        const visualWidth = itemWidth * visualScale
        const visualHeight = itemHeight * visualScale
        return Qt.rect(
            itemX + (itemWidth - visualWidth) / 2,
            itemY + (itemHeight - visualHeight) / 2,
            visualWidth,
            visualHeight
        )
    }

    function hiddenSourceItemRect(targetRect) {
        const size = Math.max(1, Math.min(targetRect.width, targetRect.height) * 0.12)
        return Qt.rect(
            sourceRectX + sourceRectWidth / 2 - size / 2,
            sourceRectY + sourceRectHeight / 2 - size / 2,
            size,
            size
        )
    }

    function onDragEnter(item) {
        currentDragItem = item
    }

    function onDragExit(item) {
        if (currentDragItem === item) {
            currentDragItem = null
            Qt.callLater(function() {
                if (currentDragItem === null) {
                    root.close()
                }
            })
        }
    }

    function dropOnPage(dragId, dropFolderId, pageNumber) {
        if (dropOnPageFn) {
            dropOnPageFn(dragId, dropFolderId, pageNumber)
        }
    }

    function dropOnItem(dragId, dropId, op) {
        if (dropOnItemFn) {
            dropOnItemFn(dragId, dropId, op)
        }
    }

    function decrementPageIndex(pages) {
        if (decrementPageIndexFn) {
            decrementPageIndexFn(pages)
        }
    }

    function incrementPageIndex(pages) {
        if (incrementPageIndexFn) {
            incrementPageIndexFn(pages)
        }
    }

    function launchApp(desktopId) {
        if (launchAppFn) {
            launchAppFn(desktopId)
        }
    }

    function showContextMenu(item, model) {
        if (showContextMenuFn) {
            showContextMenuFn(item, model)
        }
    }

    function open() {
        if (currentFolderId === -1) {
            return
        }

        LauncherController.updateSlowLaunchAnimationFromKeyboardModifiers()
        activeAnimationSpeedScale = LauncherController.animationSpeedScale
        closeAnimation.stop()
        folderItemMoveEnableTimer.stop()
        folderItemMoveEnabled = false
        panelX = sourceRectX
        panelY = sourceRectY
        panelCurrentWidth = sourceRectWidth
        panelCurrentHeight = sourceRectHeight
        panelRadius = sourceCornerRadius
        iconMorphProgress = 0
        iconMorphClosing = false
        backgroundMorphProgress = 0
        externalDimProgress = 0
        contentRevealProgress = 0
        sourcePreviewOpacity = sourcePreviewCount() > 0 ? 1 : 0
        if (prepareContentBlurSourceFn) {
            prepareContentBlurSourceFn()
        }
        pendingOpenAfterSnapshot = true
        backgroundSnapshotUrl = ""
        pendingOpenSnapshotCount = 0

        if (captureBackgroundSourceFn) {
            pendingOpenSnapshotCount += 1
            captureBackgroundSourceFn(function(url) {
                if (!root.pendingOpenAfterSnapshot) {
                    return
                }
                root.backgroundSnapshotUrl = url
                if (url === "" || backgroundSnapshotImage.status === Image.Ready || backgroundSnapshotImage.status === Image.Error) {
                    root.finishOpenSnapshot()
                }
            })
        } else if (refreshBackgroundSourceFn) {
            refreshBackgroundSourceFn()
        }

        if (pendingOpenSnapshotCount === 0) {
            deferredOpenTimer.restart()
        } else {
            Qt.callLater(function() {
                if (root.pendingOpenAfterSnapshot && root.pendingOpenSnapshotCount === 0) {
                    deferredOpenTimer.restart()
                }
            })
        }
    }

    function close() {
        if (deferredOpenTimer.running) {
            deferredOpenTimer.stop()
            resetState()
            return
        }
        if (!visible) {
            return
        }

        LauncherController.updateSlowLaunchAnimationFromKeyboardModifiers()
        activeAnimationSpeedScale = LauncherController.animationSpeedScale
        iconMorphClosing = true
        folderItemMoveEnableTimer.stop()
        folderItemMoveEnabled = false
        openAnimation.stop()
        closeAnimation.restart()
    }

    function resetState() {
        visible = false
        currentFolderId = -1
        currentDragItem = null
        backgroundMorphProgress = 0
        externalDimProgress = 0
        contentRevealProgress = 0
        sourcePreviewOpacity = 0
        panelX = sourceRectX
        panelY = sourceRectY
        panelCurrentWidth = sourceRectWidth
        panelCurrentHeight = sourceRectHeight
        panelRadius = sourceCornerRadius
        iconMorphProgress = 0
        iconMorphClosing = false
        pendingOpenAfterSnapshot = false
        backgroundSnapshotUrl = ""
        pendingOpenSnapshotCount = 0
        folderItemMoveEnabled = false
        sourceIcons = []
        sourcePreviewIconRects = []
        sourceIconScaleFactor = 1.0
    }

    Keys.onEscapePressed: close()

    Image {
        id: backgroundSnapshotImage
        x: -width - 4096
        y: -height - 4096
        visible: source !== ""
        asynchronous: false
        cache: false
        source: root.backgroundSnapshotUrl
        width: root.backgroundSourceItem ? root.backgroundSourceItem.width : root.width
        height: root.backgroundSourceItem ? root.backgroundSourceItem.height : root.height
        fillMode: Image.Stretch
        onStatusChanged: {
            if (root.pendingOpenAfterSnapshot && (status === Image.Ready || status === Image.Error)) {
                root.finishOpenSnapshot()
            }
        }
    }

    Image {
        id: iconBlurSnapshotImage
        x: -width - 4096
        y: -height - 4096
        visible: source !== ""
        asynchronous: false
        cache: false
        source: root.iconBlurSnapshotUrl
        width: root.iconBlurSourceItem ? root.iconBlurSourceItem.width : root.width
        height: root.iconBlurSourceItem ? root.iconBlurSourceItem.height : root.height
        fillMode: Image.Stretch
        onStatusChanged: {
            if (root.pendingOpenAfterSnapshot && (status === Image.Ready || status === Image.Error)) {
                root.finishOpenSnapshot()
            }
        }
    }

    ParallelAnimation {
        id: openAnimation
        onFinished: folderItemMoveEnableTimer.restart()

        NumberAnimation {
            target: root
            property: "panelX"
            duration: root.animationDuration(root.openDuration)
            easing.type: Easing.OutQuart
            to: root.targetPanelX
        }

        NumberAnimation {
            target: root
            property: "panelY"
            duration: root.animationDuration(root.openDuration)
            easing.type: Easing.OutQuart
            to: root.targetPanelY
        }

        NumberAnimation {
            target: root
            property: "panelCurrentWidth"
            duration: root.animationDuration(root.openDuration)
            easing.type: Easing.OutQuart
            to: root.panelWidth
        }

        NumberAnimation {
            target: root
            property: "panelCurrentHeight"
            duration: root.animationDuration(root.openDuration)
            easing.type: Easing.OutQuart
            to: root.panelHeight
        }

        NumberAnimation {
            target: root
            property: "panelRadius"
            duration: root.animationDuration(root.openDuration)
            easing.type: Easing.OutQuart
            to: 24
        }

        NumberAnimation {
            target: root
            property: "backgroundMorphProgress"
            duration: root.animationDuration(root.openDuration)
            easing.type: Easing.OutQuart
            to: 1
        }

        NumberAnimation {
            target: root
            property: "iconMorphProgress"
            duration: root.animationDuration(root.openDuration)
            easing.type: Easing.OutQuart
            to: 1
        }

        NumberAnimation {
            target: root
            property: "externalDimProgress"
            duration: root.animationDuration(root.dimOpenDuration)
            easing.type: Easing.OutQuart
            to: 1
        }

        NumberAnimation {
            target: root
            property: "sourcePreviewOpacity"
            duration: root.animationDuration(root.previewFadeDuration)
            easing.type: Easing.InCubic
            to: 0
        }

        SequentialAnimation {
            PauseAnimation {
                duration: root.animationDuration(root.contentRevealDelay)
            }

            NumberAnimation {
                target: root
                property: "contentRevealProgress"
                duration: root.animationDuration(root.contentRevealDuration)
                easing.type: Easing.OutQuart
                to: 1
            }
        }
    }

    Timer {
        id: folderItemMoveEnableTimer
        interval: root.animationDuration(80)
        repeat: false
        onTriggered: {
            root.folderItemMoveEnabled = root.visible
                && !root.animationRunning
                && root.contentRevealProgress >= 1
                && !root.iconMorphClosing
        }
    }

    Timer {
        id: deferredOpenTimer
        interval: Math.max(1, Math.round(1000 / 60))
        repeat: false
        onTriggered: {
            if (root.currentFolderId === -1) {
                return
            }
            root.pendingOpenAfterSnapshot = false
            root.visible = true
            openAnimation.restart()
            root.forceActiveFocus()
        }
    }

    ParallelAnimation {
        id: closeAnimation
        onFinished: root.resetState()

        NumberAnimation {
            target: root
            property: "panelX"
            duration: root.animationDuration(root.closeDuration)
            easing.type: Easing.InQuart
            to: root.sourceRectX
        }

        NumberAnimation {
            target: root
            property: "panelY"
            duration: root.animationDuration(root.closeDuration)
            easing.type: Easing.InQuart
            to: root.sourceRectY
        }

        NumberAnimation {
            target: root
            property: "panelCurrentWidth"
            duration: root.animationDuration(root.closeDuration)
            easing.type: Easing.InQuart
            to: root.sourceRectWidth
        }

        NumberAnimation {
            target: root
            property: "panelCurrentHeight"
            duration: root.animationDuration(root.closeDuration)
            easing.type: Easing.InQuart
            to: root.sourceRectHeight
        }

        NumberAnimation {
            target: root
            property: "panelRadius"
            duration: root.animationDuration(root.closeDuration)
            easing.type: Easing.InQuart
            to: root.sourceCornerRadius
        }

        NumberAnimation {
            target: root
            property: "backgroundMorphProgress"
            duration: root.animationDuration(root.backgroundCloseDuration)
            easing.type: Easing.InQuart
            to: 0
        }

        NumberAnimation {
            target: root
            property: "iconMorphProgress"
            duration: root.animationDuration(root.closeDuration)
            easing.type: Easing.InQuart
            to: 0
        }

        NumberAnimation {
            target: root
            property: "externalDimProgress"
            duration: root.animationDuration(root.dimCloseDuration)
            easing.type: Easing.InQuad
            to: 0
        }

        SequentialAnimation {
            PauseAnimation {
                duration: root.animationDuration(root.previewReturnDelay)
            }

            NumberAnimation {
                target: root
                property: "sourcePreviewOpacity"
                duration: root.animationDuration(root.previewReturnDuration)
                easing.type: Easing.InOutCubic
                to: root.sourcePreviewCount() > 0 ? 1 : 0
            }
        }
    }

    MouseArea {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: folderPanel.top
        enabled: root.visible
        onClicked: root.close()
    }

    MouseArea {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: folderPanel.bottom
        anchors.bottom: parent.bottom
        enabled: root.visible
        onClicked: root.close()
    }

    MouseArea {
        anchors.left: parent.left
        anchors.right: folderPanel.left
        anchors.top: folderPanel.top
        anchors.bottom: folderPanel.bottom
        enabled: root.visible
        onClicked: root.close()
    }

    MouseArea {
        anchors.left: folderPanel.right
        anchors.right: parent.right
        anchors.top: folderPanel.top
        anchors.bottom: folderPanel.bottom
        enabled: root.visible
        onClicked: root.close()
    }

    Control {
        id: folderPanel

        width: Math.max(1, Math.round(root.panelCurrentWidth * root.devicePixelRatio) / root.devicePixelRatio)
        height: Math.max(1, Math.round(root.panelCurrentHeight * root.devicePixelRatio) / root.devicePixelRatio)
        x: Math.round(root.panelX * root.devicePixelRatio) / root.devicePixelRatio
        y: Math.round(root.panelY * root.devicePixelRatio) / root.devicePixelRatio
        visible: root.visible

        background: Item {
            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                radius: root.panelRadius
                color: "#26FFFFFF"
                opacity: 1 - root.backgroundMorphProgress
                antialiasing: true
            }

            Rectangle {
                anchors.fill: parent
                radius: root.panelRadius
                color: Qt.rgba(1, 1, 1, 0.10)
                opacity: root.backgroundMorphProgress
                antialiasing: true
            }

            Item {
                id: blurLayer
                anchors.fill: parent
                clip: true
                visible: root.iconBlurSourceItem !== null && opacity > 0
                opacity: Math.max(0, Math.min(1, (root.backgroundMorphProgress - 0.78) / 0.22))

                readonly property real rawCaptureLeft: root.targetPanelX - root.backgroundSourceOriginX
                readonly property real rawCaptureTop: root.targetPanelY - root.backgroundSourceOriginY
                readonly property real captureLeft: root.backgroundSourceItem
                    ? Math.max(
                        0,
                        Math.round(rawCaptureLeft * root.devicePixelRatio)
                        / root.devicePixelRatio
                    )
                    : 0
                readonly property real captureTop: root.backgroundSourceItem
                    ? Math.max(
                        0,
                        Math.round(rawCaptureTop * root.devicePixelRatio)
                        / root.devicePixelRatio
                    )
                    : 0
                readonly property real captureRight: root.backgroundSourceItem
                    ? Math.min(
                        root.backgroundSourceItem.width,
                        Math.max(captureLeft + 1, rawCaptureLeft + root.panelWidth)
                    )
                    : folderPanel.width
                readonly property real captureBottom: root.backgroundSourceItem
                    ? Math.min(
                        root.backgroundSourceItem.height,
                        Math.max(captureTop + 1, rawCaptureTop + root.panelHeight)
                    )
                    : folderPanel.height
                readonly property real captureWidth: root.backgroundSourceItem
                    ? Math.max(
                        1,
                        captureRight - captureLeft
                    )
                    : Math.max(1, folderPanel.width)
                readonly property real captureHeight: root.backgroundSourceItem
                    ? Math.max(
                        1,
                        captureBottom - captureTop
                    )
                    : Math.max(1, folderPanel.height)
                readonly property real captureOffsetX: Math.round((captureLeft - rawCaptureLeft + root.targetPanelX - folderPanel.x) * root.devicePixelRatio)
                    / root.devicePixelRatio
                readonly property real captureOffsetY: Math.round((captureTop - rawCaptureTop + root.targetPanelY - folderPanel.y) * root.devicePixelRatio)
                    / root.devicePixelRatio
                readonly property Item effectiveBackgroundSourceItem: backgroundSnapshotImage.status === Image.Ready
                    ? backgroundSnapshotImage
                    : root.backgroundSourceItem
                readonly property Item effectiveIconBlurSourceItem: iconBlurSnapshotImage.status === Image.Ready
                    ? iconBlurSnapshotImage
                    : root.iconBlurSourceItem
                readonly property bool hasIconBlurSource: root.iconBlurSourceItem !== null
                readonly property bool hasFolderIconBlurSource: root.folderInternalIconBlurSourceItem !== null
                readonly property point folderIconBlurOrigin: hasFolderIconBlurSource
                    ? root.folderInternalIconBlurSourceItem.mapToItem(folderPanel, 0, 0)
                    : Qt.point(0, 0)
                readonly property real iconRawCaptureLeft: root.targetPanelX - root.iconBlurSourceOriginX
                readonly property real iconRawCaptureTop: root.targetPanelY - root.iconBlurSourceOriginY
                readonly property real iconCaptureLeft: hasIconBlurSource
                    ? Math.max(
                        0,
                        Math.round(iconRawCaptureLeft * root.devicePixelRatio)
                        / root.devicePixelRatio
                    )
                    : 0
                readonly property real iconCaptureTop: hasIconBlurSource
                    ? Math.max(
                        0,
                        Math.round(iconRawCaptureTop * root.devicePixelRatio)
                        / root.devicePixelRatio
                    )
                    : 0
                readonly property real iconCaptureRight: hasIconBlurSource
                    ? Math.min(
                        root.iconBlurSourceItem.width,
                        Math.max(iconCaptureLeft + 1, iconRawCaptureLeft + root.panelWidth)
                    )
                    : folderPanel.width
                readonly property real iconCaptureBottom: hasIconBlurSource
                    ? Math.min(
                        root.iconBlurSourceItem.height,
                        Math.max(iconCaptureTop + 1, iconRawCaptureTop + root.panelHeight)
                    )
                    : folderPanel.height
                readonly property real iconCaptureWidth: hasIconBlurSource
                    ? Math.max(1, iconCaptureRight - iconCaptureLeft)
                    : Math.max(1, folderPanel.width)
                readonly property real iconCaptureHeight: hasIconBlurSource
                    ? Math.max(1, iconCaptureBottom - iconCaptureTop)
                    : Math.max(1, folderPanel.height)
                readonly property real iconCaptureOffsetX: Math.round((iconCaptureLeft - iconRawCaptureLeft + root.targetPanelX - folderPanel.x) * root.devicePixelRatio)
                    / root.devicePixelRatio
                readonly property real iconCaptureOffsetY: Math.round((iconCaptureTop - iconRawCaptureTop + root.targetPanelY - folderPanel.y) * root.devicePixelRatio)
                    / root.devicePixelRatio

                Item {
                    id: capturedBlurSurface
                    x: blurLayer.captureOffsetX
                    y: blurLayer.captureOffsetY
                    width: blurLayer.captureWidth
                    height: blurLayer.captureHeight
                    visible: false
                    clip: true

                    ShaderEffectSource {
                        id: backdropCapture
                        anchors.fill: parent
                        visible: false
                        live: false
                        hideSource: false
                        recursive: false
                        smooth: true
                        mipmap: false
                        sourceItem: blurLayer.effectiveBackgroundSourceItem
                        sourceRect: Qt.rect(
                            blurLayer.captureLeft,
                            blurLayer.captureTop,
                            blurLayer.captureWidth,
                            blurLayer.captureHeight
                        )
                        textureSize: Qt.size(
                            Math.max(64, Math.ceil(root.panelWidth * root.devicePixelRatio)),
                            Math.max(64, Math.ceil(root.panelHeight * root.devicePixelRatio))
                        )
                    }

                    Item {
                        id: folderMask
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true

                        Rectangle {
                            anchors.fill: parent
                            radius: root.panelRadius
                            color: "#FFFFFFFF"
                            antialiasing: true
                        }
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: backdropCapture
                        autoPaddingEnabled: false
                        blurEnabled: false
                        blurMax: 64
                        blurMultiplier: 0.22
                        blur: 1.0
                        saturation: 1.15
                        maskEnabled: true
                        maskSource: folderMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }
                }

                Item {
                    id: capturedIconBlurSurface
                    x: blurLayer.iconCaptureOffsetX
                    y: blurLayer.iconCaptureOffsetY
                    width: blurLayer.iconCaptureWidth
                    height: blurLayer.iconCaptureHeight
                    visible: blurLayer.hasIconBlurSource && opacity > 0
                    opacity: root.iconBlurLayerOpacity
                    clip: true

                    ShaderEffectSource {
                        id: iconLayerCapture
                        anchors.fill: parent
                        visible: false
                        live: false
                        hideSource: false
                        recursive: false
                        smooth: true
                        mipmap: false
                        sourceItem: blurLayer.effectiveIconBlurSourceItem
                        sourceRect: Qt.rect(
                            blurLayer.iconCaptureLeft,
                            blurLayer.iconCaptureTop,
                            blurLayer.iconCaptureWidth,
                            blurLayer.iconCaptureHeight
                        )
                        textureSize: Qt.size(
                            Math.max(64, Math.ceil(root.panelWidth * root.devicePixelRatio)),
                            Math.max(64, Math.ceil(root.panelHeight * root.devicePixelRatio))
                        )
                    }

                    Item {
                        id: iconLayerMask
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true

                        Rectangle {
                            anchors.fill: parent
                            radius: root.panelRadius
                            color: "#FFFFFFFF"
                            antialiasing: true
                        }
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: iconLayerCapture
                        autoPaddingEnabled: false
                        blurEnabled: true
                        blurMax: 64
                        blurMultiplier: 0.22
                        blur: 1.0
                        saturation: 1.0
                        maskEnabled: true
                        maskSource: iconLayerMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }
                }

                Item {
                    id: capturedFolderIconBlurSurface
                    x: blurLayer.folderIconBlurOrigin.x
                    y: blurLayer.folderIconBlurOrigin.y
                    width: root.folderInternalIconBlurSourceItem
                        ? root.folderInternalIconBlurSourceItem.width
                        : 1
                    height: root.folderInternalIconBlurSourceItem
                        ? root.folderInternalIconBlurSourceItem.height
                        : 1
                    visible: false
                    opacity: root.iconBlurLayerOpacity * root.contentRevealProgress
                    clip: true

                    ShaderEffectSource {
                        id: folderIconLayerCapture
                        anchors.fill: parent
                        visible: false
                        live: root.visible
                        hideSource: false
                        recursive: false
                        smooth: true
                        mipmap: false
                        sourceItem: root.folderInternalIconBlurSourceItem
                        sourceRect: Qt.rect(
                            0,
                            0,
                            capturedFolderIconBlurSurface.width,
                            capturedFolderIconBlurSurface.height
                        )
                        textureSize: Qt.size(
                            Math.max(64, Math.ceil(capturedFolderIconBlurSurface.width * root.devicePixelRatio)),
                            Math.max(64, Math.ceil(capturedFolderIconBlurSurface.height * root.devicePixelRatio))
                        )
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: folderIconLayerCapture
                        autoPaddingEnabled: false
                        blurEnabled: true
                        blurMax: 64
                        blurMultiplier: 0.22
                        blur: 1.0
                        saturation: 1.0
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: root.backgroundSourceItem === null && opacity > 0
                opacity: root.backgroundMorphProgress
                radius: root.panelRadius
                color: Qt.rgba(0, 0, 0, 0.1)
                antialiasing: true
            }

            Rectangle {
                anchors.fill: parent
                radius: root.panelRadius
                color: "transparent"
                opacity: root.backgroundMorphProgress
                antialiasing: true
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)
            }

            Item {
                id: sourcePreview
                anchors.centerIn: parent
                width: Math.min(root.sourceRectWidth, parent.width)
                height: Math.min(root.sourceRectHeight, parent.height)
                visible: false
                opacity: root.sourcePreviewOpacity * Math.max(0, 1 - root.contentRevealProgress * 4)
                scale: 0.975 + (root.sourcePreviewOpacity * 0.025)

                readonly property real previewSpacing: 5
                readonly property real previewItemWidth: Math.max(1, (width - previewSpacing * (root.sourcePreviewGridSize + 1)) / root.sourcePreviewGridSize)
                readonly property real previewItemHeight: Math.max(1, (height - previewSpacing * (root.sourcePreviewGridSize + 1)) / root.sourcePreviewGridSize)

                function itemX(index) {
                    const column = index % root.sourcePreviewGridSize
                    return previewSpacing + column * (previewItemWidth + previewSpacing)
                }

                function itemY(index) {
                    const row = Math.floor(index / root.sourcePreviewGridSize)
                    return previewSpacing + row * (previewItemHeight + previewSpacing)
                }

                Repeater {
                    model: root.sourcePreviewCount()

                    DciIcon {
                        x: sourcePreview.itemX(index)
                        y: sourcePreview.itemY(index)
                        width: sourcePreview.previewItemWidth
                        height: sourcePreview.previewItemHeight
                        name: root.sourcePreviewIconName(index)
                        sourceSize: Qt.size(64, 64)
                        scale: Math.min(width, height) / 64
                        palette: DTK.makeIconPalette(root.palette)
                        theme: ApplicationHelper.DarkType
                    }
                }
            }

            DropArea {
                anchors.fill: parent
                keys: ["text/x-dde-launcher-dnd-desktopId"]
                onEntered: root.onDragEnter(this)
                onExited: root.onDragExit(this)
                onDropped: {
                    const dragId = drop.getDataAsString("text/x-dde-launcher-dnd-desktopId")
                    dropOnPage(dragId, "internal/folders/" + root.currentFolderId, folderPagesView.currentIndex)
                }
            }
        }

        contentItem: Loader {
            id: folderLoader

            active: root.currentFolderId !== -1
                    && (root.contentRevealProgress > 0 || closeAnimation.running)
            anchors.fill: parent

            sourceComponent: Item {
                anchors.fill: parent
                opacity: root.contentRevealProgress

                DropArea {
                    anchors.fill: parent
                    keys: ["text/x-dde-launcher-dnd-desktopId"]
                    onEntered: root.onDragEnter(this)
                    onExited: root.onDragExit(this)
                }

                ColumnLayout {
                    id: contentRoot
                    anchors.fill: parent
                    anchors.topMargin: 20
                    spacing: 5
                    opacity: 1
                    scale: 1
                    transformOrigin: Item.Center

                    property bool nameEditing: false
                    property int titleMargin: 30

                    property Palette titleTextColor: Palette {
                        normal {
                            common: Qt.rgba(0, 0, 0, 1)
                            crystal: Qt.rgba(0, 0, 0, 1)
                        }
                        normalDark {
                            common: Qt.rgba(1, 1, 1, 1)
                            crystal: Qt.rgba(1, 1, 1, 1)
                        }
                    }

                    TextInput {
                        id: folderNameEdit
                        Layout.fillWidth: true
                        Layout.leftMargin: contentRoot.titleMargin - folderPanel.padding
                        Layout.rightMargin: contentRoot.titleMargin - folderPanel.padding
                        visible: contentRoot.nameEditing
                        clip: true
                        font.family: root.folderNameFont.family
                        font.pixelSize: 24
                        font.weight: Font.Normal
                        font.bold: false
                        horizontalAlignment: Text.AlignHCenter
                        text: root.folderName
                        color: palette.windowText
                        selectByMouse: true
                        maximumLength: 255
                        selectionColor: palette.highlight

                        onEditingFinished: {
                            contentRoot.nameEditing = false
                            if (text === "") {
                                text = root.folderName
                                return
                            }

                            root.folderName = text
                            ItemArrangementProxyModel.updateFolderName(root.currentFolderId, text)
                        }
                    }

                    Text {
                        id: folderNameText
                        Layout.fillWidth: true
                        Layout.leftMargin: contentRoot.titleMargin - folderPanel.padding
                        Layout.rightMargin: contentRoot.titleMargin - folderPanel.padding
                        clip: true
                        font.family: root.folderNameFont.family
                        font.pixelSize: 24
                        font.weight: Font.Normal
                        font.bold: false
                        horizontalAlignment: Text.AlignHCenter
                        text: root.folderName
                        color: contentRoot.ColorSelector.titleTextColor
                        visible: !contentRoot.nameEditing
                        elide: Text.ElideRight
                        ToolTip.visible: folderNameTextMouseArea.containsMouse ? implicitWidth > width : false
                        ToolTip.delay: 500
                        ToolTip.timeout: 5000
                        ToolTip.text: text

                        MouseArea {
                            id: folderNameTextMouseArea
                            anchors.fill: parent
                            hoverEnabled: true

                            onClicked: {
                                contentRoot.nameEditing = true
                                folderNameEdit.forceActiveFocus()
                                folderNameEdit.selectAll()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "transparent"

                        Item {
                            id: wheelFocusSink
                            width: 0
                            height: 0
                        }

                        DropArea {
                            id: folderPageDropArea
                            property int pageIntent: 0
                            property bool createdEmptyPage: false
                            readonly property real paddingColumns: 0.3
                            readonly property int horizontalPadding: contentRoot.width * paddingColumns

                            anchors.fill: parent
                            keys: ["text/x-dde-launcher-dnd-desktopId"]

                            function checkDragMove() {
                                if (drag.x < horizontalPadding) {
                                    pageIntent = -1
                                } else if (drag.x > (width - horizontalPadding)) {
                                    const isLastPage = folderPagesView.currentIndex === folderPagesView.count - 1
                                    if (isLastPage && folderPageDropArea.createdEmptyPage) {
                                        return
                                    }
                                    pageIntent = 1
                                } else {
                                    pageIntent = 0
                                }
                            }

                            onEntered: root.onDragEnter(this)

                            onExited: {
                                root.onDragExit(this)
                                pageIntent = 0
                                createdEmptyPage = false
                            }

                            onPositionChanged: checkDragMove()

                            onDropped: function(drop) {
                                const dragId = drop.getDataAsString("text/x-dde-launcher-dnd-desktopId")
                                dropOnPage(dragId, "internal/folders/" + root.currentFolderId, folderPagesView.currentIndex)
                                pageIntent = 0
                                createdEmptyPage = false
                            }

                            onPageIntentChanged: {
                                if (pageIntent !== 0) {
                                    folderDndMovePageTimer.restart()
                                } else {
                                    folderDndMovePageTimer.stop()
                                }
                            }

                            Timer {
                                id: folderDndMovePageTimer
                                interval: 1000

                                onTriggered: {
                                    if (parent.pageIntent > 0) {
                                        const isLastPage = folderPagesView.currentIndex === folderPagesView.count - 1
                                        if (isLastPage && !folderPageDropArea.createdEmptyPage) {
                                            const newPageIndex = ItemArrangementProxyModel.creatEmptyPage(root.currentFolderId)
                                            folderPageDropArea.createdEmptyPage = true
                                            folderPagesView.setCurrentIndex(newPageIndex)
                                            parent.pageIntent = 0
                                            return
                                        }
                                        incrementPageIndex(folderPagesView)
                                    } else if (parent.pageIntent < 0) {
                                        decrementPageIndex(folderPagesView)
                                    }

                                    parent.pageIntent = 0
                                    if (folderPagesView.currentIndex !== 0) {
                                        parent.checkDragMove()
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            scrollGestureEnabled: false

                            onWheel: function(wheel) {
                                wheelFocusSink.forceActiveFocus()
                                const xDelta = wheel.angleDelta.x / 8
                                const yDelta = wheel.angleDelta.y / 8
                                let toPage = 0

                                if (yDelta !== 0) {
                                    toPage = yDelta > 0 ? -1 : 1
                                } else if (xDelta !== 0) {
                                    toPage = xDelta > 0 ? 1 : -1
                                }

                                if (toPage < 0) {
                                    decrementPageIndex(folderPagesView)
                                } else if (toPage > 0) {
                                    incrementPageIndex(folderPagesView)
                                }
                            }
                        }

                        SwipeView {
                            id: folderPagesView
                            anchors.fill: parent
                            clip: gridViews.count > 1
                            currentIndex: folderPageIndicator.currentIndex
                            activeFocusOnTab: false

                            property int pendingFocusIndex: 0
                            property bool pageChangedByKeyboard: false

                            onCurrentItemChanged: {
                                if (currentItem && pageChangedByKeyboard) {
                                    currentItem.resetCurrentIndex(pendingFocusIndex)
                                    pageChangedByKeyboard = false
                                }
                            }

                            Connections {
                                target: ItemArrangementProxyModel
                                function onFolderPageCountChanged(folderId) {
                                    if (folderId === root.currentFolderId) {
                                        gridViews.model = ItemArrangementProxyModel.pageCount(folderId)
                                    }
                                }
                            }

                            Repeater {
                                id: gridViews
                                model: ItemArrangementProxyModel.pageCount(root.currentFolderId)

                                Loader {
                                    id: folderGridViewLoader
                                    active: SwipeView.isCurrentItem || SwipeView.isNextItem || SwipeView.isPreviousItem
                                    objectName: "Folder GridView Loader"

                                    function resetCurrentIndex(focusIndex) {
                                        if (item && item.resetGridFocus) {
                                            item.resetGridFocus(focusIndex)
                                        }
                                    }

                                    sourceComponent: Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"

                                        function resetGridFocus(focusIndex) {
                                            if (gridViewContainerLoader && gridViewContainerLoader.item) {
                                                gridViewContainerLoader.item.forceActiveFocus()
                                                Qt.callLater(function() {
                                                    if (!gridViewContainerLoader || !gridViewContainerLoader.item) {
                                                        return
                                                    }

                                                    let count = 0
                                                    if (gridViewContainerLoader.item.model) {
                                                        if (gridViewContainerLoader.item.model.count !== undefined) {
                                                            count = gridViewContainerLoader.item.model.count
                                                        } else if (gridViewContainerLoader.item.model.rowCount) {
                                                            count = gridViewContainerLoader.item.model.rowCount()
                                                        }
                                                    }

                                                    let targetIndex = 0
                                                    if (count > 0) {
                                                        if (focusIndex < 0) {
                                                            targetIndex = count - 1
                                                        } else {
                                                            targetIndex = Math.min(focusIndex, count - 1)
                                                        }
                                                    }
                                                    gridViewContainerLoader.item.currentIndex = targetIndex
                                                    folderPagesView.pendingFocusIndex = 0
                                                })
                                            }
                                        }

                                        MultipageSortFilterProxyModel {
                                            id: folderProxyModel
                                            filterOnlyMode: true
                                            sourceModel: ItemArrangementProxyModel
                                            pageId: modelData
                                            folderId: root.currentFolderId
                                        }

                                        SortProxyModel {
                                            id: sortProxyModel
                                            sourceModel: folderProxyModel
                                            sortRole: ItemArrangementProxyModel.IndexInPageRole
                                            Component.onCompleted: sortProxyModel.sort(0)
                                        }

                                        Loader {
                                            id: gridViewContainerLoader
                                            anchors.fill: parent

                                            property Transition itemMove: Transition {
                                                NumberAnimation {
                                                    properties: "x,y"
                                                    duration: root.animationDuration(200)
                                                    easing.type: Easing.OutQuad
                                                }
                                            }

                                            sourceComponent: GridViewContainer {
                                                id: folderGridViewContainer
                                                objectName: "folderGridViewContainer"
                                                anchors.fill: parent
                                                rows: 3
                                                columns: 4
                                                model: sortProxyModel
                                                cellWidth: root.folderCellWidth
                                                cellHeight: root.folderCellHeight
                                                compactCentered: true
                                                compactItemCount: sortProxyModel.count !== undefined
                                                    ? sortProxyModel.count
                                                    : (sortProxyModel.rowCount ? sortProxyModel.rowCount() : 0)
                                                padding: 10
                                                interactive: false
                                                focus: true
                                                gridViewClip: false
                                                activeGridViewFocusOnTab: folderGridViewLoader.SwipeView.isCurrentItem
                                                itemTransitionsEnabled: root.folderItemMoveEnabled
                                                itemMove: gridViewContainerLoader.itemMove

                                                onActiveFocusChanged: {
                                                    if (activeFocus) {
                                                        currentIndex = 0
                                                    }
                                                }

                                                Keys.onLeftPressed: function(event) {
                                                    event.accepted = true

                                                    const count = sortProxyModel.count !== undefined
                                                        ? sortProxyModel.count
                                                        : (sortProxyModel.rowCount ? sortProxyModel.rowCount() : 0)
                                                    if (count === 0) {
                                                        return
                                                    }

                                                    const current = folderGridViewContainer.currentIndex
                                                    if (current > 0) {
                                                        folderGridViewContainer.currentIndex = current - 1
                                                        return
                                                    }

                                                    const pageCount = folderPagesView.count
                                                    if (pageCount <= 1) {
                                                        folderGridViewContainer.currentIndex = count - 1
                                                        return
                                                    }

                                                    folderPagesView.pendingFocusIndex = -1
                                                    folderPagesView.pageChangedByKeyboard = true
                                                    if (folderPagesView.currentIndex === 0) {
                                                        folderPagesView.setCurrentIndex(pageCount - 1)
                                                    } else {
                                                        folderPagesView.setCurrentIndex(folderPagesView.currentIndex - 1)
                                                    }
                                                }

                                                Keys.onRightPressed: function(event) {
                                                    event.accepted = true

                                                    const count = sortProxyModel.count !== undefined
                                                        ? sortProxyModel.count
                                                        : (sortProxyModel.rowCount ? sortProxyModel.rowCount() : 0)
                                                    if (count === 0) {
                                                        return
                                                    }

                                                    const current = folderGridViewContainer.currentIndex
                                                    if (current < count - 1) {
                                                        folderGridViewContainer.currentIndex = current + 1
                                                        return
                                                    }

                                                    const pageCount = folderPagesView.count
                                                    if (pageCount <= 1) {
                                                        folderGridViewContainer.currentIndex = 0
                                                        return
                                                    }

                                                    folderPagesView.pendingFocusIndex = 0
                                                    folderPagesView.pageChangedByKeyboard = true
                                                    if (folderPagesView.currentIndex === pageCount - 1) {
                                                        folderPagesView.setCurrentIndex(0)
                                                    } else {
                                                        folderPagesView.setCurrentIndex(folderPagesView.currentIndex + 1)
                                                    }
                                                }

                                                delegate: DropArea {
                                                    id: folderDelegateRoot
                                                    width: folderGridViewContainer.cellWidth
                                                    height: folderGridViewContainer.cellHeight

                                                    property bool isDragHover: false
                                                    readonly property real morphProgress: root.iconMorphProgress
                                                    readonly property real contentOpacity: index < root.sourcePreviewCount()
                                                        ? Math.max(0, Math.min(1, (morphProgress - 0.84) / 0.16))
                                                        : Math.max(0, Math.min(1, (morphProgress - 0.48) / 0.32))

                                                    onEntered: function(drag) {
                                                        root.onDragEnter(this)
                                                        const dragId = drag.getDataAsString("text/x-dde-launcher-dnd-desktopId")
                                                        if (dragId !== model.desktopId) {
                                                            isDragHover = true
                                                        }
                                                        folderDragApplyTimer.dragId = dragId
                                                        folderDragApplyTimer.restart()
                                                    }

                                                    onPositionChanged: function(drag) {
                                                        const dragId = drag.getDataAsString("text/x-dde-launcher-dnd-desktopId")
                                                        if (dragId === model.desktopId) {
                                                            return
                                                        }
                                                        folderDragApplyTimer.dragId = dragId
                                                        folderDragApplyTimer.currentDropX = drag.x
                                                        if (!folderDragApplyTimer.running) {
                                                            folderDragApplyTimer.restart()
                                                        }
                                                    }

                                                    onExited: {
                                                        isDragHover = false
                                                        root.onDragExit(this)
                                                        folderDragApplyTimer.stop()
                                                        folderDragApplyTimer.dragId = ""
                                                    }

                                                    Component.onDestruction: root.onDragExit(this)

                                                    onDropped: function(drop) {
                                                        isDragHover = false
                                                        const dragId = drop.getDataAsString("text/x-dde-launcher-dnd-desktopId")
                                                        if (dragId === "") {
                                                            return
                                                        }

                                                        if (folderDragApplyTimer.running) {
                                                            folderDragApplyTimer.stop()
                                                            root.itemDropped(dragId)
                                                        }

                                                        folderDragApplyTimer.stop()
                                                        folderDragApplyTimer.dragId = ""
                                                        if (dragId === model.desktopId) {
                                                            return
                                                        }

                                                        let op = 1
                                                        const sideOpPadding = width / 2
                                                        if (drop.x < sideOpPadding) {
                                                            op = -1
                                                        }

                                                        dropOnItem(dragId, model.desktopId, op)
                                                        sortProxyModel.sort(0)
                                                    }

                                                    Timer {
                                                        id: folderDragApplyTimer
                                                        interval: 400
                                                        property string dragId: ""
                                                        property real currentDropX: 0

                                                        onTriggered: {
                                                            if (dragId === "") {
                                                                return
                                                            }

                                                            let op = 0
                                                            const sideOpPadding = parent.width / 4
                                                            if (currentDropX < sideOpPadding) {
                                                                op = -1
                                                            } else if (currentDropX > (parent.width - sideOpPadding)) {
                                                                op = 1
                                                            }

                                                            if (op !== 0) {
                                                                dropOnItem(dragId, model.desktopId, op)
                                                                sortProxyModel.sort(0)
                                                            }
                                                        }
                                                    }

                                                    Keys.forwardTo: [iconItem]

                                                    Item {
                                                        id: itemMorphWrapper
                                                        width: parent.width
                                                        height: parent.height
                                                        opacity: folderDelegateRoot.contentOpacity
                                                            * (!root.dndItem || root.dndItem.currentlyDraggedId !== model.desktopId ? 1 : 0)

                                                        IconItemDelegate {
                                                            id: iconItem
                                                            anchors.fill: parent
                                                            dndEnabled: true
                                                            isDragHover: false
                                                            displayFont: DTK.fontManager.t6
                                                            Drag.mimeData: Helper.generateDragMimeData(model.desktopId)
                                                            iconSource: iconName
                                                            padding: 5
                                                            hoverVisualEnabled: root.iconMorphProgress >= 0.98 && !root.iconMorphClosing
                                                            labelOpacity: Math.max(0, Math.min(1, (root.iconMorphProgress - 0.72) / 0.28))

                                                            onItemClicked: launchApp(desktopId)

                                                            onMenuTriggered: {
                                                                showContextMenu(this, model)
                                                                if (root.focusTarget) {
                                                                    root.focusTarget.focus = true
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            anchors.fill: parent

                            MouseArea {
                                anchors.fill: parent
                                enabled: contentRoot.nameEditing
                                onClicked: folderNameEdit.editingFinished()
                            }
                        }
                    }

                    PageIndicator {
                        id: folderPageIndicator
                        Layout.alignment: Qt.AlignHCenter
                        visible: folderPagesView.count > 1
                        implicitHeight: implicitWidth
                        count: folderPagesView.count
                        currentIndex: folderPagesView.currentIndex
                        interactive: true
                        spacing: 10

                        delegate: Rectangle {
                            width: index === folderPageIndicator.currentIndex ? 20 : 8
                            height: 8
                            implicitWidth: width
                            implicitHeight: height
                            radius: height / 2
                            color: index === folderPageIndicator.currentIndex
                                ? Qt.rgba(255, 255, 255, 0.9)
                                : Qt.rgba(255, 255, 255, pressed ? 0.18 : 0.05)

                            FrostedGlassBackground {
                                anchors.fill: parent
                                visible: index !== folderPageIndicator.currentIndex
                                radius: parent.radius
                                sourceItem: root.backgroundSourceItem
                                live: false
                                textureScale: 0.5
                                tintColor: Qt.rgba(1, 1, 1, pressed ? 0.14 : 0.08)
                                borderColor: Qt.rgba(1, 1, 1, 0.12)
                            }

                            Behavior on opacity {
                                OpacityAnimator {
                                    duration: root.animationDuration(100)
                                }
                            }

                            Behavior on width {
                                NumberAnimation {
                                    duration: root.animationDuration(160)
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: root.animationDuration(160)
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
            }
        }
    }
}
