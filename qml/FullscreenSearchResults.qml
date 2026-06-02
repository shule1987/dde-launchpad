// SPDX-FileCopyrightText: 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQml.Models 2.15
import QtQuick 2.15
import QtQuick.Controls 2.15

import org.deepin.launchpad 1.0
import org.deepin.launchpad.models 1.0

Item {
    id: root

    required property real cellWidth
    required property real cellHeight
    required property real iconScaleFactor
    required property var launchAppFn
    required property var showContextMenuFn
    property var handleWheelPageFn: null

    property alias pageView: searchPagesView
    property int currentIndex: 0
    readonly property Item currentItem: searchPagesView.currentItem ? searchPagesView.currentItem.currentItem : null
    readonly property int resultCount: SearchFilterProxyModel.count
    readonly property int pageSize: 4 * 7
    readonly property int pageCount: Math.ceil(resultCount / pageSize)
    readonly property int pageSwitchDuration: 600
    property bool syncingCurrentIndex: false

    function pageSwitchAnimationDuration() {
        return Math.max(1, Math.round(pageSwitchDuration * LauncherController.animationSpeedScale))
    }

    function setCurrentGlobalIndex(index) {
        if (resultCount <= 0) {
            syncingCurrentIndex = true
            currentIndex = 0
            syncingCurrentIndex = false
            return
        }

        const clampedIndex = Math.max(0, Math.min(index, resultCount - 1))
        const targetPage = Math.floor(clampedIndex / pageSize)
        const pageLocalIndex = clampedIndex % pageSize

        searchPagesView.pendingGridIndex = pageLocalIndex
        if (searchPagesView.currentIndex !== targetPage) {
            searchPagesView.setCurrentIndex(targetPage)
        } else if (searchPagesView.currentItem) {
            searchPagesView.currentItem.currentIndex = Math.min(pageLocalIndex, Math.max(0, searchPagesView.currentItem.count - 1))
            searchPagesView.pendingGridIndex = -1
        }

        syncingCurrentIndex = true
        currentIndex = clampedIndex
        syncingCurrentIndex = false
    }

    function updateCurrentIndexFromPage() {
        if (!searchPagesView.currentItem || resultCount <= 0) {
            return
        }

        const pageIndex = Math.max(0, searchPagesView.currentIndex)
        const localIndex = Math.max(0, searchPagesView.currentItem.currentIndex)
        const globalIndex = Math.min(resultCount - 1, pageIndex * pageSize + localIndex)
        syncingCurrentIndex = true
        currentIndex = globalIndex
        syncingCurrentIndex = false
    }

    function handleWheelPage(wheel) {
        if (typeof handleWheelPageFn === "function") {
            handleWheelPageFn(wheel, searchPagesView)
        }
    }

    onCurrentIndexChanged: {
        if (!syncingCurrentIndex) {
            setCurrentGlobalIndex(currentIndex)
        }
    }

    ListModel {
        id: emptyModel
    }

    GridViewContainer {
        id: emptySearchResultGrid
        anchors.fill: parent
        visible: root.resultCount <= 0
        rows: 4
        columns: 7
        cellWidth: root.cellWidth
        cellHeight: root.cellHeight
        paddingColumns: 0
        paddingRows: 0
        placeholderIcon: "search_no_result"
        placeholderText: qsTranslate("SearchResultView", "No search results")
        placeholderIconSize: 256
        model: emptyModel
        padding: 0
        interactive: false
    }

    ListView {
        id: searchPagesView
        anchors.fill: parent
        visible: root.resultCount > 0
        clip: true
        snapMode: ListView.SnapOneItem
        orientation: ListView.Horizontal
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightFollowsCurrentItem: true
        highlightMoveDuration: root.pageSwitchAnimationDuration()
        highlightMoveVelocity: -1
        cacheBuffer: width
        interactive: root.pageCount > 1
        activeFocusOnTab: true
        focus: true
        model: root.pageCount

        property int pendingGridIndex: -1
        property int previousIndex: -1
        property bool changedByNonKeyboard: false
        property bool isDragging: false

        function setCurrentIndex(index) {
            currentIndex = Math.max(0, Math.min(index, count - 1))
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            enabled: searchPagesView.visible
            onWheel: function(wheel) {
                root.handleWheelPage(wheel)
            }
        }

        onDragStarted: {
            isDragging = true
        }

        onMovementEnded: {
            isDragging = false
        }

        Behavior on contentX {
            enabled: !searchPagesView.isDragging

            NumberAnimation {
                duration: root.pageSwitchAnimationDuration()
                easing.type: Easing.OutCubic
            }
        }

        onCurrentItemChanged: {
            if (currentItem && pendingGridIndex >= 0) {
                currentItem.currentIndex = Math.min(pendingGridIndex, Math.max(0, currentItem.count - 1))
                pendingGridIndex = -1
            }
            root.updateCurrentIndexFromPage()
        }

        delegate: FocusScope {
            id: pageDelegate
            readonly property int pageIndex: index

            width: searchPagesView.width
            height: searchPagesView.height

            property alias currentIndex: searchResultGridViewContainer.currentIndex
            readonly property alias currentItem: searchResultGridViewContainer.currentItem
            readonly property int count: pageSliceModel.count

            PageSliceProxyModel {
                id: pageSliceModel
                sourceModel: SearchFilterProxyModel
                pageSize: root.pageSize
                pageIndex: pageDelegate.pageIndex
            }

            GridViewContainer {
                id: searchResultGridViewContainer
                anchors.fill: parent
                activeFocusOnTab: visible && gridViewFocus
                focus: true
                alwaysShowHighlighted: true
                rows: 4
                columns: 7
                cellWidth: root.cellWidth
                cellHeight: root.cellHeight
                paddingColumns: 0
                paddingRows: 0
                model: pageSliceModel
                padding: 0
                interactive: false

                delegate: IconItemDelegate {
                    iconSource: iconName
                    width: searchResultGridViewContainer.cellWidth
                    height: searchResultGridViewContainer.cellHeight
                    padding: 5
                    iconScaleFactor: root.iconScaleFactor
                    transformOrigin: Item.Center
                    onItemClicked: root.launchAppFn(desktopId)
                    onMenuTriggered: root.showContextMenuFn(this, model)
                }

                onCurrentIndexChanged: root.updateCurrentIndexFromPage()

                Keys.onLeftPressed: function(event) {
                    event.accepted = true

                    if (pageSliceModel.count <= 0) {
                        return
                    }

                    const current = searchResultGridViewContainer.currentIndex
                    if (current > 0) {
                        searchResultGridViewContainer.currentIndex = current - 1
                        return
                    }

                    if (searchPagesView.count <= 1) {
                        searchResultGridViewContainer.currentIndex = pageSliceModel.count - 1
                        return
                    }

                    const targetPage = pageDelegate.pageIndex === 0 ? searchPagesView.count - 1 : pageDelegate.pageIndex - 1
                    searchPagesView.pendingGridIndex = root.pageSize - 1
                    searchPagesView.setCurrentIndex(targetPage)
                }

                Keys.onRightPressed: function(event) {
                    event.accepted = true

                    if (pageSliceModel.count <= 0) {
                        return
                    }

                    const current = searchResultGridViewContainer.currentIndex
                    if (current < pageSliceModel.count - 1) {
                        searchResultGridViewContainer.currentIndex = current + 1
                        return
                    }

                    if (searchPagesView.count <= 1) {
                        searchResultGridViewContainer.currentIndex = 0
                        return
                    }

                    const targetPage = pageDelegate.pageIndex === searchPagesView.count - 1 ? 0 : pageDelegate.pageIndex + 1
                    searchPagesView.pendingGridIndex = 0
                    searchPagesView.setCurrentIndex(targetPage)
                }
            }
        }
    }

    Connections {
        target: SearchFilterProxyModel
        function onCountChanged() {
            root.setCurrentGlobalIndex(root.currentIndex)
        }
    }
}
