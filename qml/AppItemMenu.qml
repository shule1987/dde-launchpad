// SPDX-FileCopyrightText: 2023 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15

import org.deepin.launchpad 1.0
import org.deepin.launchpad.models 1.0

Item {
    id: root

    property string display
    property string desktopId
    property string iconName
    property bool isFavoriteItem
    property bool hideFavoriteMenu
    property bool hideMoveToTopMenu
    property bool hideDisplayScalingMenu
    readonly property bool isFullscreen: LauncherController.currentFrame === "FullscreenFrame"
    readonly property bool isHorizontalDock: DesktopIntegration.dockPosition === Qt.UpArrow || DesktopIntegration.dockPosition === Qt.DownArrow
    readonly property int dockSpacing: (isHorizontalDock ? DesktopIntegration.dockGeometry.height : DesktopIntegration.dockGeometry.width) / Screen.devicePixelRatio
    property bool closing: false
    property bool menuRunning: false
    property bool closedEmitted: false
    signal closed()

    visible: false
    width: 0
    height: 0

    Connections {
        target: LauncherController
        function onVisibleChanged(visible) {
            if (!visible) {
                root.close()
            }
        }
    }

    function popup() {
        closing = false
        Qt.callLater(openStandardMenu)
    }

    function close() {
        closing = true
        if (menuRunning) {
            DesktopIntegration.closeStandardContextMenu()
        } else {
            finish()
        }
    }

    function finish() {
        if (closedEmitted) {
            return
        }

        closedEmitted = true
        closed()
    }

    function openStandardMenu() {
        if (closing) {
            finish()
            return
        }

        const command = popupMenu()
        if (!closing) {
            handleCommand(command)
        }
        finish()
    }

    function popupMenu() {
        let command = ""
        menuRunning = true
        LauncherController.setAvoidHide(false)
        try {
            command = DesktopIntegration.popupStandardContextMenu(menuItems(),
                                                                  isFullscreen && DesktopIntegration.dockPosition === Qt.UpArrow ? dockSpacing : 0,
                                                                  isFullscreen && DesktopIntegration.dockPosition === Qt.RightArrow ? dockSpacing : 0,
                                                                  isFullscreen && DesktopIntegration.dockPosition === Qt.DownArrow ? dockSpacing : 0,
                                                                  isFullscreen && DesktopIntegration.dockPosition === Qt.LeftArrow ? dockSpacing : 0)
        } finally {
            LauncherController.setAvoidHide(true)
            menuRunning = false
        }
        return command
    }

    function menuItems() {
        const isFolder = root.desktopId.startsWith("internal/folders/")
        const isInternal = root.desktopId.startsWith("internal/")
        const pinToTopVisible = isFavoriteItem && !hideFavoriteMenu
        const favoriteVisible = !hideFavoriteMenu
        const displayScalingVisible = !hideDisplayScalingMenu

        return [
            { command: "open", text: qsTr("Open"), enabled: !isFolder },
            { separator: true },
            { command: "pinToTop", text: qsTr("Pin to Top"), visible: pinToTopVisible, enabled: false },
            { command: "moveToTop", text: qsTr("Move to Top"), visible: !hideMoveToTopMenu, enabled: !hideMoveToTopMenu },
            {
                command: "favorite",
                text: FavoritedProxyModel.exists(root.desktopId) ? qsTr("Remove from favorites") : qsTr("Add to favorites"),
                visible: favoriteVisible,
                enabled: false
            },
            { separator: true, visible: pinToTopVisible && favoriteVisible },
            {
                command: "desktop",
                text: DesktopIntegration.isOnDesktop(root.desktopId) ? qsTr("Remove from desktop") : qsTr("Send to desktop"),
                enabled: !isFolder
            },
            {
                command: "dock",
                text: DesktopIntegration.isDockedApp(root.desktopId) ? qsTr("Remove from dock") : qsTr("Send to dock"),
                enabled: !isInternal
            },
            { separator: true },
            {
                command: "autoStart",
                text: DesktopIntegration.isAutoStart(root.desktopId) ? qsTr("Remove from startup") : qsTr("Add to startup"),
                enabled: !isFolder
            },
            { command: "proxy", text: qsTr("Use a proxy"), visible: false, enabled: false },
            {
                command: "displayScaling",
                text: qsTr("Disable display scaling"),
                visible: displayScalingVisible,
                enabled: displayScalingVisible && !isFolder,
                checkable: true,
                checked: !!DesktopIntegration.disableScale(root.desktopId)
            },
            {
                command: "uninstall",
                text: qsTr("Uninstall"),
                enabled: !isFolder && !DesktopIntegration.appIsCompulsoryForDesktop(root.desktopId)
            }
        ]
    }

    function handleCommand(command) {
        switch (command) {
        case "open":
            launchApp(root.desktopId)
            break
        case "pinToTop":
            FavoritedProxyModel.pinToTop(root.desktopId)
            break
        case "moveToTop":
            ItemArrangementProxyModel.bringToFront(root.desktopId)
            break
        case "favorite":
            if (FavoritedProxyModel.exists(root.desktopId)) {
                FavoritedProxyModel.removeFavorite(root.desktopId)
            } else {
                FavoritedProxyModel.addFavorite(root.desktopId)
            }
            break
        case "desktop":
            if (DesktopIntegration.isOnDesktop(root.desktopId)) {
                DesktopIntegration.removeFromDesktop(root.desktopId)
            } else {
                DesktopIntegration.sendToDesktop(root.desktopId)
            }
            break
        case "dock":
            if (DesktopIntegration.isDockedApp(root.desktopId)) {
                DesktopIntegration.removeFromDock(root.desktopId)
            } else {
                DesktopIntegration.sendToDock(root.desktopId)
            }
            break
        case "autoStart":
            DesktopIntegration.setAutoStart(root.desktopId, !DesktopIntegration.isAutoStart(root.desktopId))
            break
        case "displayScaling":
            DesktopIntegration.setDisableScale(root.desktopId, !DesktopIntegration.disableScale(root.desktopId))
            break
        case "uninstall":
            uninstallSelectedApp()
            break
        }
    }

    function uninstallSelectedApp() {
        if (DesktopIntegration.shouldSkipConfirmUninstallDialog(root.desktopId)) {
            DesktopIntegration.uninstallApp(root.desktopId)
            return
        }

        LauncherController.setAvoidHide(false)
        try {
            DesktopIntegration.confirmUninstallApp(root.desktopId, root.display, root.iconName)
        } finally {
            LauncherController.setAvoidHide(true)
        }
    }
}
