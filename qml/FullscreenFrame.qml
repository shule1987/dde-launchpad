// SPDX-FileCopyrightText: 2023-2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15
import QtQuick.Effects
import QtQuick.Shapes
import org.deepin.dtk 1.0

import org.deepin.launchpad 1.0
import org.deepin.launchpad.models 1.0

InputEventItem {
    id: root
    anchors.fill: parent
    objectName: "FullscreenFrame-InputEventItem"
    inputMethodSource: footer.searchEdit
    focus: true

    property bool dockAreaReservedByWindow: false
    property alias launchAnimationViewportItem: reservedViewport
    property alias launchAnimationBackdropItem: launchAnimationBackdrop
    property alias launchAnimationForegroundItem: launchAnimationForegroundContent
    property alias launchAnimationForegroundScale: launchAnimationScale
    property var launchAnimationForegroundSnapshotItem: null
    property int iconGridMotionSerial: 0
    property bool iconGridMotionHiding: false
    property int iconGridMotionSpeedScale: 1
    property int glassSampleRevision: 0
    property int iconContentRevision: 0
    property string wallpaperBlurCacheKey: ""
    property string contentBlurCacheKey: ""
    property bool launchTransitionActive: false
    property var pendingGridPressItem: null
    property var pendingGridPressPageItem: null
    readonly property bool launcherDragActive: dndItem.currentlyDraggedId !== "" || dndItem.Drag.active
    readonly property bool glassLiveEnabled: false
    readonly property bool glassEffectEnabled: root.Window.window
        && root.Window.window.visible
        && !launchTransitionActive
    readonly property real glassSampleTextureScale: 0.5
    readonly property real footerBlankTop: footer ? footer.y : 0
    readonly property real footerBlankHeight: footer ? footer.height : 0
    readonly property rect footerSearchRect: footer
        ? Qt.rect(
            (width - footer.searchEdit.width) / 2,
            footer.y + (footer.height - footer.searchEdit.height) / 2,
            footer.searchEdit.width,
            footer.searchEdit.height
        )
        : Qt.rect(0, 0, 0, 0)

    function pointInRect(point, rect) {
        return point.x >= rect.x
            && point.x <= rect.x + rect.width
            && point.y >= rect.y
            && point.y <= rect.y + rect.height
    }

    function searchEditRectInCanvas() {
        if (!footer || !footer.searchEdit || !fullscreenCanvas) {
            return Qt.rect(0, 0, 0, 0)
        }

        const topLeft = footer.searchEdit.mapToItem(fullscreenCanvas, 0, 0)
        return Qt.rect(topLeft.x, topLeft.y, footer.searchEdit.width, footer.searchEdit.height)
    }

    function clearPendingGridPress() {
        pendingGridPressItem = null
        pendingGridPressPageItem = null
    }

    function rememberGridPressAt(position) {
        clearPendingGridPress()
        if (!contentView || !contentView.pageView || !contentView.pageView.currentItem) {
            return
        }

        const p = fullscreenCanvas.mapFromItem(root, position.x, position.y)
        const pageItem = contentView.pageView.currentItem
        const pagePoint = pageItem.mapFromItem(fullscreenCanvas, p.x, p.y)
        if (typeof pageItem.gridItemAt !== "function") {
            return
        }

        const gridItem = pageItem.gridItemAt(pagePoint.x, pagePoint.y)
        if (gridItem) {
            pendingGridPressItem = gridItem
            pendingGridPressPageItem = pageItem
            LauncherController.suppressNextHideForInputFocus()
        }
    }

    function activatePendingGridFolderAt(position) {
        const pressedItem = pendingGridPressItem
        const pageItem = pendingGridPressPageItem
        clearPendingGridPress()

        if (!pressedItem || !pageItem || folderGridViewPopup.visible || root.launcherDragActive) {
            return
        }
        if (typeof pageItem.gridItemAt !== "function"
                || typeof pressedItem.activateFolderItem !== "function") {
            return
        }

        const p = fullscreenCanvas.mapFromItem(root, position.x, position.y)
        const pagePoint = pageItem.mapFromItem(fullscreenCanvas, p.x, p.y)
        if (pageItem.gridItemAt(pagePoint.x, pagePoint.y) !== pressedItem) {
            return
        }

        if (pressedItem.activateFolderItem()) {
            LauncherController.suppressNextHideForInputFocus()
        }
    }

    function hideLauncherFromBlankPress(position) {
        if (DebugHelper.avoidHideWindow || folderGridViewPopup.visible) {
            return
        }

        const canvasOrigin = fullscreenCanvas.mapToItem(root, 0, 0)
        const canvasRect = Qt.rect(canvasOrigin.x, canvasOrigin.y,
                                   fullscreenCanvas.width, fullscreenCanvas.height)
        if (!pointInRect(position, canvasRect)) {
            LauncherController.visible = false
            return
        }

        const p = fullscreenCanvas.mapFromItem(root, position.x, position.y)
        const searchRect = searchEditRectInCanvas()

        if (p.y >= header.y && p.y <= header.y + header.height) {
            const headerPoint = header.mapFromItem(fullscreenCanvas, p.x, p.y)
            if (header.switchPageIndicatorAt(headerPoint.x, headerPoint.y)) {
                LauncherController.suppressNextHideForInputFocus()
                return
            }
            if (!header.pointInInteractiveArea(headerPoint.x, headerPoint.y)) {
                LauncherController.visible = false
            }
            return
        }

        if (p.y >= footer.y && p.y <= footer.y + footer.height && !pointInRect(p, searchRect)) {
            LauncherController.visible = false
            return
        }

        rememberGridPressAt(position)

    }

    onPointerPressed: function(position, button, modifiers) {
        if (button === Qt.LeftButton) {
            hideLauncherFromBlankPress(position)
        }
    }

    onPointerReleased: function(position, button, modifiers) {
        if (button === Qt.LeftButton) {
            activatePendingGridFolderAt(position)
        } else {
            clearPendingGridPress()
        }
    }

    function activateLauncherInput() {
        forceActiveFocus(Qt.ActiveWindowFocusReason)
        activateWindowForInput()
    }

    function refreshGlassSamples() {
        glassSampleRevision += 1
        glassBackdropCapture.scheduleUpdate()
        glassContentCapture.scheduleUpdate()
    }

    function currentWallpaperBlurKey() {
        const source = wallpaperBackground.status === Image.Ready
            ? wallpaperBackground.source
            : fallbackBackground.source
        return [
            source,
            root.width,
            root.height,
            Screen.devicePixelRatio,
            wallpaperBlurCache.textureSize.width,
            wallpaperBlurCache.textureSize.height
        ].join("|")
    }

    function refreshWallpaperBlurCacheIfNeeded(force) {
        if (!wallpaperBlurCache || width <= 0 || height <= 0) {
            return
        }

        const key = currentWallpaperBlurKey()
        if (!force && key === wallpaperBlurCacheKey) {
            return
        }

        wallpaperBlurCacheKey = key
        wallpaperBlurCache.scheduleUpdate()
    }

    function markIconContentDirty() {
        iconContentRevision += 1
    }

    function currentContentBlurKey() {
        return [
            iconContentRevision,
            contentView.pageView.currentIndex,
            footer.searchEdit.text,
            contentArea.width,
            contentArea.height,
            baseLayer.iconScaleFactor,
            baseLayer.iconCellWidth,
            baseLayer.iconCellHeight,
            Screen.devicePixelRatio
        ].join("|")
    }

    function refreshContentBlurCacheIfNeeded(force) {
        if (!contentBlurCache || contentArea.width <= 0 || contentArea.height <= 0) {
            return
        }

        const key = currentContentBlurKey()
        if (!force && key === contentBlurCacheKey) {
            return
        }

        contentBlurCacheKey = key
        contentBlurCache.scheduleUpdate()
    }

    function refreshGlassSnapshotAfterSettled() {
        if (!root.Window.window || !root.Window.window.visible) {
            return
        }
        if (launchTransitionActive || folderGridViewPopup.animationRunning) {
            glassSnapshotRequestTimer.restart()
            return
        }
        if (folderGridViewPopup.visible) {
            return
        }
        refreshGlassSamples()
        glassSnapshotSettledRefreshTimer.restart()
    }

    function requestGlassSnapshotAfterSettled() {
        if (!root.Window.window || !root.Window.window.visible) {
            return
        }
        glassSnapshotRequestTimer.restart()
    }

    MouseArea {
        anchors.fill: parent
        z: -100
        acceptedButtons: Qt.LeftButton
        enabled: !folderGridViewPopup.visible
        onClicked: {
            if (!DebugHelper.avoidHideWindow) {
                LauncherController.visible = false
            }
        }
    }

    Timer {
        id: inputActivationTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (root.Window.window && root.Window.window.visible) {
                root.activateLauncherInput()
            }
        }
    }

    Timer {
        id: glassSnapshotRequestTimer
        interval: 220 * LauncherController.animationSpeedScale
        repeat: false
        onTriggered: root.refreshGlassSnapshotAfterSettled()
    }

    Component.onCompleted: {
        inputActivationTimer.restart()
        root.refreshWallpaperBlurCacheIfNeeded(true)
        root.refreshContentBlurCacheIfNeeded(true)
    }

    property Palette appTextColor: Palette {
        normal {
            common: Qt.rgba(0, 0, 0, 1)
            crystal: Qt.rgba(0, 0, 0, 1)
        }
        normalDark {
            common: Qt.rgba(1, 1, 1, 0.7)
            crystal: Qt.rgba(1, 1, 1, 0.7)
        }
    }

    property Palette pageButtonIconColor: Palette {
        normal {
            common: Qt.rgba(1, 1, 1, 1)
            crystal: Qt.rgba(1, 1, 1, 1)
        }
        normalDark {
            common: Qt.rgba(1, 1, 1, 1)
            crystal: Qt.rgba(1, 1, 1, 1)
        }
    }

    Label {
        id: dndItem
        visible: DebugHelper.qtDebugEnabled
        text: "DnD DEBUG"

        property string currentlyDraggedId
        property string currentlyDraggedIconName
        property bool mergeAnimPending: false
        property string mergeAnimTargetIcon: ""
        property string mergeAnimTargetIcon2: ""
        property real mergeAnimStartX: 0
        property real mergeAnimStartY: 0
        property string liveReorderKey: ""
        property real mergeSize: 0

        signal dragEnded()

        Drag.onActiveChanged: {
            if (Drag.active) {
                text = "Dragging " + currentlyDraggedId
            } else {
                currentlyDraggedId = ""
                currentlyDraggedIconName = ""
                liveReorderKey = ""
                dragEnded()
            }
        }
    }

    function dropOnPage(dragId, dropFolderId, pageNumber) {
        dndItem.text = "drag " + dragId + " into " + dropFolderId + " at page " + pageNumber
        ItemArrangementProxyModel.commitDndOperation(dragId, dropFolderId, ItemArrangementProxyModel.DndJoin, pageNumber)
    }

    function decrementPageIndex(pages) {
        if (pages.currentIndex !== 0 || pages.count <= 1) {
            pages.decrementCurrentIndex()
        }
        if (typeof closeContextMenu === "function") {
            closeContextMenu()
        }
    }

    function incrementPageIndex(pages) {
        if (pages.currentIndex !== pages.count - 1 || pages.count <= 1) {
            pages.incrementCurrentIndex()
        }
        if (typeof closeContextMenu === "function") {
            closeContextMenu()
        }
    }

    readonly property bool isHorizontalDock: DesktopIntegration.dockPosition === Qt.UpArrow
                                            || DesktopIntegration.dockPosition === Qt.DownArrow
    readonly property real dockReserve: (
        (isHorizontalDock ? DesktopIntegration.dockGeometry.height : DesktopIntegration.dockGeometry.width)
        / Screen.devicePixelRatio
        + DesktopIntegration.dockSpacing
    )
    readonly property real reservedLeftInset: 0
    readonly property real reservedRightInset: 0
    readonly property real reservedTopInset: 0
    readonly property real reservedBottomInset: 0

    Item {
        id: reservedViewport
        anchors.fill: parent
        anchors.leftMargin: reservedLeftInset
        anchors.rightMargin: reservedRightInset
        anchors.topMargin: reservedTopInset
        anchors.bottomMargin: reservedBottomInset
        clip: true

        Item {
            id: blurSceneSource
            anchors.fill: parent

            Item {
                id: launchAnimationBackdrop
                anchors.fill: parent

                Image {
                    id: fallbackBackground
                    anchors.fill: parent
                    source: DesktopIntegration.backgroundUrl
                    sourceSize: Qt.size(
                        Math.max(1, Math.min(3200, Math.ceil(width * Screen.devicePixelRatio))),
                        Math.max(1, Math.min(2000, Math.ceil(height * Screen.devicePixelRatio)))
                    )
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    visible: wallpaperBackground.status !== Image.Ready
                    onStatusChanged: {
                        if (status === Image.Ready || status === Image.Error) {
                            root.refreshWallpaperBlurCacheIfNeeded(false)
                        }
                    }
                }

                Image {
                    id: wallpaperBackground
                    anchors.fill: parent
                    source: DesktopIntegration.wallpaperUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    smooth: true
                    sourceSize: Qt.size(
                        Math.max(1, Math.min(3200, Math.ceil(width * Screen.devicePixelRatio))),
                        Math.max(1, Math.min(2000, Math.ceil(height * Screen.devicePixelRatio)))
                    )
                    visible: status === Image.Ready
                    onStatusChanged: {
                        if (status === Image.Ready || status === Image.Error) {
                            root.refreshWallpaperBlurCacheIfNeeded(false)
                        }
                    }
                    onSourceChanged: root.refreshWallpaperBlurCacheIfNeeded(false)
                }

                Item {
                    id: wallpaperBlurSource
                    anchors.fill: parent

                    MultiEffect {
                        anchors.fill: parent
                        source: wallpaperBackground.status === Image.Ready ? wallpaperBackground : fallbackBackground
                        blurEnabled: true
                        blurMax: 80
                        blurMultiplier: 0.36
                        blur: 1.0
                        saturation: 1.05
                        autoPaddingEnabled: false
                    }
                }

                ShaderEffectSource {
                    id: wallpaperBlurCache
                    anchors.fill: parent
                    live: false
                    hideSource: true
                    recursive: false
                    smooth: true
                    mipmap: false
                    sourceItem: wallpaperBlurSource
                    textureSize: Qt.size(
                        Math.max(64, Math.min(3200, Math.ceil(width * Screen.devicePixelRatio))),
                        Math.max(64, Math.min(2000, Math.ceil(height * Screen.devicePixelRatio)))
                    )
                    onTextureSizeChanged: root.refreshWallpaperBlurCacheIfNeeded(false)
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.34)
                }

                Rectangle {
                    x: baseLayer.leftPadding
                    y: baseLayer.topPadding
                    width: Math.max(0, parent.width - baseLayer.leftPadding - baseLayer.rightPadding)
                    height: Math.max(0, parent.height - baseLayer.topPadding - baseLayer.bottomPadding)
                    readonly property real folderBackdropOpacity: 0.2 * folderGridViewPopup.externalDimProgress
                    color: Qt.rgba(0, 0, 0, folderBackdropOpacity)
                }
            }

            Item {
                id: launchAnimationForegroundContent
                width: parent.width
                height: parent.height
                x: 0
                y: 0
                transform: [
                    Scale {
                        id: launchAnimationScale
                        origin.x: 0
                        origin.y: 0
                        xScale: 1
                        yScale: 1
                    }
                ]

                Control {
                    id: baseLayer
                    anchors.fill: parent
                    visible: true
                    focus: true
                    objectName: "FullscreenFrame-BaseLayer"

                    property real iconScaleFactor: DesktopIntegration.iconScaleFactor
                    property Palette textColor: appTextColor

                    readonly property real viewportWidth: width - leftPadding - rightPadding
                    readonly property real viewportHeight: height - topPadding - bottomPadding
                    readonly property real gridUnitWidth: viewportWidth / 8
                    readonly property real gridUnitHeight: viewportHeight / 5
                    readonly property real iconCellWidth: gridUnitWidth
                    readonly property real iconCellHeight: gridUnitHeight
                    readonly property real iconAreaWidth: iconCellWidth * 7
                    readonly property real topBandHeight: iconCellHeight * 0.5
                    readonly property real bottomBandHeight: iconCellHeight * 0.5

                    palette.windowText: ColorSelector.textColor
                    leftPadding: (!dockAreaReservedByWindow && DesktopIntegration.dockPosition === Qt.LeftArrow ? dockReserve : 0)
                    rightPadding: (!dockAreaReservedByWindow && DesktopIntegration.dockPosition === Qt.RightArrow ? dockReserve : 0)
                    topPadding: (!dockAreaReservedByWindow && DesktopIntegration.dockPosition === Qt.UpArrow ? dockReserve : 0)
                    bottomPadding: (!dockAreaReservedByWindow && DesktopIntegration.dockPosition === Qt.DownArrow ? dockReserve : 0)

                    Behavior on iconScaleFactor {
                        NumberAnimation {
                            duration: 200 * LauncherController.animationSpeedScale
                            easing.type: Easing.OutQuad
                        }
                    }

                    Shortcut {
                        context: Qt.ApplicationShortcut
                        sequences: [StandardKey.HelpContents, "F1"]
                        onActivated: LauncherController.showHelp()
                        onActivatedAmbiguously: LauncherController.showHelp()
                    }

                    Shortcut {
                        context: Qt.ApplicationShortcut
                        sequences: ["Ctrl++", "Ctrl+="]
                        onActivated: baseLayer.increaseIconScale()
                    }

                    Shortcut {
                        context: Qt.ApplicationShortcut
                        sequences: ["Ctrl+-"]
                        onActivated: baseLayer.decreaseIconScale()
                    }

                    function increaseIconScale() {
                        if (DesktopIntegration.iconScaleFactor < 1.0) {
                            DesktopIntegration.iconScaleFactor = Math.min(DesktopIntegration.iconScaleFactor + 0.1, 1.0)
                        }
                    }

                    function decreaseIconScale() {
                        if (DesktopIntegration.iconScaleFactor > 0.5) {
                            DesktopIntegration.iconScaleFactor = Math.max(DesktopIntegration.iconScaleFactor - 0.1, 0.5)
                        }
                    }

                    function tryToRemoveEmptyPage() {
                        ItemArrangementProxyModel.removeEmptyPage()
                    }

                    DropArea {
                        id: dropArea
                        anchors.fill: parent
                        z: -1

                        property int pageIntent: 0
                        property bool createdEmptyPage: false
                        readonly property real paddingColumns: 0.5
                        readonly property real horizontalPadding: baseLayer.iconCellWidth * paddingColumns

                        function checkDragMove() {
                            if (drag.x < horizontalPadding) {
                                pageIntent = -1
                            } else if (drag.x > (width - baseLayer.iconCellWidth)) {
                                const isLastPage = contentView.pageView.currentIndex === contentView.pageView.count - 1
                                if (isLastPage && createdEmptyPage) {
                                    return
                                }
                                pageIntent = 1
                            } else {
                                pageIntent = 0
                            }
                        }

                        keys: ["text/x-dde-launcher-dnd-desktopId"]

                        onEntered: {
                            if (folderGridViewPopup.opened) {
                                folderGridViewPopup.close()
                            }
                        }

                        onPositionChanged: {
                            checkDragMove()
                        }

                        onDropped: function(drop) {
                            if (pageIntent !== 0) {
                                pageIntent = 0
                                return
                            }

                            const dragId = drop.getDataAsString("text/x-dde-launcher-dnd-desktopId")
                            dropOnPage(dragId, "internal/folders/0", contentView.pageView.currentIndex)
                            parent.pageIntent = 0
                        }

                        onExited: {
                            pageIntent = 0
                        }

                        onPageIntentChanged: {
                            if (pageIntent !== 0) {
                                dndMovePageTimer.restart()
                            } else {
                                dndMovePageTimer.stop()
                            }
                        }

                        Timer {
                            id: dndMovePageTimer
                            interval: 1000

                            onTriggered: {
                                if (parent.pageIntent > 0) {
                                    const isLastPage = contentView.pageView.currentIndex === contentView.pageView.count - 1
                                    if (isLastPage && !dropArea.createdEmptyPage) {
                                        const newPageIndex = ItemArrangementProxyModel.creatEmptyPage()
                                        dropArea.createdEmptyPage = true
                                        contentView.pageView.setCurrentIndex(newPageIndex)
                                        parent.pageIntent = 0
                                        return
                                    }
                                    incrementPageIndex(contentView.pageView)
                                } else if (parent.pageIntent < 0) {
                                    decrementPageIndex(contentView.pageView)
                                }

                                parent.pageIntent = 0
                                if (contentView.pageView.currentIndex !== 0) {
                                    parent.checkDragMove()
                                }
                            }
                        }

                        Connections {
                            target: dndItem
                            function onDragEnded() {
                                if (dropArea.createdEmptyPage) {
                                    baseLayer.tryToRemoveEmptyPage()
                                    dropArea.createdEmptyPage = false
                                }
                                ItemArrangementProxyModel.persistArrangement()
                                root.requestGlassSnapshotAfterSettled()
                            }
                        }
                    }

                    Timer {
                        id: flipPageDelay
                        interval: 400
                        repeat: false
                    }

                    contentItem: Item {
                        anchors.fill: parent

                        Item {
                                id: fullscreenCanvas
                                anchors.fill: parent
                                anchors.leftMargin: baseLayer.leftPadding
                                anchors.rightMargin: baseLayer.rightPadding
                                anchors.topMargin: baseLayer.topPadding
                                anchors.bottomMargin: baseLayer.bottomPadding
                                clip: true

                                MouseArea {
                                    anchors.fill: parent
                                    scrollGestureEnabled: false
                                    enabled: !folderGridViewPopup.visible

                                    onClicked: function(mouse) {
                                        if (mouse.y >= header.y && mouse.y <= header.y + header.height) {
                                            return
                                        }
                                        if (root.pointInRect(Qt.point(mouse.x, mouse.y), root.searchEditRectInCanvas())) {
                                            return
                                        }
                                        if (!DebugHelper.avoidHideWindow) {
                                            LauncherController.visible = false
                                        }
                                    }

                                    onWheel: function(wheel) {
                                        if (wheel.modifiers & Qt.ControlModifier) {
                                            const yDelta = wheel.angleDelta.y / 8
                                            if (yDelta > 0) {
                                                baseLayer.increaseIconScale()
                                            } else if (yDelta < 0) {
                                                baseLayer.decreaseIconScale()
                                            }
                                            return
                                        }

                                        if (flipPageDelay.running) {
                                            return
                                        }

                                        const xDelta = wheel.angleDelta.x / 8
                                        const yDelta = wheel.angleDelta.y / 8
                                        let toPage = 0
                                        if (yDelta !== 0) {
                                            toPage = yDelta > 0 ? -1 : 1
                                        } else if (xDelta !== 0) {
                                            toPage = xDelta > 0 ? 1 : -1
                                        }

                                        if (toPage < 0) {
                                            flipPageDelay.start()
                                            if (!footer.searchEdit.focus) {
                                                baseLayer.focus = true
                                            }
                                            contentView.pageView.changedByNonKeyboard = true
                                            decrementPageIndex(contentView.pageView)
                                        } else if (toPage > 0) {
                                            flipPageDelay.start()
                                            if (!footer.searchEdit.focus) {
                                                baseLayer.focus = true
                                            }
                                            contentView.pageView.changedByNonKeyboard = true
                                            incrementPageIndex(contentView.pageView)
                                        }
                                    }
                                }

                                TapHandler {
                                    acceptedButtons: Qt.LeftButton
                                    enabled: !folderGridViewPopup.visible

                                    function hideLauncher() {
                                        if (!DebugHelper.avoidHideWindow) {
                                            LauncherController.visible = false
                                        }
                                    }

                                    onTapped: function(eventPoint, button) {
                                        const p = eventPoint.position
                                        const searchRect = root.searchEditRectInCanvas()
                                        const inSearch = root.pointInRect(p, searchRect)
                                        if (p.y >= header.y && p.y <= header.y + header.height) {
                                            return
                                        }

                                        if (p.y >= footer.y && p.y <= footer.y + footer.height && !inSearch) {
                                            hideLauncher()
                                            return
                                        }

                                    }
                                }

                                FullscreenHeader {
                                    id: header
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    bandHeight: baseLayer.topBandHeight
                                    searchActive: footer.searchEdit.text !== ""
                                    pageView: footer.searchEdit.text !== "" ? contentView.searchPageView : contentView.pageView
                                    glassSourceItem: glassControlsSampleSource
                                    glassSampleRevision: root.glassSampleRevision
                                    glassLive: root.glassLiveEnabled
                                    glassEffect: root.glassEffectEnabled
                                    onExitRequested: {
                                        footer.searchEdit.text = ""
                                        LauncherController.setCurrentFrameToWindowedFrame()
                                    }
                                }

                                Item {
                                    id: contentArea
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: header.bottom
                                    anchors.bottom: footer.top
                                    clip: true
                                    opacity: contentBlurOverlay.visible ? 0 : 1

                                    FullscreenContentView {
                                        id: contentView
                                        anchors.fill: parent
                                        folderGridViewPopup: folderGridViewPopup
                                        dndItem: dndItem
                                        dropArea: dropArea
                                        mapTarget: folderGridViewPopup
                                        iconGridMotionSerial: root.iconGridMotionSerial
                                        iconGridMotionHiding: root.iconGridMotionHiding
                                        iconGridMotionSpeedScale: root.iconGridMotionSpeedScale
                                        cellWidth: baseLayer.iconCellWidth
                                        cellHeight: baseLayer.iconCellHeight
                                        iconScaleFactor: baseLayer.iconScaleFactor
                                        externalDimProgress: 0
                                        searchText: footer.searchEdit.text
                                        glassSourceItem: launchAnimationBackdrop
                                        glassSampleRevision: root.glassSampleRevision
                                        glassLive: root.glassLiveEnabled
                                        glassEffect: root.glassEffectEnabled
                                        launchAppFn: function(desktopId) { launchApp(desktopId) }
                                        showContextMenuFn: function(item, model) { showContextMenu(item, model) }
                                        getCategoryNameFn: function(section) { return getCategoryName(section) }
                                    }
                                }

                                ShaderEffectSource {
                                    id: contentBlurCache
                                    x: contentArea.x
                                    y: contentArea.y
                                    width: contentArea.width
                                    height: contentArea.height
                                    visible: false
                                    live: false
                                    hideSource: false
                                    recursive: false
                                    smooth: true
                                    mipmap: false
                                    sourceItem: contentArea
                                    sourceRect: Qt.rect(0, 0, contentArea.width, contentArea.height)
                                    textureSize: Qt.size(
                                        Math.max(64, Math.ceil(width * Screen.devicePixelRatio)),
                                        Math.max(64, Math.ceil(height * Screen.devicePixelRatio))
                                    )
                                }

                                MultiEffect {
                                    id: contentBlurOverlay
                                    x: contentArea.x
                                    y: contentArea.y
                                    width: contentArea.width
                                    height: contentArea.height
                                    source: contentBlurCache
                                    visible: folderGridViewPopup.visible || folderGridViewPopup.externalDimProgress > 0
                                    opacity: 1 - (0.4 * folderGridViewPopup.externalDimProgress)
                                    autoPaddingEnabled: false
                                    blurEnabled: true
                                    blurMax: 64
                                    blurMultiplier: 0.22
                                    blur: folderGridViewPopup.externalDimProgress
                                    saturation: 1.4
                                }

                                Item {
                                    id: glassControlsSampleSource
                                    anchors.fill: parent
                                    z: -100
                                    enabled: false

                                    ShaderEffectSource {
                                        id: glassBackdropCapture
                                        readonly property point backdropOrigin: glassControlsSampleSource.mapToItem(launchAnimationBackdrop, 0, 0)

                                        anchors.fill: parent
                                        live: root.glassLiveEnabled
                                        hideSource: false
                                        recursive: false
                                        smooth: true
                                        mipmap: false
                                        sourceItem: launchAnimationBackdrop
                                        sourceRect: Qt.rect(
                                            backdropOrigin.x,
                                            backdropOrigin.y,
                                            glassControlsSampleSource.width,
                                            glassControlsSampleSource.height
                                        )
                                        textureSize: Qt.size(
                                            Math.max(64, Math.ceil(width * Screen.devicePixelRatio * root.glassSampleTextureScale)),
                                            Math.max(64, Math.ceil(height * Screen.devicePixelRatio * root.glassSampleTextureScale))
                                        )
                                    }

                                    ShaderEffectSource {
                                        id: glassContentCapture
                                        x: contentArea.x
                                        y: contentArea.y
                                        width: contentArea.width
                                        height: contentArea.height
                                        visible: false
                                        live: root.glassLiveEnabled
                                        hideSource: false
                                        recursive: false
                                        smooth: true
                                        mipmap: false
                                        sourceItem: contentArea
                                        sourceRect: Qt.rect(0, 0, contentArea.width, contentArea.height)
                                        textureSize: Qt.size(
                                            Math.max(64, Math.ceil(width * Screen.devicePixelRatio * root.glassSampleTextureScale)),
                                            Math.max(64, Math.ceil(height * Screen.devicePixelRatio * root.glassSampleTextureScale))
                                        )
                                    }
                                }

                                FullscreenFooter {
                                    id: footer
                                    z: 100
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    bandHeight: baseLayer.bottomBandHeight
                                    maxSearchWidth: baseLayer.iconAreaWidth
                                    dimProgress: folderGridViewPopup.externalDimProgress
                                    pageView: contentView.pageView
                                    searchGrid: contentView.searchGrid
                                    searchResultCount: contentView.searchResultCount
                                    glassSourceItem: glassControlsSampleSource
                                    glassSampleRevision: root.glassSampleRevision
                                    glassLive: root.glassLiveEnabled
                                    glassEffect: root.glassEffectEnabled
                                }

                                ToolButton {
                                    id: previousPageButton
                                    readonly property var targetPageView: footer.searchEdit.text !== ""
                                        ? contentView.searchPageView
                                        : contentView.pageView
                                    anchors.left: parent.left
                                    anchors.leftMargin: 30
                                    y: Math.round((root.height - height) / 2)
                                    z: 10
                                    width: 50
                                    height: 50
                                    hoverEnabled: true
                                    visible: targetPageView
                                             && targetPageView.count > 1
                                             && !folderGridViewPopup.visible
                                    enabled: visible
                                    display: AbstractButton.IconOnly
                                    icon.name: "go-previous"
                                    icon.width: 20
                                    icon.height: 20
                                    icon.color: "#FFFFFFFF"
                                    contentItem: Item {
                                        anchors.fill: parent

                                        Canvas {
                                            anchors.centerIn: parent
                                            width: 20
                                            height: 20
                                            onPaint: {
                                                const ctx = getContext("2d")
                                                ctx.clearRect(0, 0, width, height)
                                                ctx.strokeStyle = "#FFFFFFFF"
                                                ctx.lineWidth = 2.2
                                                ctx.lineCap = "round"
                                                ctx.lineJoin = "round"
                                                ctx.beginPath()
                                                ctx.moveTo(12.5, 5)
                                                ctx.lineTo(7.5, 10)
                                                ctx.lineTo(12.5, 15)
                                                ctx.stroke()
                                            }
                                        }
                                    }
                                    background: FrostedGlassBackground {
                                        radius: 25
                                        sourceItem: glassControlsSampleSource
                                        sampleRevision: root.glassSampleRevision
                                        live: root.glassLiveEnabled
                                        effectEnabled: root.glassEffectEnabled
                                        textureScale: root.glassSampleTextureScale
                                        brightness: previousPageButton.down ? -0.1 : previousPageButton.hovered ? 0.2 : 0.0
                                        tintColor: Qt.rgba(1, 1, 1, previousPageButton.down ? 0.16 : previousPageButton.hovered ? 0.12 : 0.08)
                                        borderColor: Qt.rgba(1, 1, 1, 0.12)
                                    }
                                    onClicked: {
                                        if (!targetPageView) {
                                            return
                                        }
                                        targetPageView.changedByNonKeyboard = true
                                        decrementPageIndex(targetPageView)
                                    }
                                }

                                ToolButton {
                                    id: nextPageButton
                                    readonly property var targetPageView: footer.searchEdit.text !== ""
                                        ? contentView.searchPageView
                                        : contentView.pageView
                                    anchors.right: parent.right
                                    anchors.rightMargin: 30
                                    y: Math.round((root.height - height) / 2)
                                    z: 10
                                    width: 50
                                    height: 50
                                    hoverEnabled: true
                                    visible: targetPageView
                                             && targetPageView.count > 1
                                             && !folderGridViewPopup.visible
                                    enabled: visible
                                    display: AbstractButton.IconOnly
                                    icon.name: "go-next"
                                    icon.width: 20
                                    icon.height: 20
                                    icon.color: "#FFFFFFFF"
                                    contentItem: Item {
                                        anchors.fill: parent

                                        Canvas {
                                            anchors.centerIn: parent
                                            width: 20
                                            height: 20
                                            onPaint: {
                                                const ctx = getContext("2d")
                                                ctx.clearRect(0, 0, width, height)
                                                ctx.strokeStyle = "#FFFFFFFF"
                                                ctx.lineWidth = 2.2
                                                ctx.lineCap = "round"
                                                ctx.lineJoin = "round"
                                                ctx.beginPath()
                                                ctx.moveTo(7.5, 5)
                                                ctx.lineTo(12.5, 10)
                                                ctx.lineTo(7.5, 15)
                                                ctx.stroke()
                                            }
                                        }
                                    }
                                    background: FrostedGlassBackground {
                                        radius: 25
                                        sourceItem: glassControlsSampleSource
                                        sampleRevision: root.glassSampleRevision
                                        live: root.glassLiveEnabled
                                        effectEnabled: root.glassEffectEnabled
                                        textureScale: root.glassSampleTextureScale
                                        brightness: nextPageButton.down ? -0.1 : nextPageButton.hovered ? 0.2 : 0.0
                                        tintColor: Qt.rgba(1, 1, 1, nextPageButton.down ? 0.16 : nextPageButton.hovered ? 0.12 : 0.08)
                                        borderColor: Qt.rgba(1, 1, 1, 0.12)
                                    }
                                    onClicked: {
                                        if (!targetPageView) {
                                            return
                                        }
                                        targetPageView.changedByNonKeyboard = true
                                        incrementPageIndex(targetPageView)
                                    }
                                }

                                Item {
                                    id: footerBlankClickLayer
                                    anchors.fill: parent
                                    z: 90
                                    visible: !folderGridViewPopup.visible

                                    readonly property real footerTop: footer.y
                                    readonly property real footerBottom: footer.y + footer.height
                                    readonly property rect searchRect: root.searchEditRectInCanvas()
                                    readonly property real searchLeft: searchRect.x
                                    readonly property real searchTop: searchRect.y
                                    readonly property real searchRight: searchRect.x + searchRect.width
                                    readonly property real searchBottom: searchRect.y + searchRect.height

                                    function hideLauncher() {
                                        if (!DebugHelper.avoidHideWindow) {
                                            LauncherController.visible = false
                                        }
                                    }

                                    MouseArea {
                                        x: 0
                                        y: footerBlankClickLayer.footerTop
                                        width: Math.max(0, footerBlankClickLayer.searchLeft)
                                        height: footer.height
                                        onClicked: footerBlankClickLayer.hideLauncher()
                                    }

                                    MouseArea {
                                        x: footerBlankClickLayer.searchRight
                                        y: footerBlankClickLayer.footerTop
                                        width: Math.max(0, parent.width - x)
                                        height: footer.height
                                        onClicked: footerBlankClickLayer.hideLauncher()
                                    }

                                    MouseArea {
                                        x: footerBlankClickLayer.searchLeft
                                        y: footerBlankClickLayer.footerTop
                                        width: footer.searchEdit.width
                                        height: Math.max(0, footerBlankClickLayer.searchTop - footerBlankClickLayer.footerTop)
                                        onClicked: footerBlankClickLayer.hideLauncher()
                                    }

                                    MouseArea {
                                        x: footerBlankClickLayer.searchLeft
                                        y: footerBlankClickLayer.searchBottom
                                        width: footer.searchEdit.width
                                        height: Math.max(0, footerBlankClickLayer.footerBottom - footerBlankClickLayer.searchBottom)
                                        onClicked: footerBlankClickLayer.hideLauncher()
                                    }
                                }
                        }
                    }
                }
            }

        }

        FullscreenFolderOverlay {
            id: folderGridViewPopup
            anchors.fill: parent
            cs: baseLayer.iconCellHeight
            folderCellWidth: baseLayer.iconCellWidth
            folderCellHeight: baseLayer.iconCellHeight
            backgroundSourceItem: wallpaperBackground.status === Image.Ready ? wallpaperBackground : null
            refreshBackgroundSourceFn: function() {
                root.refreshGlassSamples()
            }
            backgroundSourceOriginX: wallpaperBackground.status === Image.Ready ? wallpaperBackground.mapToItem(folderGridViewPopup, 0, 0).x : 0
            backgroundSourceOriginY: wallpaperBackground.status === Image.Ready ? wallpaperBackground.mapToItem(folderGridViewPopup, 0, 0).y : 0
            dndItem: dndItem
            focusTarget: baseLayer
            launchAppFn: function(desktopId) { launchApp(desktopId) }
            showContextMenuFn: function(item, model) { showContextMenu(item, model) }
            dropOnPageFn: function(dragId, dropFolderId, pageNumber) {
                dropOnPage(dragId, dropFolderId, pageNumber)
            }
            dropOnItemFn: function(dragId, dropId, op) {
                dndItem.text = "drag " + dragId + " onto " + dropId + " with " + op
                ItemArrangementProxyModel.commitDndOperation(dragId, dropId, op)
            }
            decrementPageIndexFn: function(pages) { decrementPageIndex(pages) }
            incrementPageIndexFn: function(pages) { incrementPageIndex(pages) }
            prepareContentBlurSourceFn: function() {
                root.refreshContentBlurCacheIfNeeded(false)
            }
            folderNameFont: LauncherController.adjustFontWeight(DTK.fontManager.t6, Font.Bold)
            endPoint: Qt.point(width / 2, height / 2)
        }

        Item {
            id: folderOutsideDimOverlay
            anchors.fill: parent
            z: 90
            enabled: false
            visible: opacity > 0
            opacity: 0.2 * folderGridViewPopup.externalDimProgress

            readonly property real panelLeft: Math.max(0, Math.min(width, folderGridViewPopup.panelX))
            readonly property real panelTop: Math.max(0, Math.min(height, folderGridViewPopup.panelY))
            readonly property real panelRight: Math.max(panelLeft, Math.min(width, folderGridViewPopup.panelX + folderGridViewPopup.panelCurrentWidth))
            readonly property real panelBottom: Math.max(panelTop, Math.min(height, folderGridViewPopup.panelY + folderGridViewPopup.panelCurrentHeight))
            readonly property real panelRadius: Math.max(0, Math.min(
                folderGridViewPopup.panelRadius,
                (panelRight - panelLeft) / 2,
                (panelBottom - panelTop) / 2
            ))

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "black"
                    strokeColor: "transparent"
                    strokeWidth: 0
                    fillRule: ShapePath.OddEvenFill

                    PathMove { x: 0; y: 0 }
                    PathLine { x: folderOutsideDimOverlay.width; y: 0 }
                    PathLine { x: folderOutsideDimOverlay.width; y: folderOutsideDimOverlay.height }
                    PathLine { x: 0; y: folderOutsideDimOverlay.height }
                    PathLine { x: 0; y: 0 }

                    PathMove {
                        x: folderOutsideDimOverlay.panelLeft + folderOutsideDimOverlay.panelRadius
                        y: folderOutsideDimOverlay.panelTop
                    }
                    PathLine {
                        x: folderOutsideDimOverlay.panelRight - folderOutsideDimOverlay.panelRadius
                        y: folderOutsideDimOverlay.panelTop
                    }
                    PathQuad {
                        x: folderOutsideDimOverlay.panelRight
                        y: folderOutsideDimOverlay.panelTop + folderOutsideDimOverlay.panelRadius
                        controlX: folderOutsideDimOverlay.panelRight
                        controlY: folderOutsideDimOverlay.panelTop
                    }
                    PathLine {
                        x: folderOutsideDimOverlay.panelRight
                        y: folderOutsideDimOverlay.panelBottom - folderOutsideDimOverlay.panelRadius
                    }
                    PathQuad {
                        x: folderOutsideDimOverlay.panelRight - folderOutsideDimOverlay.panelRadius
                        y: folderOutsideDimOverlay.panelBottom
                        controlX: folderOutsideDimOverlay.panelRight
                        controlY: folderOutsideDimOverlay.panelBottom
                    }
                    PathLine {
                        x: folderOutsideDimOverlay.panelLeft + folderOutsideDimOverlay.panelRadius
                        y: folderOutsideDimOverlay.panelBottom
                    }
                    PathQuad {
                        x: folderOutsideDimOverlay.panelLeft
                        y: folderOutsideDimOverlay.panelBottom - folderOutsideDimOverlay.panelRadius
                        controlX: folderOutsideDimOverlay.panelLeft
                        controlY: folderOutsideDimOverlay.panelBottom
                    }
                    PathLine {
                        x: folderOutsideDimOverlay.panelLeft
                        y: folderOutsideDimOverlay.panelTop + folderOutsideDimOverlay.panelRadius
                    }
                    PathQuad {
                        x: folderOutsideDimOverlay.panelLeft + folderOutsideDimOverlay.panelRadius
                        y: folderOutsideDimOverlay.panelTop
                        controlX: folderOutsideDimOverlay.panelLeft
                        controlY: folderOutsideDimOverlay.panelTop
                    }
                }
            }
        }

        Timer {
            id: glassSnapshotSettledRefreshTimer
            interval: 240 * LauncherController.animationSpeedScale
            repeat: false
            onTriggered: {
                if (folderGridViewPopup.visible) {
                    return
                }
                root.refreshGlassSamples()
            }
        }
    }

    Keys.forwardTo: [footer.searchEdit]

    Keys.onPressed: function(event) {
        if (!baseLayer.focus) {
            return
        }

        switch (event.key) {
        case Qt.Key_Up:
        case Qt.Key_Down:
        case Qt.Key_Left:
        case Qt.Key_Right:
        case Qt.Key_Enter:
        case Qt.Key_Return:
            contentView.pageView.focus = true
            break
        }
    }

    Keys.onEscapePressed: {
        if (!DebugHelper.avoidHideWindow) {
            LauncherController.visible = false
        }
    }

    Connections {
        target: root.Window.window

        function onVisibleChanged() {
            if (root.Window.window && root.Window.window.visible) {
                inputActivationTimer.restart()
                root.requestGlassSnapshotAfterSettled()
                return
            }

            if (!root.Window.window) {
                return
            }

            releaseWindowInput()
            footer.searchEdit.text = ""
            contentView.resetCurrentGridIndex()
            if (folderGridViewPopup.visible) {
                folderGridViewPopup.close()
            }
            baseLayer.focus = true
        }
    }

    Connections {
        target: contentView.pageView

        function onCurrentIndexChanged() {
            root.requestGlassSnapshotAfterSettled()
        }
    }

    Connections {
        target: ItemArrangementProxyModel

        function onRowsInserted() {
            root.markIconContentDirty()
        }

        function onRowsRemoved() {
            root.markIconContentDirty()
        }

        function onRowsMoved() {
            root.markIconContentDirty()
        }

        function onDataChanged() {
            root.markIconContentDirty()
        }

        function onLayoutChanged() {
            root.markIconContentDirty()
        }

        function onModelReset() {
            root.markIconContentDirty()
        }
    }

    Connections {
        target: footer.searchEdit

        function onTextChanged() {
            root.requestGlassSnapshotAfterSettled()
        }
    }

    Connections {
        target: folderGridViewPopup

        function onAnimationRunningChanged() {
            if (!folderGridViewPopup.animationRunning) {
                root.requestGlassSnapshotAfterSettled()
            }
        }
    }

    Connections {
        target: LauncherController

        function onCurrentFrameChanged() {
            if (LauncherController.currentFrame === "FullscreenFrame") {
                contentView.resetToFirstPage()
            }
        }
    }

    onInputReceived: function(text) {
        if (footer.searchEdit.text !== "" || footer.searchEdit.focus !== true) {
            footer.searchEdit.text = text
            footer.searchEdit.focus = true
        }
    }
}
