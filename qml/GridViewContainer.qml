// SPDX-FileCopyrightText: 2023 - 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQml.Models 2.15
import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15
import org.deepin.dtk 1.0

FocusScope {
    id: root
    visible: true

    property alias model: gridView.model
    property alias delegate: gridView.delegate
    property alias placeholderIcon: placeholderIcon.name
    property alias placeholderIconSize: placeholderIcon.sourceSize.width
    property alias placeholderText: placeholderLabel.text
    property alias interactive: gridView.interactive
    property alias padding: item.anchors.margins
    property alias gridViewFocus: gridView.focus
    property alias gridViewClip: gridView.clip
    property ScrollBar vScrollBar
    property bool activeGridViewFocusOnTab: false
    property bool alwaysShowHighlighted: false
    property Transition itemMove
    property bool itemTransitionsEnabled: true
    required property int columns
    required property int rows
    property real paddingColumns: 0
    property real paddingRows: paddingColumns
    property bool compactCentered: false
    property int compactItemCount: gridView.count
    property alias cellHeight: item.cellHeight
    property alias cellWidth: item.cellWidth

    property alias currentIndex: gridView.currentIndex
    readonly property alias currentItem: gridView.currentItem
    readonly property alias gridViewWidth: gridView.width
    readonly property bool isWindowedMode: LauncherController.currentFrame === "WindowedFrame"

    function setPreviousPageSwitch(state) {
        if (state)
            gridView.currentIndex = gridView.count - 1
        else
            gridView.currentIndex = 0
    }

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

        readonly property real availableGridWidth: root.compactCentered
            ? Math.max(1, width - root.paddingColumns * Math.max(0, root.columns - 1))
            : width
        readonly property real availableGridHeight: root.compactCentered
            ? Math.max(1, height - root.paddingRows * Math.max(0, root.rows - 1))
            : height
        property int cellHeight: root.rows == 0
            ? (availableGridWidth / (root.columns + (root.compactCentered ? 0 : root.paddingColumns * 2)))
            : Math.min(availableGridWidth / (root.columns + (root.compactCentered ? 0 : root.paddingColumns * 2)),
                       availableGridHeight / Math.max(1, root.rows + (root.compactCentered ? 0 : root.paddingRows * 2)))
        property int cellWidth: cellHeight
        readonly property real gridCellWidth: cellWidth + (root.compactCentered ? root.paddingColumns : 0)
        readonly property real gridCellHeight: cellHeight + (root.compactCentered ? root.paddingRows : 0)
        readonly property int visibleColumns: root.compactCentered && root.compactItemCount > 0
            ? Math.min(root.columns, root.compactItemCount)
            : root.columns
        readonly property int visibleRows: root.compactCentered && root.compactItemCount > 0
            ? Math.min(root.rows, Math.ceil(root.compactItemCount / Math.max(1, root.columns)))
            : root.rows
        Rectangle {
            x: Math.round((parent.width - width) / 2)
            y: root.compactCentered ? 0 : Math.round((parent.height - height) / 2)
            width: {
                if (root.compactCentered) {
                    return item.cellWidth * item.visibleColumns + root.paddingColumns * Math.max(0, item.visibleColumns - 1)
                } else {
                    return item.cellWidth * root.columns
                }
            }
            height: {
                if (root.compactCentered) {
                    return item.cellHeight * item.visibleRows + root.paddingRows * Math.max(0, item.visibleRows - 1)
                } else {
                    return root.rows == 0 ? parent.height : (item.cellHeight * root.rows)
                }
            }
            color: "transparent"

                GridView {
                    id: gridView

                    ScrollBar.vertical: root.vScrollBar

                anchors.fill: parent
                clip: true
                highlightFollowsCurrentItem: true
                keyNavigationEnabled: true
                highlightMoveDuration: 100 * LauncherController.animationSpeedScale
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
                    cellHeight: item.gridCellHeight
                    cellWidth: item.gridCellWidth

                    highlight: Item {
                        FocusBoxBorder {
                        anchors {
                            fill: parent
                            margins: 5
                        }
                        radius: isWindowedMode ? 8 : 18
                        color: parent.palette.highlight
                        visible: gridView.activeFocus
                    }
                    Rectangle {
                        anchors {
                            fill: parent
                            margins: 5
                        }
                        radius: 18
                        color: Qt.rgba(1, 1, 1, 0.2)
                        visible: alwaysShowHighlighted
                    }
                }

                // Keep item reflow smooth during drag-reorder and folder insert/remove.
                add: root.itemTransitionsEnabled ? root.itemMove : null
                move: root.itemTransitionsEnabled ? root.itemMove : null
                remove: root.itemTransitionsEnabled ? root.itemMove : null
                displaced: root.itemTransitionsEnabled ? root.itemMove : null
                moveDisplaced: root.itemTransitionsEnabled ? root.itemMove : null
            }
        }

        ColumnLayout {
            visible: placeholderLabel.text !== "" && model.count <= 0
            anchors.centerIn: parent

            Control {
                id: control
                contentItem: DciIcon {
                    id: placeholderIcon
                    visible: name !== ""
                    sourceSize {
                        width: 128
                        height: width
                    }
                    palette: DTK.makeIconPalette(control.palette)
                    theme: DTK.toColorType(control.palette.window)
                }
            }

            Label {
                id: placeholderLabel
                Layout.alignment: Qt.AlignCenter
            }
        }
    }
}
