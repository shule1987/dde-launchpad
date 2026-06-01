// SPDX-FileCopyrightText: 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

pragma Singleton

import QtQuick 2.15
import org.deepin.dtk 1.0 as D

QtObject {
    property QtObject windowed: QtObject {
        property int doubleRowMaxFontSize: 12
        property int listItemHeight: 36
    }

    property QtObject fullscreen: QtObject {
        property int doubleRowMaxFontSize: 14
    }

    property D.Palette itemBackground: D.Palette {
        normal {
            common: Qt.rgba(0, 0, 0, 0)
            crystal: Qt.rgba(0, 0, 0, 0)
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

    function generateDragMimeData(desktopId) {
        return {
            "text/x-dde-launcher-dnd-desktopId": desktopId,
            "text/x-dde-dock-dnd-appid": desktopId,
            "text/x-dde-dock-dnd-source": "launcher"
        }
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
}
