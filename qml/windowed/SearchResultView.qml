// SPDX-FileCopyrightText: 2024 - 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQml.Models 2.15
import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.deepin.dtk 1.0

import org.deepin.launchpad 1.0
import org.deepin.launchpad.models 1.0
import "."

Control {
    id: control

    property Item nextKeyTabTarget
    property Item keyTabTarget: currentGrid ? currentGrid : searchResultPagesView
    readonly property int pageSize: 4 * 4
    readonly property int columns: 4
    readonly property int resultCount: SearchFilterProxyModel.count
    readonly property int pageCount: Math.ceil(resultCount / pageSize)
    readonly property real pageWidth: 80 * 4 + Helper.frequentlyUsed.cellPaddingColumns * 4
    readonly property real pageHeight: 82 * 4 + Helper.frequentlyUsed.cellPaddingRows * 4
    readonly property Item currentGrid: searchResultPagesView.currentItem ? searchResultPagesView.currentItem.gridItem : null

    onFocusChanged: () => {
        if (currentGrid) {
            currentGrid.focus = true
        } else {
            searchResultPagesView.focus = true
        }
    }

    function launchCurrentItem() {
        currentGrid?.currentItem?.itemClicked()
    }

    function setCurrentGlobalIndex(index) {
        if (resultCount <= 0) {
            searchResultPagesView.pendingGridIndex = 0
            searchResultPagesView.setCurrentIndex(0)
            return
        }

        const clampedIndex = Math.max(0, Math.min(index, resultCount - 1))
        const targetPage = Math.floor(clampedIndex / pageSize)
        const pageLocalIndex = clampedIndex % pageSize

        searchResultPagesView.pendingGridIndex = pageLocalIndex
        if (searchResultPagesView.currentIndex !== targetPage) {
            searchResultPagesView.setCurrentIndex(targetPage)
        } else if (searchResultPagesView.currentItem) {
            searchResultPagesView.currentItem.currentIndex =
                    Math.min(pageLocalIndex, Math.max(0, searchResultPagesView.currentItem.count - 1))
            searchResultPagesView.pendingGridIndex = -1
        }
    }

    function currentGlobalIndex() {
        if (resultCount <= 0) {
            return 0
        }

        const pageIndex = Math.max(0, searchResultPagesView.currentIndex)
        const localIndex = currentGrid ? Math.max(0, currentGrid.currentIndex) : 0
        return Math.min(resultCount - 1, pageIndex * pageSize + localIndex)
    }

    function revealCurrentFocusHighlight() {
        if (currentGrid && typeof currentGrid.revealFocusHighlight === "function") {
            currentGrid.revealFocusHighlight()
        }
    }

    function hideCurrentFocusHighlight() {
        if (currentGrid && typeof currentGrid.hideFocusHighlight === "function") {
            currentGrid.hideFocusHighlight()
        }
    }

    function currentFocusHighlightVisible() {
        return currentGrid ? currentGrid.focusHighlightVisible : false
    }

    function selectFirstItemForInitialDirectionKey() {
        if (currentFocusHighlightVisible()) {
            return false
        }

        setCurrentGlobalIndex(0)
        Qt.callLater(function() {
            control.revealCurrentFocusHighlight()
        })
        return true
    }

    function targetIndexForKey(key, index) {
        const pageStartIndex = Math.floor(index / pageSize) * pageSize
        const pageLocalIndex = index - pageStartIndex
        const currentPageCount = Math.min(pageSize, resultCount - pageStartIndex)

        switch (key) {
        case Qt.Key_Left:
            return index > 0 ? index - 1 : resultCount - 1
        case Qt.Key_Right:
            return index < resultCount - 1 ? index + 1 : 0
        case Qt.Key_Up:
            if (pageLocalIndex >= columns) {
                return index - columns
            }
            return pageStartIndex > 0 ? pageStartIndex - 1 : index
        case Qt.Key_Down:
            if (pageLocalIndex + columns < currentPageCount) {
                return index + columns
            }
            return pageStartIndex + pageSize < resultCount ? pageStartIndex + pageSize : index
        default:
            return index
        }
    }

    function moveCurrentSelectionByKey(key) {
        if (resultCount <= 0) {
            return true
        }

        const current = currentGlobalIndex()
        switch (key) {
        case Qt.Key_Left:
        case Qt.Key_Right:
        case Qt.Key_Up:
        case Qt.Key_Down:
            break
        default:
            return false
        }

        if (selectFirstItemForInitialDirectionKey()) {
            return true
        }

        const targetIndex = targetIndexForKey(key, current)
        setCurrentGlobalIndex(targetIndex)
        Qt.callLater(function() {
            control.revealCurrentFocusHighlight()
        })
        return true
    }

    function resetCurrentPage() {
        hideCurrentFocusHighlight()
        searchResultPagesView.pendingGridIndex = 0
        searchResultPagesView.setCurrentIndex(0)
        if (searchResultPagesView.currentItem) {
            searchResultPagesView.currentItem.currentIndex = 0
        }
    }

    ListModel {
        id: emptyModel
    }

    contentItem: ColumnLayout {
        spacing: 0
        visible: control.resultCount > 0

        Label {
            text: qsTr("All Apps")
            font: LauncherController.adjustFontWeight(DTK.fontManager.t6, Font.Bold)
        }

        ListView {
            id: searchResultPagesView

            KeyNavigation.tab: nextKeyTabTarget
            Layout.alignment: Qt.AlignRight
            Layout.topMargin: 10
            Layout.rightMargin: 10
            Layout.preferredHeight: control.pageHeight
            Layout.preferredWidth: control.pageWidth
            clip: true
            snapMode: ListView.SnapOneItem
            orientation: ListView.Horizontal
            highlightRangeMode: ListView.StrictlyEnforceRange
            highlightFollowsCurrentItem: true
            highlightMoveDuration: 150 * LauncherController.animationSpeedScale
            highlightMoveVelocity: -1
            cacheBuffer: width
            interactive: control.pageCount > 1
            activeFocusOnTab: gridViewFocus
            focus: true
            model: control.pageCount

            property int pendingGridIndex: -1
            property bool gridViewFocus: true

            function setCurrentIndex(index) {
                currentIndex = Math.max(0, Math.min(index, count - 1))
            }

            function handleWheelPage(wheel) {
                const toPage = Helper.wheelPageStep(wheel)
                if (toPage === 0 || count <= 1) {
                    return
                }

                wheel.accepted = true
                if (searchResultWheelPageDelay.running) {
                    return
                }

                if (toPage < 0 && currentIndex > 0) {
                    searchResultWheelPageDelay.start()
                    setCurrentIndex(currentIndex - 1)
                } else if (toPage > 0 && currentIndex < count - 1) {
                    searchResultWheelPageDelay.start()
                    setCurrentIndex(currentIndex + 1)
                }
            }

            Timer {
                id: searchResultWheelPageDelay
                interval: Math.max(1, Math.round(150 * LauncherController.animationSpeedScale))
                repeat: false
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: function(wheel) {
                    searchResultPagesView.handleWheelPage(wheel)
                }
            }

            onCurrentItemChanged: {
                if (currentItem && pendingGridIndex >= 0) {
                    currentItem.currentIndex = Math.min(pendingGridIndex, Math.max(0, currentItem.count - 1))
                    pendingGridIndex = -1
                }
            }

            delegate: Item {
                id: pageDelegate
                readonly property int pageIndex: index

                width: searchResultPagesView.width
                height: searchResultPagesView.height

                property alias gridItem: searchResultViewContainer
                property alias currentIndex: searchResultViewContainer.currentIndex
                readonly property int count: pageSliceModel.count

                PageSliceProxyModel {
                    id: pageSliceModel
                    sourceModel: SearchFilterProxyModel
                    pageSize: control.pageSize
                    pageIndex: pageDelegate.pageIndex
                }

                GridViewContainer {
                    id: searchResultViewContainer
                    anchors.centerIn: parent
                    KeyNavigation.tab: control.nextKeyTabTarget
                    interactive: false
                    alwaysShowHighlighted: true
                    showFocusHighlightWithoutActiveFocus: true
                    model: pageSliceModel
                    activeFocusOnTab: searchResultPagesView.gridViewFocus

                    delegate: IconItemDelegate {
                        width: searchResultViewContainer.cellWidth
                        height: searchResultViewContainer.cellHeight
                        iconSource: iconName
                        onItemClicked: {
                            searchResultViewContainer.hideFocusHighlight()
                            launchApp(desktopId)
                        }
                        onMenuTriggered: {
                            searchResultViewContainer.hideFocusHighlight()
                            showContextMenu(this, model)
                            baseLayer.forceActiveFocus(Qt.MouseFocusReason)
                        }
                    }

                    Keys.onLeftPressed: function(event) {
                        event.accepted = true
                        control.moveCurrentSelectionByKey(event.key)
                    }

                    Keys.onRightPressed: function(event) {
                        event.accepted = true
                        control.moveCurrentSelectionByKey(event.key)
                    }

                    Keys.onUpPressed: function(event) {
                        event.accepted = true
                        control.moveCurrentSelectionByKey(event.key)
                    }

                    Keys.onDownPressed: function(event) {
                        event.accepted = true
                        control.moveCurrentSelectionByKey(event.key)
                    }
                }
            }
        }

        PageIndicator {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            visible: control.pageCount > 1
            count: control.pageCount
            currentIndex: searchResultPagesView.currentIndex
            interactive: true
            spacing: 5
            onCurrentIndexChanged: {
                if (searchResultPagesView.currentIndex !== currentIndex) {
                    searchResultPagesView.setCurrentIndex(currentIndex)
                }
            }
        }

        Item {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: control.resultCount <= 0
        DciIcon {
            Layout.alignment: Qt.AlignCenter
            sourceSize {
                width: 128
                height: width
            }
            name: "search_no_result"
            palette: DTK.makeIconPalette(control.palette)
            theme: DTK.toColorType(control.palette.window)
        }

        Label {
            Layout.alignment: Qt.AlignCenter
            text: qsTr("No search results")
        }
    }

    Connections {
        target: SearchFilterProxyModel
        function onCountChanged() {
            control.resetCurrentPage()
        }
    }

    background: DebugBounding { }
}
