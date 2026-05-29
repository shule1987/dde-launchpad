// SPDX-FileCopyrightText: 2024 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15

import org.deepin.launchpad 1.0

Item {
    id: root

    property string desktopId
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

        let command = ""
        menuRunning = true
        LauncherController.setAvoidHide(false)
        try {
            command = DesktopIntegration.popupStandardContextMenu([
                { command: "install", text: qsTr("Install") },
                { command: "remove", text: qsTr("Remove") }
            ],
                                                                  isFullscreen && DesktopIntegration.dockPosition === Qt.UpArrow ? dockSpacing : 0,
                                                                  isFullscreen && DesktopIntegration.dockPosition === Qt.RightArrow ? dockSpacing : 0,
                                                                  isFullscreen && DesktopIntegration.dockPosition === Qt.DownArrow ? dockSpacing : 0,
                                                                  isFullscreen && DesktopIntegration.dockPosition === Qt.LeftArrow ? dockSpacing : 0)
        } finally {
            LauncherController.setAvoidHide(true)
            menuRunning = false
        }

        if (!closing) {
            if (command === "install") {
                launchApp(root.desktopId)
            } else if (command === "remove") {
                DesktopIntegration.uninstallApp(root.desktopId)
            }
        }

        finish()
    }
}
