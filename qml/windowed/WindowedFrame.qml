// SPDX-FileCopyrightText: 2023-2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15
import QtQml.Models 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15
import org.deepin.dtk 1.0

import org.deepin.launchpad 1.0
import org.deepin.launchpad.models 1.0
import "."

InputEventItem {
    id: baseLayer
    objectName: "WindowedFrame-BaseLayer"
    inputMethodSource: folderGridViewPopup.folderNameEditing ? null : bottomBar.searchEdit
    wheelEventForwardingEnabled: folderGridViewPopup.visible

    visible: true
    focus: true
    readonly property bool searchActive: SearchFilterProxyModel.searchText !== ""

    KeyNavigation.tab: appGridLoader.item

    onWheelReceived: function(position, pixelDelta, angleDelta, modifiers) {
        if (!LauncherController.visible || LauncherController.currentFrame !== "WindowedFrame") {
            return
        }

        if (folderGridViewPopup.visible) {
            folderGridViewPopup.handleWheelDeltas(pixelDelta, angleDelta, modifiers)
        }
    }

    Shortcut {
        context: Qt.ApplicationShortcut
        sequences: [StandardKey.HelpContents, "F1"]
        onActivated: LauncherController.showHelp()
        onActivatedAmbiguously: LauncherController.showHelp()
    }

    function getHorizontalCoordinatesOfSideBar()
    {
        return sideBar.x + sideBar.width / 2
    }

    function handleSearchNavigationKey(key) {
        if (!baseLayer.searchActive) {
            return false
        }

        if (appGridLoader.item
                && typeof appGridLoader.item.moveCurrentSelectionByKey === "function") {
            appGridLoader.item.moveCurrentSelectionByKey(key)
        }
        if (!bottomBar.searchEdit.activeFocus) {
            bottomBar.searchEdit.forceActiveFocus(Qt.TabFocusReason)
        }
        return true
    }

    function selectFirstAppGridItemForInitialDirectionKey() {
        if (!appGridLoader.item
                || typeof appGridLoader.item.selectFirstItemForInitialDirectionKey !== "function") {
            return false
        }

        appGridLoader.item.forceActiveFocus(Qt.TabFocusReason)
        return appGridLoader.item.selectFirstItemForInitialDirectionKey()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: () => {
            baseLayer.forceActiveFocus(Qt.MouseFocusReason)
        }
    }

    // ----------- Drag and Drop related functions START -----------
    Label {
        property string currentlyDraggedId
        property string currentlyDraggedIconName

        property bool mergeAnimPending: false
        property string mergeAnimTargetIcon: ""
        property string mergeAnimTargetIcon2: ""
        property real mergeAnimStartX: 0
        property real mergeAnimStartY: 0

        property real mergeSize: 0

        id: dndItem
        visible: dragVisualActive || DebugHelper.qtDebugEnabled
        z: 10000
        opacity: dragVisualActive ? 0.92 : 1
        width: Math.max(1, mergeSize)
        height: Math.max(1, mergeSize)
        text: "DnD DEBUG"
        color: DebugHelper.qtDebugEnabled ? palette.windowText : "transparent"
        readonly property bool dragVisualActive: currentlyDraggedId !== "" || Drag.active

        Drag.onActiveChanged: {
            if (Drag.active) {
                text = "Dragging " + currentlyDraggedId
            } else {
                currentlyDraggedId = ""
                currentlyDraggedIconName = ""
            }
        }

        Image {
            anchors.fill: parent
            visible: dndItem.dragVisualActive && source != ""
            source: dndItem.Drag.imageSource
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }
    }

    function dropOnItem(dragId, dropId, op) {
        dndItem.text = "drag " + dragId + " onto " + dropId + " with " + op
        ItemArrangementProxyModel.commitDndOperation(dragId, dropId, op)
    }

    function dropOnPage(dragId, dropFolderId, pageNumber) {
        dndItem.text = "drag " + dragId + " into " + dropFolderId + " at page " + pageNumber
        ItemArrangementProxyModel.commitDndOperation(dragId, dropFolderId, ItemArrangementProxyModel.DndJoin, pageNumber)
    }
    // ----------- Drag and Drop related functions  END  -----------

    SideBar {
        id: sideBar
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 10
        anchors.leftMargin: 10
        nextKeyTabTarget: bottomBar.keyTabTarget
    }

    Control {
        id: rowLineControl
        width: Helper.windowed.splitLineWidth
        anchors.left: sideBar.right
        anchors.top: baseLayer.top
        anchors.bottom: bottomBar.top
        anchors.leftMargin: 10

        property Palette backgroundColor: Palette {
            normal {
                common: Qt.rgba(0, 0, 0, 0.05)
                crystal: Qt.rgba(0, 0, 0, 0.05)
            }
            normalDark {
                common: Qt.rgba(1, 1, 1, 0.05)
                crystal: Qt.rgba(1, 1, 1, 0.05)
            }
        }

        contentItem: Rectangle {
            color: rowLineControl.ColorSelector.backgroundColor
        }
    }

    RowLayout {
        id: appArea
        anchors.left: sideBar.right
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: bottomBar.top
        anchors.topMargin: 10
        anchors.leftMargin: 10
        anchors.rightMargin: 1
        spacing: 0
        Behavior on opacity {
            NumberAnimation { duration: 200 * LauncherController.animationSpeedScale; easing.type: Easing.OutQuad }
        }
        AppList {
            id: appList
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            nextKeyTabTarget: sideBar.keyTabTarget
        }

        Loader {
            id: appGridLoader
            property Item keyTabTarget: appGridLoader.item.keyTabTarget
            Component {
                id: analysisViewCom
                AnalysisView {
                    nextKeyTabTarget: appList.keyTabTarget
                }
            }
            Component {
                id: searchResultViewCom
                SearchResultView {
                    nextKeyTabTarget: appList.keyTabTarget
                }
            }
            Layout.fillHeight: true
            Layout.preferredWidth: 365
            Layout.alignment: Qt.AlignRight | Qt.AlignTop
            Layout.leftMargin: Helper.frequentlyUsed.leftMargin
            Layout.rightMargin: Helper.frequentlyUsed.rightMargin
            sourceComponent: baseLayer.searchActive ? searchResultViewCom
                : analysisViewCom
        }
    }

    BottomBar {
        id: bottomBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        nextKeyTabTarget: appGridLoader.keyTabTarget
        searchNavigationKeyHandler: function(key) {
            return baseLayer.handleSearchNavigationKey(key)
        }
        initialDirectionKeyHandler: function(key) {
            return baseLayer.selectFirstAppGridItemForInitialDirectionKey()
        }
    }

    Control {
        id: columnLineControl
        height: Helper.windowed.splitLineWidth
        anchors.left: baseLayer.left
        anchors.right: baseLayer.right
        anchors.bottom: bottomBar.top

        property Palette backgroundColor: Palette {
            normal {
                common: Qt.rgba(0, 0, 0, 0.05)
                crystal: Qt.rgba(0, 0, 0, 0.05)
            }
            normalDark {
                common: Qt.rgba(1, 1, 1, 0.05)
                crystal: Qt.rgba(1, 1, 1, 0.05)
            }
        }

        contentItem: Rectangle {
            color: columnLineControl.ColorSelector.backgroundColor
        }
    }

    FolderGridViewPopup {
        id: folderGridViewPopup
        // 物理像素对齐，确保在各种缩放比例下边缘都能对齐到整数物理像素
        width: Math.round(370 * Screen.devicePixelRatio) / Screen.devicePixelRatio
        height: Math.round(330 * Screen.devicePixelRatio) / Screen.devicePixelRatio
        folderNameFont: LauncherController.adjustFontWeight(DTK.fontManager.t6, Font.Bold)
        centerPosition: Qt.point(curPointX, curPointY)

        readonly property int animationDuration: 200 * LauncherController.animationSpeedScale
        property int startPointX: 0
        property int startPointY: 0
        readonly property point endPoint: Qt.point(parent.width / 2, parent.height / 2)
        property int curPointX: 0
        property int curPointY: 0

        onVisibleChanged: function (visible) {
            if (!visible) {
                appArea.opacity = 1
            }
        }

        enter: Transition {
            ParallelAnimation {
                NumberAnimation {
                    duration: folderGridViewPopup.animationDuration
                    properties: "scale"
                    easing.type: Easing.OutQuad
                    from: 0.1
                    to: 1
                }
                NumberAnimation {
                    duration: folderGridViewPopup.animationDuration
                    properties: "curPointX"
                    easing.type: Easing.OutQuad
                    from: folderGridViewPopup.startPointX
                    to: folderGridViewPopup.endPoint.x
                }
                NumberAnimation {
                    duration: folderGridViewPopup.animationDuration
                    properties: "curPointY"
                    easing.type: Easing.OutQuad
                    from: folderGridViewPopup.startPointY
                    to: folderGridViewPopup.endPoint.y
                }
            }
        }

        exit: Transition {
            ParallelAnimation {
                NumberAnimation {
                    duration: folderGridViewPopup.animationDuration
                    properties: "scale"
                    easing.type: Easing.InQuad
                    from: 1
                    to: 0.1
                }
                NumberAnimation {
                    duration: folderGridViewPopup.animationDuration
                    properties: "curPointX"
                    easing.type: Easing.InQuad
                    to: folderGridViewPopup.startPointX
                    from: folderGridViewPopup.endPoint.x
                }
                NumberAnimation {
                    duration: folderGridViewPopup.animationDuration
                    properties: "curPointY"
                    easing.type: Easing.InQuad
                    to: folderGridViewPopup.startPointY
                    from: folderGridViewPopup.endPoint.y
                }
            }
        }
    }

    Keys.forwardTo: folderGridViewPopup.folderNameEditing ? [] : [bottomBar.searchEdit]
    Keys.onPressed: function (event) {
        if (folderGridViewPopup.folderNameEditing) {
            return
        }

        if (bottomBar.searchEdit.focus === true || baseLayer.focus === true) {
            // the SearchEdit will catch the key event first, and events that it won't accept will then got here
            switch (event.key) {
            case Qt.Key_Up:
            case Qt.Key_Down:
                if (baseLayer.handleSearchNavigationKey(event.key)) {
                    event.accepted = true
                    return
                }
            case Qt.Key_Left:
            case Qt.Key_Right:
                if (baseLayer.handleSearchNavigationKey(event.key)) {
                    event.accepted = true
                    return
                }
                baseLayer.selectFirstAppGridItemForInitialDirectionKey()
                event.accepted = true
                return
            case Qt.Key_Enter:
            case Qt.Key_Return:
                if (baseLayer.searchActive) {
                    appGridLoader.item.launchCurrentItem()
                } else {
                    appGridLoader.item.forceActiveFocus()
                }
            }
        }
    }

    Keys.onEscapePressed: function (event) {
        if (!DebugHelper.avoidHideWindow) {
            LauncherController.visible = false;
        }
    }
    onInputReceived: function(text){
        if (folderGridViewPopup.folderNameEditing) {
            return
        }

        if (bottomBar.searchEdit.activeFocus) {
            return
        }

        bottomBar.searchEdit.forceActiveFocus(Qt.TabFocusReason)
        bottomBar.searchEdit.text = bottomBar.searchEdit.text + text
    }

    Component.onCompleted: {
        // Since LauncherController onVisibleChanged only reset state on visible === false,
        // we also need to do it to ensure initial state also get its listview's state reset
        appList.resetViewState()
    }

    Connections {
        target: LauncherController
        function onVisibleChanged() {
            // only do these clean-up steps on launcher get hide
            if (LauncherController.visible) return

            // clear searchEdit text
            bottomBar.searchEdit.text = ""
            // reset(remove) keyboard focus
            baseLayer.forceActiveFocus(Qt.MouseFocusReason)
            // reset scroll area position and state
            appList.resetViewState()
            folderGridViewPopup.close()
        }
    }

    Connections {
        target: sideBar
        function onSwitchToFreeSort(isFreeSort) {
            appList.switchToFreeSort(isFreeSort)
        }
    }

    Connections {
        target: appList
        function onFreeSortViewFolderClicked(folderId, folderName, triggerPosition) {
            let point = mapFromItem(appList, triggerPosition)
            folderGridViewPopup.startPointX = point.x
            folderGridViewPopup.startPointY = point.y
            folderGridViewPopup.currentFolderId = folderId
            folderGridViewPopup.folderName = folderName
            folderGridViewPopup.open()

            appArea.opacity = 0.1
        }
    }
}
