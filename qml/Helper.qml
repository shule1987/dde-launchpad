// SPDX-FileCopyrightText: 2024 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

pragma Singleton
import QtQuick 2.0
import org.deepin.dtk 1.0 as D

QtObject {
    property QtObject windowed :QtObject {
        property int topMargin: 11
        property int splitLineWidth: 1
        property int bottomBarMargins: 10
        property int maxViewRows: 4
        property int doubleRowMaxFontSize: 12
        property int listItemHeight: 36
    }
    property QtObject fullscreen :QtObject {
        property int doubleRowMaxFontSize: 14
    }
    property QtObject frequentlyUsed :QtObject {
        property int leftMargin: 10
        property int rightMargin: 10
        property int cellPaddingColumns: 14
        property int cellPaddingRows: 6
    }

    property D.Palette itemBackground: D.Palette {
        normal {
            common: ("transparent")
            crystal: ("transparent")
        }
        hovered {
            common: Qt.rgba(0, 0, 0, 0.1)
            crystal: Qt.rgba(0, 0, 0, 0.1)
        }
        hoveredDark {
            common: Qt.rgba(1, 1, 1, 0.1)
            crystal: Qt.rgba(1, 1, 1, 0.1)
        }
    }

    function generateDragMimeData(desktopId, dockOnly = false) {
        // In some cases an app is not allowed to be pinned onto dock via drag-n-drop;
        // We only insert the MIME data for dde-dock in those allowed cases.
        let mime = {}
        if (!dockOnly) {
            mime["text/x-dde-launcher-dnd-desktopId"] = desktopId
        }
        if (!DesktopIntegration.appIsDummyPackage(desktopId)) {
            mime["text/x-dde-dock-dnd-appid"] = desktopId
            mime["text/x-dde-dock-dnd-source"] = "launcher"
        }
        return mime
    }

    function dragDesktopId(drag) {
        if (!drag) {
            return ""
        }

        if (typeof drag.getDataAsString === "function") {
            const mimeId = drag.getDataAsString("text/x-dde-launcher-dnd-desktopId")
            if (mimeId !== "") {
                return mimeId
            }
        }

        if (drag.source && typeof drag.source.currentlyDraggedId !== "undefined") {
            return drag.source.currentlyDraggedId
        }

        return ""
    }

    function pointComponent(point, component) {
        if (!point) {
            return 0
        }

        const value = point[component]
        if (typeof value === "number") {
            return value
        }

        if (typeof value === "function") {
            return value.call(point)
        }

        return 0
    }

    function wheelDeltaX(wheel) {
        if (!wheel) {
            return 0
        }

        const pixelX = pointComponent(wheel.pixelDelta, "x")
        const angleX = pointComponent(wheel.angleDelta, "x") / 8
        return pixelX !== 0 ? pixelX : angleX
    }

    function wheelDeltaY(wheel) {
        if (!wheel) {
            return 0
        }

        const pixelY = pointComponent(wheel.pixelDelta, "y")
        const angleY = pointComponent(wheel.angleDelta, "y") / 8
        return pixelY !== 0 ? pixelY : angleY
    }

    function wheelPageStep(wheel) {
        const xDelta = wheelDeltaX(wheel)
        const yDelta = wheelDeltaY(wheel)

        if (Math.abs(xDelta) >= Math.abs(yDelta) && xDelta !== 0) {
            return xDelta > 0 ? 1 : -1
        }

        if (yDelta !== 0) {
            return yDelta > 0 ? -1 : 1
        }

        return 0
    }
}
