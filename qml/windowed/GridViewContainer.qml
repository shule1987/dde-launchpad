// SPDX-FileCopyrightText: 2023 - 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQml.Models 2.15
import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15
import org.deepin.dtk 1.0

import org.deepin.launchpad 1.0

FocusScope {
    id: root
    visible: true
    width: gridView.width
    height: gridView.height

    property alias count: gridView.count
    property alias model: gridView.model
    property alias delegate: gridView.delegate
    property alias interactive: gridView.interactive
    property alias gridViewFocus: gridView.focus
    property bool alwaysShowHighlighted: false
    property alias gridViewClip: gridView.clip
    property bool activeGridViewFocusOnTab: false
    property int columns: 4
    property int rows: Math.min(Math.ceil(count * 1.0 / columns), Helper.windowed.maxViewRows)
    property int paddingColumns: Helper.frequentlyUsed.cellPaddingColumns
    property int paddingRows: Helper.frequentlyUsed.cellPaddingRows
    property real cellHeight: 82
    property real cellWidth: 80
    property bool compactCentered: false
    property int compactItemCount: gridView.count
    property Transition itemMove
    property bool itemTransitionsEnabled: true

    readonly property alias currentItem: gridView.currentItem
    readonly property alias gridViewWidth: gridView.width
    property alias highlight: gridView.highlight
    property ScrollBar vScrollBar
    property alias currentIndex: gridView.currentIndex

    function itemAt(x, y) {
        let point = mapToItem(gridView, x, y)
        return gridView.itemAt(point.x, point.y)
    }

    function indexAt(x, y) {
        let point = mapToItem(gridView, x, y)
        return gridView.indexAt(point.x, point.y)
    }

    Item {
        id: item
        visible: true
        anchors.fill: parent

        readonly property int visibleColumns: root.compactCentered && root.compactItemCount > 0
            ? Math.min(root.columns, root.compactItemCount)
            : root.columns
        readonly property int visibleRows: root.compactCentered && root.compactItemCount > 0
            ? Math.min(root.rows, Math.ceil(root.compactItemCount / Math.max(1, root.columns)))
            : root.rows

        GridView {
            id: gridView
            width: {
                if (root.compactCentered) {
                    return root.cellWidth * item.visibleColumns + paddingColumns * Math.max(0, item.visibleColumns - 1)
                }
                return root.cellWidth * columns + paddingColumns * Math.max(0, columns - 1) + paddingColumns
            }
            height: {
                if (root.compactCentered) {
                    return root.cellHeight * item.visibleRows + paddingRows * Math.max(0, item.visibleRows - 1)
                }
                return root.cellHeight * rows + paddingRows * Math.max(0, rows - 1) + paddingRows
            }
            ScrollBar.vertical: root.vScrollBar

            x: Math.round((parent.width - width) / 2)
            y: root.compactCentered ? 0 : Math.round((parent.height - height) / 2)
            clip: true

            interactive: false
            highlightFollowsCurrentItem: true
            highlightMoveDuration: 100 * LauncherController.animationSpeedScale
            keyNavigationEnabled: true
            activeFocusOnTab: focus ? root.activeGridViewFocusOnTab : false
            focus: count > 0
            onActiveFocusChanged: {
                if (activeFocus) {
                    let snapMode = gridView.snapMode
                    let preferredHighlightBegin = gridView.preferredHighlightBegin
                    gridView.snapMode = GridView.SnapToRow
                    gridView.preferredHighlightBegin = 0
                    gridView.positionViewAtIndex(gridView.currentIndex, GridView.SnapPosition)
                    gridView.snapMode = snapMode
                    gridView.preferredHighlightBegin = preferredHighlightBegin
                }
            }
            cellHeight: root.cellHeight + paddingRows
            cellWidth: root.cellWidth + paddingColumns

            displaced: root.itemTransitionsEnabled ? root.itemMove : null
            move: root.itemTransitionsEnabled ? root.itemMove : null
            moveDisplaced: root.itemTransitionsEnabled ? root.itemMove : null

            highlight: Item {
                FocusBoxBorder {
                    anchors {
                        fill: parent
                        margins: 5
                    }
                    radius: 8
                    color: parent.palette.highlight
                    visible: gridView.activeFocus
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: DTK.themeType === ApplicationHelper.DarkType ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(0, 0, 0, 0.15)
                    visible: alwaysShowHighlighted
                }
            }

            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_Left ||
                    event.key === Qt.Key_Right ||
                    event.key === Qt.Key_Up ||
                    event.key === Qt.Key_Down) {

                    if (!keyTimer.running) {
                        keyTimer.start()
                    } else {
                        event.accepted = true
                    }
                }
            }
            Timer {
                id: keyTimer
                interval: 100
            }
        }
    }
}
