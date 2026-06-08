// SPDX-FileCopyrightText: 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15

import org.deepin.launchpad.models 1.0

Item {
    id: root

    required property var folderGridViewPopup
    required property var dndItem
    required property var dropArea
    required property var mapTarget
    required property int iconGridMotionSerial
    required property bool iconGridMotionHiding
    required property int iconGridMotionSpeedScale
    required property real cellWidth
    required property real cellHeight
    required property real iconScaleFactor
    required property real externalDimProgress
    required property string searchText
    required property Item glassSourceItem
    required property real glassSampleRevision
    required property bool glassLive
    required property bool glassEffect
    required property var launchAppFn
    required property var showContextMenuFn
    required property var getCategoryNameFn
    property var handleWheelPageFn: null

    property alias pageView: listviewPage
    property alias searchGrid: searchResultGridViewContainer
    property alias searchPageView: searchResultGridViewContainer.pageView
    property alias searchModelReady: searchResultGridViewContainer.modelReady
    readonly property int searchResultCount: searchResultGridViewContainer.resultCount
    readonly property int pageSwitchDuration: 600

    function pageSwitchAnimationDuration() {
        return Math.max(1, Math.round(pageSwitchDuration * LauncherController.animationSpeedScale))
    }

    function resetCurrentGridIndex() {
        if (listviewPage.currentItem) {
            listviewPage.currentItem.gridViewIndex = 0
        }
    }

    function resetToFirstPage() {
        listviewPage.currentIndex = 0
        listviewPage.previousIndex = -1
        listviewPage.changedByNonKeyboard = false
    }

    function selectFirstItemForInitialDirectionKey() {
        const currentPage = listviewPage.currentItem
        if (currentPage && typeof currentPage.selectFirstItemForInitialDirectionKey === "function") {
            return currentPage.selectFirstItemForInitialDirectionKey()
        }
        return false
    }

    function handleWheelPage(wheel, pageView) {
        if (typeof handleWheelPageFn === "function") {
            handleWheelPageFn(wheel, pageView)
        }
    }

    ItemsPageModel {
        id: itemPageModel
        sourceModel: ItemArrangementProxyModel
    }

    ListView {
        id: listviewPage
        anchors.fill: parent
        snapMode: ListView.SnapOneItem
        orientation: ListView.Horizontal
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightFollowsCurrentItem: true
        clip: true
        highlightMoveDuration: root.pageSwitchAnimationDuration()
        highlightMoveVelocity: -1
        cacheBuffer: width
        activeFocusOnTab: true
        focus: true
        visible: root.searchText === ""
        interactive: !root.folderGridViewPopup.visible && root.dndItem.currentlyDraggedId === ""
        opacity: 1 - (0.8 * root.externalDimProgress)

        property bool isDragging: false
        property int previousIndex: -1
        property bool changedByNonKeyboard: false

        onFlickStarted: {
            if (!isDragging) {
                cancelFlick()
                contentX = currentIndex * width
            }
        }

        onDragStarted: {
            isDragging = true
        }

        onMovementEnded: {
            isDragging = false
        }

        Behavior on contentX {
            enabled: !listviewPage.isDragging

            NumberAnimation {
                duration: root.pageSwitchAnimationDuration()
                easing.type: Easing.OutCubic
            }
        }

        function setCurrentIndex(index) {
            currentIndex = index
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            enabled: listviewPage.visible
            onWheel: function(wheel) {
                root.handleWheelPage(wheel, listviewPage)
            }
        }

        model: itemPageModel

        delegate: FullscreenPageDelegate {
            pageView: listviewPage
            folderGridViewPopup: root.folderGridViewPopup
            dndItem: root.dndItem
            globalDropArea: root.dropArea
            mapTarget: root.mapTarget
            iconGridMotionSerial: root.iconGridMotionSerial
            iconGridMotionHiding: root.iconGridMotionHiding
            iconGridMotionSpeedScale: root.iconGridMotionSpeedScale
            cellWidth: root.cellWidth
            cellHeight: root.cellHeight
            iconScaleFactor: root.iconScaleFactor
            glassSourceItem: root.glassSourceItem
            glassSampleRevision: root.glassSampleRevision
            glassLive: root.glassLive
            glassEffect: root.glassEffect
            launchAppFn: root.launchAppFn
            showContextMenuFn: root.showContextMenuFn
            getCategoryNameFn: root.getCategoryNameFn
        }

        Component.onCompleted: {
            currentIndex = 0
        }
    }

    FullscreenSearchResults {
        id: searchResultGridViewContainer
        anchors.fill: parent
        visible: root.searchText !== ""
        opacity: 1 - (0.8 * root.externalDimProgress)
        cellWidth: root.cellWidth
        cellHeight: root.cellHeight
        iconScaleFactor: root.iconScaleFactor
        searchText: root.searchText
        launchAppFn: root.launchAppFn
        showContextMenuFn: root.showContextMenuFn
        handleWheelPageFn: root.handleWheelPageFn
    }
}
