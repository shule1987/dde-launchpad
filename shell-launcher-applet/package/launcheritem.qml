// SPDX-FileCopyrightText: 2023 - 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

import org.deepin.dtk 1.0
import org.deepin.dtk.style 1.0 as DStyle

import org.deepin.ds 1.0
import org.deepin.dtk 1.0 as D
import org.deepin.ds.dock 1.0

import org.deepin.launchpad 1.0
import org.deepin.launchpad.models 1.0
import org.deepin.launchpad.windowed 1.0

AppletItem {
    id: launcher
    property bool useColumnLayout: Panel.position % 2
    property int dockOrder: 12
    property rect fullscreenLaunchSourceGlobalRect: Qt.rect(0, 0, 1, 1)
    property double lastDockMousePressMs: 0
    property double lastPanelEdgeToggleMs: 0
    property double lastDockDeactivationHideMs: 0
    readonly property int crossSourceToggleGuardInterval: 220
    readonly property int deactivationToggleGuardInterval: 320
    // 1:4 the distance between app : dock height; get width/height≈0.8
    implicitWidth: useColumnLayout ? Panel.rootObject.dockSize : Panel.rootObject.dockItemMaxSize * 0.8
    implicitHeight: useColumnLayout ? Panel.rootObject.dockItemMaxSize * 0.8 : Panel.rootObject.dockSize

    function toggleLauncher() {
        if (fullscreenFrame.launchAnimationRunning) {
            return
        }

        assignFullscreenFrameScreen()
        updateFullscreenLaunchSourceRect()
        LauncherController.toggleFromDock()
        toolTip.close()
    }

    function hideAfterDockDeactivation() {
        const now = Date.now()
        if (fullscreenFrame.launcherRequestedVisible
            && now - fullscreenFrame.lastShowAnimationStartMs < Math.max(320, fullscreenFrame.launchShowAnimationDuration + fullscreenFrame.frameInterval * 4)) {
            return
        }

        lastDockDeactivationHideMs = now
        LauncherController.hideFromDockDeactivation()
    }

    function recentlyHidAfterDockDeactivation(now) {
        return now - lastDockDeactivationHideMs < deactivationToggleGuardInterval
    }

    Connections {
        target: Panel.rootObject
        function onDockCenterPartPosChanged()
        {
            updateLaunchpadPos()
        }
        function onViewDeactivated() {
        }
    }

    Connections {
        target: Panel
        function onLeftEdgeClicked(minOrder) {
            if (launcher.dockOrder == minOrder) {
                const now = Date.now()
                if (recentlyHidAfterDockDeactivation(now)) {
                    return
                }
                if (now - launcher.lastDockMousePressMs < launcher.crossSourceToggleGuardInterval) {
                    return
                }
                launcher.lastPanelEdgeToggleMs = now
                assignFullscreenFrameScreen()
                updateFullscreenLaunchSourceRect()
                LauncherController.toggleFromPanelEdge()
                toolTip.close()
            }
        }
    }

    property point itemPos: Qt.point(0, 0)
    function updateItemPos()
    {
        var lX = icon.mapToItem(null, 0, 0).x
        var lY = icon.mapToItem(null, 0, 0).y
        launcher.itemPos = Qt.point(lX, lY)
    }
    function updateLaunchpadPos()
    {
        updateItemPos()
        updateFullscreenLaunchSourceRect()
        var launchpad = DS.applet("org.deepin.ds.launchpad")
        if (!launchpad || !launchpad.rootObject)
            return

        launchpad.rootObject.windowedPos = launcher.itemPos
        launchpad.rootObject.fullscreenLaunchSourceGlobalRect = launcher.fullscreenLaunchSourceGlobalRect
    }

    function updateFullscreenLaunchSourceRect()
    {
        if (!icon)
            return

        const renderedWidth = Math.max(1, icon.width * Math.abs(icon.scale))
        const renderedHeight = Math.max(1, icon.height * Math.abs(icon.scale))
        const iconGlobalCenter = resolvedIconGlobalCenter()

        fullscreenLaunchSourceGlobalRect = Qt.rect(
            iconGlobalCenter.x - renderedWidth / 2,
            iconGlobalCenter.y - renderedHeight / 2,
            renderedWidth,
            renderedHeight
        )
    }

    function finitePoint(point)
    {
        return point && isFinite(point.x) && isFinite(point.y)
    }

    function descaledDockRect()
    {
        const ratio = Math.max(1, Screen.devicePixelRatio || 1)
        const rect = DesktopIntegration.dockGeometry
        return Qt.rect(rect.x / ratio, rect.y / ratio, rect.width / ratio, rect.height / ratio)
    }

    function expandedRectContains(rect, point, padding)
    {
        return point.x >= rect.x - padding
            && point.x <= rect.x + rect.width + padding
            && point.y >= rect.y - padding
            && point.y <= rect.y + rect.height + padding
    }

    function resolvedIconGlobalCenter()
    {
        const localCenter = Qt.point(icon.width / 2, icon.height / 2)
        const dockRect = descaledDockRect()
        const dockPadding = Math.max(96, Panel.rootObject.dockSize || 0)

        const iconGlobalCenter = icon.mapToGlobal(localCenter.x, localCenter.y)
        if (finitePoint(iconGlobalCenter) && expandedRectContains(dockRect, iconGlobalCenter, dockPadding)) {
            return iconGlobalCenter
        }

        if (Applet.rootObject) {
            const centerInApplet = icon.mapToItem(Applet.rootObject, localCenter.x, localCenter.y)
            const appletGlobalCenter = Applet.rootObject.mapToGlobal(centerInApplet.x, centerInApplet.y)
            if (finitePoint(appletGlobalCenter) && expandedRectContains(dockRect, appletGlobalCenter, dockPadding)) {
                return appletGlobalCenter
            }
        }

        const centerInDockWindow = icon.mapToItem(null, localCenter.x, localCenter.y)
        const dockWindowGlobalCenter = Qt.point(dockRect.x + centerInDockWindow.x,
                                                dockRect.y + centerInDockWindow.y)
        if (finitePoint(dockWindowGlobalCenter) && expandedRectContains(dockRect, dockWindowGlobalCenter, dockPadding)) {
            return dockWindowGlobalCenter
        }

        return Qt.point(dockRect.x + dockRect.width / 2, dockRect.y + dockRect.height / 2)
    }
    Component.onCompleted: {
        updateLaunchpadPos()
        assignFullscreenFrameScreen()
    }

    function decrementPageIndex(pages) {
        if (pages.currentIndex === 0 && pages.count > 1) {
            // pages.setCurrentIndex(pages.count - 1)
        } else {
            pages.decrementCurrentIndex()
        }

        closeContextMenu()
    }

    function incrementPageIndex(pages) {
        if (pages.currentIndex === pages.count - 1 && pages.count > 1) {
            // pages.setCurrentIndex(0)
        } else {
            pages.incrementCurrentIndex()
        }

        closeContextMenu()
    }

    property var activeMenu: null
    property Component appContextMenuCom: AppItemMenu { }
    function showContextMenu(obj, model, additionalProps = {}) {
        if (!obj || !obj.Window.window) {
            console.log("obj or obj.Window.window is null")
            return
        }
        closeContextMenu()

        const menu = appContextMenuCom.createObject(obj.Window.window.contentItem, Object.assign({
            display: model.display,
            desktopId: model.desktopId,
            iconName: model.iconName,
            isFavoriteItem: false,
            hideFavoriteMenu: true,
            hideDisplayScalingMenu: Math.abs(DesktopIntegration.scaleFactor - 1.0) < 0.0001,
            hideMoveToTopMenu: true,
            getCategoryNameFn: function(section) { return getCategoryName(section) }
        }, additionalProps));
        menu.closed.connect(menu.destroy)
        menu.popup();

        activeMenu = menu
    }

    function closeContextMenu() {
        if (activeMenu) {
            activeMenu.close()
            activeMenu = null
        }
    }

    function getCategoryName(section) {
        switch (Number(section)) {
        case AppItem.Internet:
            return qsTr("Internet");
        case AppItem.Chat:
            return qsTr("Chat");
        case AppItem.Music:
            return qsTr("Music");
        case AppItem.Video:
            return qsTr("Video");
        case AppItem.Graphics:
            return qsTr("Graphics");
        case AppItem.Game:
            return qsTr("Games");
        case AppItem.Office:
            return qsTr("Office");
        case AppItem.Reading:
            return qsTr("Reading");
        case AppItem.Development:
            return qsTr("Development");
        case AppItem.System:
            return qsTr("System");
        default:
            return qsTr("Others");
        }
    }

    function launchApp(desktopId) {
        LauncherController.visible = false;
        DesktopIntegration.launchByDesktopId(desktopId);
    }

    function assignFullscreenFrameScreen() {
        const newScreenName = DS.applet("org.deepin.ds.dock").screenName
        for (const scr of Qt.application.screens) {
            if (scr.name === newScreenName) {
                launcher.fullscreenFrame.screen = scr
                LauncherController.currentScreen = scr.name
                return
            }
        }
    }

    // A singleshot timer
    Timer {
        id: reassignFullscreenFrameScreenTimer
        interval: 100
        repeat: false
        onTriggered: {
            assignFullscreenFrameScreen()
        }
    }

    PanelToolTip {
        id: toolTip
        text: qsTr("launchpad")
        toolTipX: DockPanelPositioner.x
        toolTipY: DockPanelPositioner.y
    }

    property var fullscreenFrame: ApplicationWindow {
        objectName: "FullscreenFrameApplicationWindow"
        title: "org.deepin.ds.launchpad.fullscreen"
        property bool launcherRequestedVisible: LauncherController.visible && (LauncherController.currentFrame !== "WindowedFrame")
        property bool keepVisibleWhileAnimating: launcherRequestedVisible
        property bool visibilityInitialized: false
        property bool showAnimationAwaitingMappedFrame: false
        property double lastShowAnimationStartMs: 0
        property int activeLaunchAnimationSpeedScale: 1
        property rect launchSourceGlobalRect: launcher.fullscreenLaunchSourceGlobalRect
        readonly property real screenRefreshRate: Math.max(60, LauncherController.displayRefreshRate)
        readonly property int frameInterval: Math.max(1, Math.floor(1000 / screenRefreshRate))
        readonly property int launchAnimationSpeedScale: activeLaunchAnimationSpeedScale
        readonly property int launchShowAnimationDuration: 200 * launchAnimationSpeedScale
        readonly property int launchHideAnimationDuration: 200 * launchAnimationSpeedScale
        readonly property int launchBackdropAnimationDuration: 180 * launchAnimationSpeedScale
        readonly property int launchGridMotionMaxDelay: 30 * launchAnimationSpeedScale
        readonly property int launchShowDeadline: launchShowAnimationDuration + launchGridMotionMaxDelay + frameInterval * 4
        readonly property int launchHideDeadline: launchHideAnimationDuration + launchGridMotionMaxDelay + frameInterval * 2
        readonly property bool launchAnimationRunning: showAnimation.running || hideAnimation.running || showAnimationAwaitingMappedFrame
        readonly property bool launchAnimationProxyVisible: showAnimation.running || hideAnimation.running
        readonly property var launchAnimationViewportItem: fullscreenFrameLoader.item ? fullscreenFrameLoader.item.launchAnimationViewportItem : null
        readonly property var launchAnimationBackdropItem: fullscreenFrameLoader.item ? fullscreenFrameLoader.item.launchAnimationBackdropItem : null
        readonly property var launchAnimationForegroundItem: fullscreenFrameLoader.item ? fullscreenFrameLoader.item.launchAnimationForegroundItem : null
        readonly property var launchAnimationForegroundScale: fullscreenFrameLoader.item ? fullscreenFrameLoader.item.launchAnimationForegroundScale : null
        readonly property var launchAnimationForegroundSnapshotItem: fullscreenFrameLoader.item ? fullscreenFrameLoader.item.launchAnimationForegroundSnapshotItem : null

        function resolvedLaunchSourceRect() {
            const screenGeometry = (fullscreenFrame.screen && fullscreenFrame.screen.geometry)
                ? fullscreenFrame.screen.geometry
                : Qt.rect(fullscreenFrame.x || 0,
                          fullscreenFrame.y || 0,
                          Math.max(1, fullscreenFrame.width || 0),
                          Math.max(1, fullscreenFrame.height || 0))
            const viewportItem = launchAnimationViewportItem
            const safeWidth = Math.max(1, viewportItem ? viewportItem.width : screenGeometry.width)
            const safeHeight = Math.max(1, viewportItem ? viewportItem.height : screenGeometry.height)
            const sourceWidth = Math.min(Math.max(1, launchSourceGlobalRect.width), safeWidth)
            const sourceHeight = Math.min(Math.max(1, launchSourceGlobalRect.height), safeHeight)
            const viewportX = viewportItem ? viewportItem.x : 0
            const viewportY = viewportItem ? viewportItem.y : 0
            const sourceX = Math.min(Math.max(launchSourceGlobalRect.x - screenGeometry.x - viewportX, 0), safeWidth - sourceWidth)
            const sourceY = Math.min(Math.max(launchSourceGlobalRect.y - screenGeometry.y - viewportY, 0), safeHeight - sourceHeight)
            return Qt.rect(sourceX, sourceY, sourceWidth, sourceHeight)
        }

        function applyLaunchSourceState() {
            if (!launchAnimationForegroundItem || !launchAnimationForegroundScale) {
                return
            }

            launchAnimationForegroundItem.x = 0
            launchAnimationForegroundItem.y = 0
            launchAnimationForegroundScale.xScale = 1
            launchAnimationForegroundScale.yScale = 1
        }

        function resetFullscreenContentState() {
            if (launchAnimationBackdropItem) {
                launchAnimationBackdropItem.opacity = 1
            }
            if (launchAnimationForegroundItem) {
                launchAnimationForegroundItem.x = 0
                launchAnimationForegroundItem.y = 0
                launchAnimationForegroundItem.opacity = 1
            }
            if (launchAnimationForegroundScale) {
                launchAnimationForegroundScale.xScale = 1
                launchAnimationForegroundScale.yScale = 1
            }
        }

        function finishShowAnimation() {
            showVisibilityDeadlineTimer.stop()
            mappedFrameFallbackTimer.stop()
            showAnimationKickoffTimer.stop()
            showAnimationAwaitingMappedFrame = false
            keepVisibleWhileAnimating = launcherRequestedVisible
            resetFullscreenContentState()
            if (fullscreenFrameLoader.item) {
                fullscreenFrameLoader.item.launchTransitionActive = false
                fullscreenFrameLoader.item.iconGridMotionHiding = false
                fullscreenFrameLoader.item.refreshGlassSnapshotAfterSettled()
            }
        }

        function finishHideAnimation() {
            hideVisibilityDeadlineTimer.stop()
            showVisibilityDeadlineTimer.stop()
            showAnimationAwaitingMappedFrame = false
            if (fullscreenFrameLoader.item) {
                fullscreenFrameLoader.item.launchTransitionActive = false
            }
            if (!launcherRequestedVisible) {
                keepVisibleWhileAnimating = false
                resetFullscreenContentState()
                hide()
            }
        }

        function armShowAnimation() {
            LauncherController.updateSlowLaunchAnimationFromKeyboardModifiers()
            activeLaunchAnimationSpeedScale = LauncherController.animationSpeedScale
            if (fullscreenFrameLoader.item) {
                fullscreenFrameLoader.item.launchTransitionActive = true
            }
            showAnimation.stop()
            hideAnimation.stop()
            showAnimationKickoffTimer.stop()
            hideVisibilityDeadlineTimer.stop()
            lastShowAnimationStartMs = Date.now()
            updateFullscreenLaunchSourceRect()
            applyLaunchSourceState()
            if (launchAnimationBackdropItem) {
                launchAnimationBackdropItem.opacity = 0
            }
            if (launchAnimationForegroundItem) {
                launchAnimationForegroundItem.opacity = 0
            }
            if (launchAnimationForegroundSnapshotItem) {
                launchAnimationForegroundSnapshotItem.scheduleUpdate()
            }
            showAnimationAwaitingMappedFrame = true
            showVisibilityDeadlineTimer.restart()
            if (active) {
                beginShowAnimation()
            } else {
                mappedFrameFallbackTimer.restart()
            }
        }

        function beginShowAnimation() {
            if (!showAnimationAwaitingMappedFrame) {
                return
            }

            if (!launcherRequestedVisible || !visible) {
                showAnimationAwaitingMappedFrame = false
                mappedFrameFallbackTimer.stop()
                if (fullscreenFrameLoader.item) {
                    fullscreenFrameLoader.item.launchTransitionActive = false
                }
                resetFullscreenContentState()
                return
            }

            showAnimationAwaitingMappedFrame = false
            mappedFrameFallbackTimer.stop()
            if (launchAnimationForegroundSnapshotItem) {
                launchAnimationForegroundSnapshotItem.scheduleUpdate()
            }
            showAnimationKickoffTimer.restart()
        }

        function startShowAnimation() {
            const wasVisible = visible
            hideAnimation.stop()
            hideVisibilityDeadlineTimer.stop()
            keepVisibleWhileAnimating = true
            LauncherController.closeAllPopups()
            if (wasVisible) {
                armShowAnimation()
            }
        }

        function startHideAnimation() {
            LauncherController.updateSlowLaunchAnimationFromKeyboardModifiers()
            activeLaunchAnimationSpeedScale = LauncherController.animationSpeedScale
            keepVisibleWhileAnimating = true
            if (fullscreenFrameLoader.item) {
                fullscreenFrameLoader.item.launchTransitionActive = true
            }
            if (!visible) {
                keepVisibleWhileAnimating = false
                showAnimationAwaitingMappedFrame = false
                mappedFrameFallbackTimer.stop()
                hideVisibilityDeadlineTimer.stop()
                if (fullscreenFrameLoader.item) {
                    fullscreenFrameLoader.item.launchTransitionActive = false
                }
                resetFullscreenContentState()
                return
            }

            updateFullscreenLaunchSourceRect()
            showAnimation.stop()
            showAnimationAwaitingMappedFrame = false
            mappedFrameFallbackTimer.stop()
            showVisibilityDeadlineTimer.stop()
            resetFullscreenContentState()
            if (launchAnimationForegroundSnapshotItem) {
                launchAnimationForegroundSnapshotItem.scheduleUpdate()
            }
            if (fullscreenFrameLoader.item) {
                fullscreenFrameLoader.item.iconGridMotionHiding = true
                fullscreenFrameLoader.item.iconGridMotionSpeedScale = launchAnimationSpeedScale
                fullscreenFrameLoader.item.iconGridMotionSerial += 1
            }
            hideAnimation.restart()
            hideVisibilityDeadlineTimer.restart()
        }

        visible: launcherRequestedVisible || keepVisibleWhileAnimating
        // Set transparent on kwin will cause abnormal rounded corners in FolderPopup, Bug: 10219
        color: "transparent"
        transientParent: null

        Connections {
            target: DS.applet("org.deepin.ds.dock")
            function onScreenNameChanged() {
                LauncherController.visible = false
                reassignFullscreenFrameScreenTimer.start()
            }
        }

        DLayerShellWindow.anchors: DLayerShellWindow.AnchorBottom | DLayerShellWindow.AnchorTop | DLayerShellWindow.AnchorLeft | DLayerShellWindow.AnchorRight
        DLayerShellWindow.layer: DLayerShellWindow.LayerTop
        DLayerShellWindow.keyboardInteractivity: DLayerShellWindow.KeyboardInteractivityOnDemand
        DLayerShellWindow.exclusionZone: -1
        DLayerShellWindow.scope: "dde-shell/launchpad"

        flags: {
            if (DebugHelper.useRegularWindow) return Qt.Window
            return (Qt.FramelessWindowHint | Qt.Window)
        }

        DWindow.enabled: !DebugHelper.useRegularWindow
        DWindow.windowRadius: 0
        DWindow.enableSystemResize: false
        DWindow.enableSystemMove: false
        // Fullscreen mode: always assume dark theme
        DWindow.themeType: ApplicationHelper.DarkType
        DWindow.windowStartUpEffect: PlatformHandle.EffectOut

        Component.onCompleted: {
            resetFullscreenContentState()
            keepVisibleWhileAnimating = launcherRequestedVisible
            visibilityInitialized = true
        }

        onLauncherRequestedVisibleChanged: {
            if (!visibilityInitialized) {
                return
            }

            if (launcherRequestedVisible) {
                startShowAnimation()
            } else {
                startHideAnimation()
            }
        }

        Connections {
            target: LauncherController

            function onVisibleChanged(visible) {
                if (!fullscreenFrame.visibilityInitialized
                        || LauncherController.currentFrame === "WindowedFrame") {
                    return
                }

                if (visible) {
                    if (fullscreenFrameLoader.item) {
                        Qt.callLater(fullscreenFrameLoader.item.activateLauncherInput)
                    }
                }
            }

        }

        onVisibleChanged: {
            if (visible) {
                LauncherController.closeAllPopups()
                if (fullscreenFrameLoader.item) {
                    Qt.callLater(fullscreenFrameLoader.item.activateLauncherInput)
                }
                if (launcherRequestedVisible
                        && !showAnimation.running
                        && !hideAnimation.running
                        && !showAnimationAwaitingMappedFrame) {
                    armShowAnimation()
                }
            }
        }

        onActiveChanged: {
            if (LauncherController.currentFrame !== "FullscreenFrame") {
                return
            }
            if (active) {
                LauncherController.cancelHide()
                if (showAnimationAwaitingMappedFrame) {
                    beginShowAnimation()
                }
                return;
            }
            if (!active && !DebugHelper.avoidHideWindow) {
                if (launchAnimationRunning
                    || (launcherRequestedVisible
                        && Date.now() - lastShowAnimationStartMs < Math.max(320, launchShowAnimationDuration + frameInterval * 4))) {
                    return
                }
                LauncherController.hideWithTimer()
            }
        }

        Item {
            id: fullscreenContentHost
            anchors.fill: parent
            focus: true
            enabled: fullscreenFrame.launcherRequestedVisible

            Loader {
                id: fullscreenFrameLoader
                anchors.fill: parent
                sourceComponent: FullscreenFrame {
                    launchAppFn: function(desktopId) { launchApp(desktopId) }
                    showContextMenuFn: function(item, model, additionalProps) { showContextMenu(item, model, additionalProps || {}) }
                    getCategoryNameFn: function(section) { return getCategoryName(section) }
                }
            }

            Label {
                visible: DebugHelper.qtDebugEnabled
                z: 999

                anchors.right: parent.right
                anchors.bottom: parent.bottom
                text: "/ / Under Construction / /"

                background: Rectangle {
                    color: Qt.rgba(1, 1, 0, 0.5)
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: { debugDialog.open() }
                }
            }
        }

        ParallelAnimation {
            id: showAnimation

            OpacityAnimator {
                target: fullscreenFrame.launchAnimationBackdropItem
                duration: fullscreenFrame.launchBackdropAnimationDuration
                easing.type: Easing.OutQuad
                to: 1
            }

            OpacityAnimator {
                target: fullscreenFrame.launchAnimationForegroundItem
                duration: Math.round(fullscreenFrame.launchShowAnimationDuration * 0.86)
                easing.type: Easing.OutQuad
                to: 1
            }

            onFinished: {
                fullscreenFrame.finishShowAnimation()
            }
        }

        ParallelAnimation {
            id: hideAnimation

            OpacityAnimator {
                target: fullscreenFrame.launchAnimationBackdropItem
                duration: fullscreenFrame.launchBackdropAnimationDuration
                easing.type: Easing.InQuad
                to: 0
            }

            OpacityAnimator {
                target: fullscreenFrame.launchAnimationForegroundItem
                duration: fullscreenFrame.launchHideAnimationDuration
                easing.type: Easing.InQuad
                to: 0
            }

            onFinished: {
                fullscreenFrame.finishHideAnimation()
            }
        }

        Timer {
            id: hideVisibilityDeadlineTimer
            interval: fullscreenFrame.launchHideDeadline
            repeat: false
            onTriggered: {
                hideAnimation.stop()
                fullscreenFrame.finishHideAnimation()
            }
        }

        Timer {
            id: showVisibilityDeadlineTimer
            interval: fullscreenFrame.launchShowDeadline
            repeat: false
            onTriggered: {
                showAnimation.stop()
                fullscreenFrame.finishShowAnimation()
            }
        }

        Timer {
            id: showAnimationKickoffTimer
            interval: 0
            repeat: false
            onTriggered: {
                if (fullscreenFrameLoader.item) {
                    fullscreenFrameLoader.item.iconGridMotionHiding = false
                    fullscreenFrameLoader.item.iconGridMotionSpeedScale = fullscreenFrame.launchAnimationSpeedScale
                    fullscreenFrameLoader.item.iconGridMotionSerial += 1
                }
                showAnimation.restart()
            }
        }

        Timer {
            id: mappedFrameFallbackTimer
            interval: fullscreenFrame.frameInterval
            repeat: false
            onTriggered: {
                fullscreenFrame.beginShowAnimation()
            }
        }

        Connections {
            target: fullscreenFrame
            enabled: fullscreenFrame.showAnimationAwaitingMappedFrame

            function onFrameSwapped() {
                fullscreenFrame.beginShowAnimation()
            }
        }
    }

    PanelPopup {
        id: windowedModeLauncher

        property bool visibility: LauncherController.visible && (LauncherController.currentFrame === "WindowedFrame")

        width: 610
        height: 480
        windowTitle: "dde-shell/launchpad"
        popupX: DockPanelPositioner.x
        popupY: DockPanelPositioner.y
        DockPanelPositioner.bounding: Qt.rect(launcher.itemPos.x + width / 2 * ((Panel.position + 1) % 2),
                                              launcher.itemPos.y + height / 2 * (Panel.position % 2),
                                              width, height)

        WindowedFrame {
            anchors.fill: parent
        }

        onVisibilityChanged: function() {
            if (visibility) {
                if (!windowedModeLauncher.visible) {
                    windowedModeLauncher.open()
                }
            } else {
                windowedModeLauncher.close()
            }
        }
        onPopupVisibleChanged: function() {
            if (LauncherController.currentFrame !== "WindowedFrame") return
            if (popupVisible !== visibility) {
                LauncherController.visible = popupVisible
            }
        }
    }

    D.DciIcon {
        id: icon
        anchors.centerIn: parent
        name: Applet.iconName
        scale: Panel.rootObject.dockItemMaxSize * 9 / 14 / Dock.MAX_DOCK_TASKMANAGER_ICON_SIZE
        // 9:14 (iconSize/dockHeight)
        sourceSize: Qt.size(Dock.MAX_DOCK_TASKMANAGER_ICON_SIZE, Dock.MAX_DOCK_TASKMANAGER_ICON_SIZE)
        onXChanged: updateLaunchpadPos()
        onYChanged: updateLaunchpadPos()
        onWidthChanged: updateFullscreenLaunchSourceRect()
        onHeightChanged: updateFullscreenLaunchSourceRect()
        onScaleChanged: updateFullscreenLaunchSourceRect()
    }
    Timer {
        id: toolTipShowTimer
        interval: 50
        onTriggered: {
            var point = Applet.rootObject.mapToItem(null, Applet.rootObject.width / 2, Applet.rootObject.height / 2)
            toolTip.DockPanelPositioner.bounding = Qt.rect(point.x, point.y, toolTip.width, toolTip.height)
            toolTip.open()
        }
    }

    // FIXME: The TapHandler receives the event after visibleChange, which causes the state to be inverted after synchronization,
    // causing the launchpad to be displayed again. However, the MouseArea receives the event before visibleChange.
    MouseArea {
        id: mouseHandler
        anchors.fill: parent
        onPressed: function (mouse) {
            if (mouse.button === Qt.LeftButton) {
                const now = Date.now()
                if (recentlyHidAfterDockDeactivation(now)) {
                    mouse.accepted = true
                    return
                }
                if (now - launcher.lastPanelEdgeToggleMs < launcher.crossSourceToggleGuardInterval) {
                    mouse.accepted = true
                    return
                }
                if (fullscreenFrame.launchAnimationRunning) {
                    mouse.accepted = true
                    return
                }
                launcher.lastDockMousePressMs = now
                toggleLauncher()
                mouse.accepted = true
            }
        }
    }
    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                toolTipShowTimer.start()
            } else {
                if (toolTipShowTimer.running) {
                    toolTipShowTimer.stop()
                }

                toolTip.close()
            }
        }
    }
}
