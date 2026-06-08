// SPDX-FileCopyrightText: 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQml.Models 2.15
import QtQuick 2.15
import QtQuick.Window 2.15

import org.deepin.launchpad 1.0
import org.deepin.launchpad.models 1.0

FocusScope {
    id: root

    required property int pageIndex
    required property var pageView
    required property var folderGridViewPopup
    required property var dndItem
    required property var globalDropArea
    required property var mapTarget
    required property int iconGridMotionSerial
    required property bool iconGridMotionHiding
    required property int iconGridMotionSpeedScale
    required property real cellWidth
    required property real cellHeight
    required property real iconScaleFactor
    required property Item glassSourceItem
    required property real glassSampleRevision
    required property bool glassLive
    required property bool glassEffect
    required property var launchAppFn
    required property var showContextMenuFn
    required property var getCategoryNameFn

    readonly property int viewIndex: pageIndex
    property alias gridViewIndex: gridViewContainer.currentIndex
    property int launchGridMotionSerial: 0
    property bool launchGridMotionHiding: false
    property string pendingLiveReorderKey: ""
    property string pendingLiveReorderDragId: ""
    property string pendingLiveReorderDropId: ""
    property int pendingLiveReorderOp: ItemArrangementProxyModel.DndPrepend

    function suppressAutoHide() {
        LauncherController.cancelHide()
    }

    function dropOperationAtX(x, width) {
        const sideOpPadding = width * 0.36
        if (x < sideOpPadding) {
            return ItemArrangementProxyModel.DndPrepend
        }
        if (x > (width - sideOpPadding)) {
            return ItemArrangementProxyModel.DndAppend
        }
        return ItemArrangementProxyModel.DndJoin
    }

    function commitDropOnItem(dragId, dropId, op) {
        root.dndItem.text = "drag " + dragId + " onto " + dropId + " with " + op
        root.dndItem.arrangementDropCommitted = true
        ItemArrangementProxyModel.commitDndOperation(dragId, dropId, op)
    }

    function scheduleLiveReorder(dragId, dropId, op) {
        const liveKey = dragId + "|" + dropId + "|" + op
        if (liveKey === root.dndItem.liveReorderKey || liveKey === pendingLiveReorderKey) {
            return
        }

        pendingLiveReorderKey = liveKey
        pendingLiveReorderDragId = dragId
        pendingLiveReorderDropId = dropId
        pendingLiveReorderOp = op
        liveReorderTimer.restart()
    }

    function checkPageSwitchState() {
        if (root.viewIndex !== root.pageView.currentIndex) {
            return
        }
        if (root.pageView.previousIndex === -1) {
            root.pageView.previousIndex = root.pageView.currentIndex
            return
        }
        if (root.pageView.changedByNonKeyboard) {
            gridViewContainer.setPreviousPageSwitch(false)
            root.pageView.changedByNonKeyboard = false
        } else if (root.pageView.currentIndex + 1 === root.pageView.previousIndex
                   || (root.pageView.previousIndex === 0 && root.pageView.currentIndex === root.pageView.count - 1)) {
            gridViewContainer.setPreviousPageSwitch(true)
        } else {
            gridViewContainer.setPreviousPageSwitch(false)
        }

        Qt.callLater(function() {
            root.pageView.previousIndex = root.pageView.currentIndex
        })
    }

    function containsGridItemAt(x, y) {
        return gridViewContainer.indexAt(x, y) >= 0
    }

    function containsGridDropAreaAt(x, y) {
        return gridViewContainer.containsGridAreaAt(x, y)
    }

    function gridItemVisualPositions() {
        return gridViewContainer.itemVisualPositions()
    }

    function animateGridItemsFromPositions(positions) {
        gridViewContainer.animateItemsFromPositions(positions)
    }

    function setGridItemTransitionsEnabled(enabled) {
        gridViewContainer.itemTransitionsEnabled = enabled
    }

    function gridItemAt(x, y) {
        return gridViewContainer.itemAt(x, y)
    }

    onIconGridMotionSerialChanged: {
        if (root.ListView.isCurrentItem) {
            launchGridMotionHiding = iconGridMotionHiding
            launchGridMotionSerial = iconGridMotionSerial
        }
    }

    width: root.pageView.width
    height: root.pageView.height

    SortProxyModel {
        id: proxyModel
        sourceModel: MultipageSortFilterProxyModel {
            filterOnlyMode: true
            sourceModel: ItemArrangementProxyModel
            pageId: root.viewIndex
            folderId: 0
        }
        sortRole: ItemArrangementProxyModel.IndexInPageRole
        sortColumn: 0
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton | Qt.LeftButton
        enabled: !root.folderGridViewPopup.visible
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                mouse.accepted = false
                return
            }

            const clickedItem = gridItemAt(mouse.x, mouse.y)
            const clickedIndex = gridViewContainer.indexAt(mouse.x, mouse.y)
            if (clickedItem && typeof clickedItem.activateItem === "function") {
                clickedItem.activateItem()
                mouse.accepted = true
                return
            }

            if (clickedIndex >= 0 || root.dndItem.currentlyDraggedId !== "") {
                LauncherController.suppressNextHideForInputFocus()
                mouse.accepted = true
            } else if (!DebugHelper.avoidHideWindow) {
                LauncherController.visible = false
            }
        }
    }

    GridViewContainer {
        id: gridViewContainer
        objectName: "gridViewContainer"
        anchors.fill: parent
        rows: 4
        columns: 7
        cellWidth: root.cellWidth
        cellHeight: root.cellHeight
        paddingColumns: 0
        paddingRows: 0
        model: proxyModel
        padding: 0
        interactive: false
        focus: true
        activeGridViewFocusOnTab: root.ListView.isCurrentItem
        opacity: 1

        Keys.onLeftPressed: function(event) {
            event.accepted = true

            const count = proxyModel.count
            if (count === 0) {
                return
            }

            const current = gridViewContainer.currentIndex
            if (current > 0) {
                gridViewContainer.currentIndex = current - 1
                return
            }

            if (root.pageView.count <= 1) {
                gridViewContainer.currentIndex = count - 1
                return
            }

            if (root.viewIndex === 0) {
                root.pageView.setCurrentIndex(root.pageView.count - 1)
            } else {
                root.pageView.setCurrentIndex(root.viewIndex - 1)
            }
        }

        Keys.onRightPressed: function(event) {
            event.accepted = true

            const count = proxyModel.count
            if (count === 0) {
                return
            }

            const current = gridViewContainer.currentIndex
            if (current < count - 1) {
                gridViewContainer.currentIndex = current + 1
                return
            }

            if (root.pageView.count <= 1) {
                gridViewContainer.currentIndex = 0
                return
            }

            if (root.viewIndex === (root.pageView.count - 1)) {
                root.pageView.previousIndex = 0
                root.pageView.setCurrentIndex(0)
            } else {
                const nextPageIndex = root.viewIndex + 1
                root.pageView.previousIndex = nextPageIndex
                root.pageView.setCurrentIndex(nextPageIndex)
            }
        }

        itemMove: Transition {
            id: itemMoveTransition
            enabled: false

            NumberAnimation {
                properties: "x,y"
                duration: 400 * LauncherController.animationSpeedScale
                easing.type: Easing.OutQuint
            }
        }

        delegate: DropArea {
            id: delegateRoot
            Keys.forwardTo: [iconItemDelegate]

            property bool isDragHover: false
            readonly property string desktopId: model.desktopId
            readonly property int activeGridMotionSerial: root.launchGridMotionSerial
            readonly property int gridColumn: index % 7
            readonly property int gridRow: Math.floor(index / 7)
            readonly property int gridRing: Math.floor(Math.max(Math.abs(gridColumn - 3), Math.abs(gridRow - 1.5)))
            readonly property int maxGridRing: 3
            readonly property real gatherStrength: 0.22
            readonly property real gridCellCenterX: (gridColumn + 0.5) * gridViewContainer.cellWidth
            readonly property real gridCellCenterY: (gridRow + 0.5) * gridViewContainer.cellHeight
            readonly property real gatherOffsetX: (gridViewContainer.width / 2 - gridCellCenterX) * gatherStrength
            readonly property real gatherOffsetY: (gridViewContainer.height / 2 - gridCellCenterY) * gatherStrength
            readonly property real devicePixelRatio: Screen.devicePixelRatio ? Screen.devicePixelRatio : 1
            property bool gridMotionHidingSnapshot: false
            property int gridMotionSpeedScaleSnapshot: 1
            property int gridMotionDelaySnapshot: 0
            property real gridMotionFromX: 5
            property real gridMotionToX: 5
            property real gridMotionFromY: 5
            property real gridMotionToY: 5
            property real gridMotionFromScale: 1
            property real gridMotionToScale: 1
            property real gridMotionFromOpacity: 1
            property real gridMotionToOpacity: 1
            property real gridMotionScale: 1
            property real gridMotionOpacity: 1
            property real rollbackOffsetX: 0
            property real rollbackOffsetY: 0

            visible: !root.folderGridViewPopup.visible
                     || root.folderGridViewPopup.currentFolderId !== Number(model.desktopId.replace("internal/folders/", ""))
            width: gridViewContainer.cellWidth
            height: gridViewContainer.cellHeight

            onVisibleChanged: {
                if (visible && !gridMotionAnim.running) {
                    resetGridMotionVisualState()
                }
            }

            function commitLiveReorder(drop) {
                const dragId = Helper.dragDesktopId(drop)
                if (dragId === "" || dragId === model.desktopId) {
                    return
                }

                const op = root.dropOperationAtX(drop.x, width)
                if (op === ItemArrangementProxyModel.DndJoin) {
                    return
                }

                root.scheduleLiveReorder(dragId, model.desktopId, op)
            }

            function finalizeDrop(drop) {
                liveReorderTimer.stop()
                root.pendingLiveReorderKey = ""

                const dragId = Helper.dragDesktopId(drop)
                if (dragId === "" || dragId === model.desktopId) {
                    return
                }

                const op = root.dropOperationAtX(drop.x, width)
                if (op === ItemArrangementProxyModel.DndJoin) {
                    root.dndItem.mergeAnimTargetIcon = root.dndItem.currentlyDraggedIconName
                    root.dndItem.mergeAnimTargetIcon2 = !folderIcons ? iconItemDelegate.iconSource : ""
                    const cursorScene = mapToItem(null, drop.x, drop.y)
                    const hs = root.dndItem.Drag.hotSpot
                    root.dndItem.mergeAnimStartX = cursorScene.x - hs.x + root.dndItem.mergeSize / 2
                    root.dndItem.mergeAnimStartY = cursorScene.y - hs.y + root.dndItem.mergeSize / 2
                    root.dndItem.mergeAnimPending = true
                }

                const liveKey = dragId + "|" + model.desktopId + "|" + op
                if (op !== ItemArrangementProxyModel.DndJoin && liveKey === root.dndItem.liveReorderKey) {
                    root.dndItem.arrangementDropCommitted = true
                    ItemArrangementProxyModel.persistArrangement()
                    return
                }

                root.commitDropOnItem(dragId, model.desktopId, op)
            }

            function roundToDevicePixel(value) {
                return Math.round(value * devicePixelRatio) / devicePixelRatio
            }

            function prepareGridMotion() {
                const hiding = root.launchGridMotionHiding
                const speedScale = root.iconGridMotionSpeedScale
                gridMotionHidingSnapshot = hiding
                gridMotionSpeedScaleSnapshot = speedScale
                gridMotionDelaySnapshot = (hiding ? (maxGridRing - gridRing) : gridRing) * 10 * speedScale
                gridMotionFromX = roundToDevicePixel(hiding ? 5 : 5 + gatherOffsetX)
                gridMotionToX = roundToDevicePixel(hiding ? 5 + gatherOffsetX : 5)
                gridMotionFromY = roundToDevicePixel(hiding ? 5 : 5 + gatherOffsetY)
                gridMotionToY = roundToDevicePixel(hiding ? 5 + gatherOffsetY : 5)
                gridMotionFromScale = hiding ? 1 : 0.96
                gridMotionToScale = hiding ? 0.96 : 1
                gridMotionFromOpacity = hiding ? 1 : 0
                gridMotionToOpacity = hiding ? 0 : 1
                iconMotionWrapper.x = gridMotionFromX
                iconMotionWrapper.y = gridMotionFromY
                gridMotionScale = gridMotionFromScale
                gridMotionOpacity = gridMotionFromOpacity
            }

            function resetGridMotionVisualState() {
                iconMotionWrapper.x = 5
                iconMotionWrapper.y = 5
                gridMotionScale = 1
                gridMotionOpacity = 1
            }

            function animateVisualMoveFrom(previousX, previousY, coordinateItem) {
                rollbackMoveAnim.stop()
                const currentPoint = delegateRoot.mapToItem(coordinateItem, 0, 0)
                rollbackOffsetX = previousX - currentPoint.x
                rollbackOffsetY = previousY - currentPoint.y
                rollbackMoveAnim.restart()
            }

            function activateItem() {
                if (model.itemType === ItemArrangementProxyModel.FolderItemType) {
                    iconItemDelegate.folderClicked()
                } else {
                    iconItemDelegate.itemClicked()
                }
            }

            function activateFolderItem() {
                if (model.itemType !== ItemArrangementProxyModel.FolderItemType) {
                    return false
                }

                iconItemDelegate.folderClicked()
                return true
            }

            function openFolderFromDelegate(delegateItem) {
                const folderId = Number(model.desktopId.replace("internal/folders/", ""))
                const folderRect = delegateItem.folderBackgroundRect(root.mapTarget)
                root.folderGridViewPopup.currentFolderId = folderId
                root.folderGridViewPopup.sourceRectX = folderRect.x
                root.folderGridViewPopup.sourceRectY = folderRect.y
                root.folderGridViewPopup.sourceRectWidth = folderRect.width
                root.folderGridViewPopup.sourceRectHeight = folderRect.height
                root.folderGridViewPopup.sourceCornerRadius = delegateItem.folderBackgroundRadius
                root.folderGridViewPopup.sourceIconScaleFactor = root.iconScaleFactor
                root.folderGridViewPopup.sourceIcons = delegateItem.folderPreviewIcons()
                const sourcePreviewIconRects = []
                const sourcePreviewCount = root.folderGridViewPopup.sourceIcons.length
                for (let i = 0; i < sourcePreviewCount; ++i) {
                    sourcePreviewIconRects.push(delegateItem.folderPreviewIconVisualRect(i, root.mapTarget))
                }
                root.folderGridViewPopup.sourcePreviewIconRects = sourcePreviewIconRects
                root.folderGridViewPopup.startPointX = folderRect.x + folderRect.width / 2
                root.folderGridViewPopup.startPointY = folderRect.y + folderRect.height / 2
                root.folderGridViewPopup.open()
                root.folderGridViewPopup.folderName = model.display.startsWith("internal/category/")
                                                ? root.getCategoryNameFn(model.display.substring(18))
                                                : model.display
            }

            function renameFolderFromDelegate(delegateItem) {
                openFolderFromDelegate(delegateItem)
                if (typeof root.folderGridViewPopup.requestFolderNameEdit === "function") {
                    root.folderGridViewPopup.requestFolderNameEdit()
                }
            }

            function dissolveFolderFromDelegate() {
                const folderId = Number(model.desktopId.replace("internal/folders/", ""))
                ItemArrangementProxyModel.dissolveFolder(folderId)
            }

            onEntered: function(drag) {
                if (root.folderGridViewPopup.opened) {
                    root.folderGridViewPopup.close()
                }

                const dragId = Helper.dragDesktopId(drag)
                if (dragId !== model.desktopId) {
                    isDragHover = true
                }
                commitLiveReorder(drag)
            }

            onPositionChanged: function(drag) {
                commitLiveReorder(drag)
            }

            onExited: {
                isDragHover = false
            }

            onDropped: function(drop) {
                isDragHover = false
                finalizeDrop(drop)
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                enabled: !root.folderGridViewPopup.visible
                         && root.dndItem.currentlyDraggedId === ""
                onClicked: {
                    delegateRoot.activateItem()
                }
            }

            Item {
                id: iconMotionWrapper
                width: parent.width - 10
                height: parent.height - 10
                x: 5
                y: 5
                opacity: root.dndItem.currentlyDraggedId !== model.desktopId ? delegateRoot.gridMotionOpacity : 0
                scale: delegateRoot.gridMotionScale
                transformOrigin: Item.Center
                transform: Translate {
                    x: delegateRoot.rollbackOffsetX
                    y: delegateRoot.rollbackOffsetY
                }
                layer.enabled: gridMotionAnim.running
                layer.smooth: true
                layer.mipmap: true

                IconItemDelegate {
                    id: iconItemDelegate
                    anchors.fill: parent
                    enabled: !root.folderGridViewPopup.visible
                    dndEnabled: !root.folderGridViewPopup.opened
                    isDragHover: parent.parent.isDragHover
                    Drag.mimeData: Helper.generateDragMimeData(model.desktopId)
                    iconSource: (iconName && iconName !== "") ? iconName : "application-x-desktop"
                    icons: folderIcons
                    iconScaleFactor: root.iconScaleFactor
                    glassSourceItem: root.glassSourceItem
                    glassSampleRevision: root.glassSampleRevision + root.pageView.contentX
                    glassLive: root.glassLive
                    glassEffect: root.glassEffect
                    transformOrigin: Item.Center

                    onItemClicked: root.launchAppFn(desktopId)

                    onFolderClicked: {
                        delegateRoot.openFolderFromDelegate(iconItemDelegate)
                    }

                    onMenuTriggered: {
                        const additionalProps = {}
                        if (model.itemType === ItemArrangementProxyModel.FolderItemType) {
                            additionalProps.openFolderFn = function() {
                                delegateRoot.openFolderFromDelegate(iconItemDelegate)
                            }
                            additionalProps.renameFolderFn = function() {
                                delegateRoot.renameFolderFromDelegate(iconItemDelegate)
                            }
                            additionalProps.dissolveFolderFn = function() {
                                delegateRoot.dissolveFolderFromDelegate()
                            }
                        }

                        root.showContextMenuFn(iconItemDelegate, model, additionalProps)
                        root.pageView.focus = true
                    }
                }
            }

            ParallelAnimation {
                id: rollbackMoveAnim

                NumberAnimation {
                    target: delegateRoot
                    property: "rollbackOffsetX"
                    to: 0
                    duration: 260 * LauncherController.animationSpeedScale
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: delegateRoot
                    property: "rollbackOffsetY"
                    to: 0
                    duration: 260 * LauncherController.animationSpeedScale
                    easing.type: Easing.OutCubic
                }
            }

            onActiveGridMotionSerialChanged: {
                if (activeGridMotionSerial > 0) {
                    prepareGridMotion()
                    gridMotionAnim.restart()
                }
            }

            SequentialAnimation {
                id: gridMotionAnim

                PauseAnimation {
                    duration: delegateRoot.gridMotionDelaySnapshot
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: iconMotionWrapper
                        property: "x"
                        duration: 200 * delegateRoot.gridMotionSpeedScaleSnapshot
                        easing.type: delegateRoot.gridMotionHidingSnapshot ? Easing.InCubic : Easing.OutCubic
                        from: delegateRoot.gridMotionFromX
                        to: delegateRoot.gridMotionToX
                    }

                    NumberAnimation {
                        target: iconMotionWrapper
                        property: "y"
                        duration: 200 * delegateRoot.gridMotionSpeedScaleSnapshot
                        easing.type: delegateRoot.gridMotionHidingSnapshot ? Easing.InCubic : Easing.OutCubic
                        from: delegateRoot.gridMotionFromY
                        to: delegateRoot.gridMotionToY
                    }

                    NumberAnimation {
                        target: delegateRoot
                        property: "gridMotionScale"
                        duration: 200 * delegateRoot.gridMotionSpeedScaleSnapshot
                        easing.type: delegateRoot.gridMotionHidingSnapshot ? Easing.InCubic : Easing.OutCubic
                        from: delegateRoot.gridMotionFromScale
                        to: delegateRoot.gridMotionToScale
                    }

                    NumberAnimation {
                        target: delegateRoot
                        property: "gridMotionOpacity"
                        duration: 200 * delegateRoot.gridMotionSpeedScaleSnapshot
                        easing.type: delegateRoot.gridMotionHidingSnapshot ? Easing.InCubic : Easing.OutCubic
                        from: delegateRoot.gridMotionFromOpacity
                        to: delegateRoot.gridMotionToOpacity
                    }
                }
            }
        }

        Connections {
            target: root.pageView
            function onCurrentIndexChanged() {
                root.checkPageSwitchState()
            }
        }

        Connections {
            target: root.globalDropArea
            function onDropped() {
                root.checkPageSwitchState()
            }
        }

        Timer {
            id: delayedEnableItemMoveTimer
            interval: 100
            onTriggered: itemMoveTransition.enabled = true
        }

        Timer {
            id: liveReorderTimer
            interval: Math.max(48, Math.round(1000 / Math.max(60, LauncherController.displayRefreshRate) * 4))
            repeat: false
            onTriggered: {
                if (root.pendingLiveReorderKey === ""
                        || root.pendingLiveReorderKey === root.dndItem.liveReorderKey) {
                    return
                }

                root.dndItem.liveReorderKey = root.pendingLiveReorderKey
                ItemArrangementProxyModel.previewDndOperation(
                    root.pendingLiveReorderDragId,
                    root.pendingLiveReorderDropId,
                    root.pendingLiveReorderOp
                )
            }
        }

        Connections {
            target: LauncherController
            function onCurrentFrameChanged() {
                if (LauncherController.currentFrame === "WindowedFrame") {
                    itemMoveTransition.enabled = false
                } else {
                    delayedEnableItemMoveTimer.restart()
                }
            }
        }

        Component.onCompleted: {
            if (LauncherController.currentFrame === "FullscreenFrame") {
                itemMoveTransition.enabled = true
            }
            root.checkPageSwitchState()
        }
    }
}
