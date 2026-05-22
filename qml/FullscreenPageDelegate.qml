// SPDX-FileCopyrightText: 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQml.Models 2.15
import QtQuick 2.15

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
    required property var launchAppFn
    required property var showContextMenuFn
    required property var getCategoryNameFn

    readonly property int viewIndex: pageIndex
    property alias gridViewIndex: gridViewContainer.currentIndex
    property int launchGridMotionSerial: 0
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

    onIconGridMotionSerialChanged: {
        if (root.ListView.isCurrentItem) {
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
            property int activeGridMotionSerial: root.launchGridMotionSerial
            property real gridMotionProgress: 1
            readonly property int gridColumn: index % 7
            readonly property int gridRow: Math.floor(index / 7)
            readonly property int gridRing: Math.floor(Math.max(Math.abs(gridColumn - 3), Math.abs(gridRow - 1.5)))
            readonly property int maxGridRing: 3
            readonly property real gatherStrength: 0.22
            readonly property real gatherOffsetX: (gridViewContainer.width / 2 - (x + width / 2)) * gatherStrength
            readonly property real gatherOffsetY: (gridViewContainer.height / 2 - (y + height / 2)) * gatherStrength

            visible: !root.folderGridViewPopup.visible
                     || root.folderGridViewPopup.currentFolderId !== Number(model.desktopId.replace("internal/folders/", ""))
            width: gridViewContainer.cellWidth
            height: gridViewContainer.cellHeight

            onActiveGridMotionSerialChanged: {
                if (activeGridMotionSerial > 0) {
                    gridMotionAnim.restart()
                }
            }

            function commitLiveReorder(drop) {
                const dragId = drop.getDataAsString("text/x-dde-launcher-dnd-desktopId")
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

                const dragId = drop.getDataAsString("text/x-dde-launcher-dnd-desktopId")
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
                    ItemArrangementProxyModel.persistArrangement()
                    return
                }

                root.commitDropOnItem(dragId, model.desktopId, op)
            }

            onEntered: function(drag) {
                if (root.folderGridViewPopup.opened) {
                    root.folderGridViewPopup.close()
                }

                const dragId = drag.getDataAsString("text/x-dde-launcher-dnd-desktopId")
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
                    if (!DebugHelper.avoidHideWindow) {
                        LauncherController.visible = false
                    }
                }
            }

            Item {
                id: iconMotionWrapper
                width: parent.width - 10
                height: parent.height - 10
                x: 5 + delegateRoot.gatherOffsetX * (1 - delegateRoot.gridMotionProgress)
                y: 5 + delegateRoot.gatherOffsetY * (1 - delegateRoot.gridMotionProgress)
                opacity: root.dndItem.currentlyDraggedId !== model.desktopId ? 1 : 0

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
                    transformOrigin: Item.Center

                    onItemClicked: root.launchAppFn(desktopId)

                    onFolderClicked: {
                        const folderId = Number(model.desktopId.replace("internal/folders/", ""))
                        const folderRect = iconItemDelegate.folderBackgroundRect(root.mapTarget)
                        root.folderGridViewPopup.currentFolderId = folderId
                        root.folderGridViewPopup.sourceRectX = folderRect.x
                        root.folderGridViewPopup.sourceRectY = folderRect.y
                        root.folderGridViewPopup.sourceRectWidth = folderRect.width
                        root.folderGridViewPopup.sourceRectHeight = folderRect.height
                        root.folderGridViewPopup.sourceCornerRadius = iconItemDelegate.folderBackgroundRadius
                        root.folderGridViewPopup.sourceIconScaleFactor = root.iconScaleFactor
                        root.folderGridViewPopup.sourceIcons = folderIcons ? folderIcons : []
                        const sourcePreviewIconRects = []
                        const sourcePreviewCount = folderIcons && folderIcons.length !== undefined
                            ? Math.min(4, folderIcons.length)
                            : 0
                        for (let i = 0; i < sourcePreviewCount; ++i) {
                            sourcePreviewIconRects.push(iconItemDelegate.folderPreviewIconVisualRect(i, root.mapTarget))
                        }
                        root.folderGridViewPopup.sourcePreviewIconRects = sourcePreviewIconRects
                        root.folderGridViewPopup.startPointX = folderRect.x + folderRect.width / 2
                        root.folderGridViewPopup.startPointY = folderRect.y + folderRect.height / 2
                        root.folderGridViewPopup.open()
                        root.folderGridViewPopup.folderName = model.display.startsWith("internal/category/")
                                                        ? root.getCategoryNameFn(model.display.substring(18))
                                                        : model.display
                    }

                    onMenuTriggered: {
                        if (folderIcons) {
                            return
                        }

                        root.showContextMenuFn(this, model)
                        root.pageView.focus = true
                    }
                }
            }

            SequentialAnimation {
                id: gridMotionAnim

                ScriptAction {
                    script: {
                        gridMotionProgress = root.iconGridMotionHiding ? 1 : 0
                    }
                }

                PauseAnimation {
                    duration: (root.iconGridMotionHiding
                        ? (delegateRoot.maxGridRing - delegateRoot.gridRing)
                        : delegateRoot.gridRing) * 10 * root.iconGridMotionSpeedScale
                }

                NumberAnimation {
                    target: delegateRoot
                    property: "gridMotionProgress"
                    duration: 200 * root.iconGridMotionSpeedScale
                    easing.type: root.iconGridMotionHiding ? Easing.InCubic : Easing.OutCubic
                    to: root.iconGridMotionHiding ? 0 : 1
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
