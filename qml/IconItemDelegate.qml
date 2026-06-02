// SPDX-FileCopyrightText: 2023 - 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15
import QtQuick.Window 2.15
import QtQml.Models 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import org.deepin.dtk 1.0
import org.deepin.dtk.private 1.0
import org.deepin.dtk 1.0 as D
import org.deepin.dtk.style 1.0 as DS

import org.deepin.launchpad 1.0
import org.deepin.launchpad.models 1.0
import 'windowed'

Control {
    id: root

    property var icons: undefined

    // TODO: When DciIcon changes the sourceSize, the icon will flash, It may be a bug of dciicon or qt?
    // So we give the max sourceSize and use scale to solve it.
    property int maxIconSize: 128
    property int maxIconSizeInFolder: 64
    readonly property int folderPreviewGridSize: 3
    readonly property int folderPreviewMaxIcons: folderPreviewGridSize * folderPreviewGridSize
    readonly property string text: display.startsWith("internal/category/") ? getCategoryName(display.substring(18)) : display

    property string iconSource
    property bool dndEnabled: false
    property bool isDragHover: false
    readonly property bool isWindowedMode: LauncherController.currentFrame === "WindowedFrame"
    readonly property real folderBackgroundRadius: dragAndfolderBackground.radius
    property font displayFont: root.font
    property real iconScaleFactor: 1.0
    readonly property real labelSpacerHeight: isWindowedMode ? 4 : root.height / 10
    readonly property real gridIconVisualScale: isWindowedMode ? 1 : 1.12
    readonly property real folderIconSizeRatio: 0.8
    readonly property real gridLabelGapReduction: isWindowedMode ? 0
        : Math.max(0, Math.min(root.height / 14, labelSpacerHeight - 4))
    property bool iconIntroAnimRunning: false
    property bool hoverVisualEnabled: true
    property real labelOpacity: 1.0
    property Item glassSourceItem: null
    property real glassSampleRevision: 0
    property bool glassLive: true
    property bool glassEffect: true
    property bool dragImageReady: false
    property bool proxyDragPending: false
    property string dragImageCacheKey: ""
    property url dragImageCacheUrl: ""

    function folderBackgroundRect(targetItem) {
        const itemPos = iconVisualItem.mapToItem(targetItem, 0, 0)
        return Qt.rect(itemPos.x, itemPos.y, iconVisualItem.width, iconVisualItem.height)
    }

    function folderBackgroundLocalRect() {
        const itemPos = iconVisualItem.mapToItem(root, 0, 0)
        return Qt.rect(itemPos.x, itemPos.y, iconVisualItem.width, iconVisualItem.height)
    }

    function appIconVisualLocalRect() {
        const containerRect = folderBackgroundLocalRect()
        const visualScale = Math.max(0.01, (iconVisualItem.width / root.maxIconSize) * root.iconScaleFactor)
        const visualWidth = iconVisualItem.width * visualScale
        const visualHeight = iconVisualItem.height * visualScale
        return Qt.rect(
            containerRect.x + (containerRect.width - visualWidth) / 2,
            containerRect.y + (containerRect.height - visualHeight) / 2,
            visualWidth,
            visualHeight
        )
    }

    function folderPreviewIconVisualRect(index, targetItem) {
        const spacing = 5
        const itemWidth = Math.max(1, (iconVisualItem.width - ((folderPreviewGridSize + 1) * spacing)) / folderPreviewGridSize)
        const itemHeight = Math.max(1, (iconVisualItem.height - ((folderPreviewGridSize + 1) * spacing)) / folderPreviewGridSize)
        const column = index % folderPreviewGridSize
        const row = Math.floor(index / folderPreviewGridSize)
        const itemX = (column + 1) * spacing + column * itemWidth
        const itemY = (row + 1) * spacing + row * itemHeight
        const visualScale = Math.max(0.01, (itemWidth / root.maxIconSizeInFolder) * root.iconScaleFactor)
        const visualWidth = itemWidth * visualScale
        const visualHeight = itemHeight * visualScale
        const itemPos = iconVisualItem.mapToItem(
            targetItem,
            itemX + (itemWidth - visualWidth) / 2,
            itemY + (itemHeight - visualHeight) / 2
        )
        return Qt.rect(itemPos.x, itemPos.y, visualWidth, visualHeight)
    }

    function folderPreviewImageSource() {
        const previewIcons = folderPreviewIcons()
        if (previewIcons.length === 0) {
            return ""
        }

        return "image://launcher-folder/" + previewIcons.join(":")
    }

    function folderPreviewIcons() {
        if (!icons || icons.length === undefined) {
            return []
        }

        const result = []
        for (let i = 0; i < icons.length && result.length < folderPreviewMaxIcons; ++i) {
            if (icons[i] && icons[i] !== "") {
                result.push(icons[i])
            }
        }
        return result
    }

    function currentDragImageCacheKey() {
        const sourceKey = root.icons !== undefined ? ("folder:" + folderPreviewIcons().join(":")) : root.iconSource
        const backgroundKey = root.glassSourceItem !== null ? ("glass:" + root.glassSampleRevision) : "plain"
        return sourceKey + "|" + backgroundKey
            + "|" + Math.round(iconVisualItem.width * Screen.devicePixelRatio)
            + "x" + Math.round(iconVisualItem.height * Screen.devicePixelRatio)
            + "|" + root.iconScaleFactor
    }

    function clampedDragHotSpot(mouseX, mouseY) {
        const iconPoint = inputLayer.mapToItem(iconVisualItem, mouseX, mouseY)
        if (iconPoint.x < 0
                || iconPoint.x > iconVisualItem.width
                || iconPoint.y < 0
                || iconPoint.y > iconVisualItem.height) {
            return Qt.point(iconVisualItem.width / 2, iconVisualItem.height / 2)
        }

        return Qt.point(
            Math.max(0, Math.min(iconVisualItem.width, iconPoint.x)),
            Math.max(0, Math.min(iconVisualItem.height, iconPoint.y))
        )
    }

    Accessible.name: iconItemLabel.text

    signal folderClicked()
    signal itemClicked()
    signal menuTriggered()

    Drag.dragType: Drag.Automatic

    states: State {
        name: "dragged";
        when: inputLayer.dragActive
        // FIXME: When dragging finished, the position of the item is changed for unknown reason,
        //        so we use the state to reset the x and y here.
        PropertyChanges {
            target: root
            x: x
            y: y
        }
    }

    contentItem: Button {
        id: iconButton
        hoverEnabled: root.hoverVisualEnabled && !root.iconIntroAnimRunning
        focusPolicy: Qt.NoFocus
        ColorSelector.pressed: false
        ColorSelector.family: D.Palette.CrystalColor
        flat: true

        contentItem: Item {
            anchors.fill: parent

            Column {
                id: contentColumn
                anchors.fill: parent

                Item {
                // actually just a top padding
                width: root.width
                height: isWindowedMode ? 7 : root.height / 9
            }

            Item {
                id: iconContainer
                width: parent.width / 2 * root.gridIconVisualScale
                height: parent.width / 2 + root.gridLabelGapReduction
                readonly property real visualSlotSize: width
                readonly property real visualSlotY: root.gridLabelGapReduction > 0
                    ? height - visualSlotSize
                    : (height - visualSlotSize) / 2
                anchors.horizontalCenter: parent.horizontalCenter

                Item {
                    id: iconVisualItem
                    width: !isWindowedMode && root.icons !== undefined
                        ? iconContainer.width * root.folderIconSizeRatio
                        : iconContainer.width
                    height: width
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: iconContainer.visualSlotY + (iconContainer.visualSlotSize - height) / 2

                    Rectangle {
                        id: dragAndfolderBackground
                        visible: root.glassSourceItem === null && opacity > 0
                        opacity: root.icons !== undefined || (root.isDragHover && !isWindowedMode) ? 1 : 0
                        scale:  (root.isDragHover && !isWindowedMode) ? 1.2 : 1
                        color: "#26FFFFFF"
                        Behavior on opacity {
                            NumberAnimation { duration: 200 * LauncherController.animationSpeedScale; easing.type: Easing.OutQuad }
                        }
                        Behavior on scale {
                            NumberAnimation { duration: 200 * LauncherController.animationSpeedScale; easing.type: Easing.OutCubic }
                        }
                        anchors.fill: parent
                        radius: 12

                        NumberAnimation {
                            id: ininAni
                            target: dragAndfolderBackground
                            property: "scale"
                            running: false
                            from: 1.2
                            to: 1
                            duration: 200 * LauncherController.animationSpeedScale
                            easing.type: Easing.OutCubic
                        }

                        Component.onCompleted: {
                            if (root.icons !== undefined && dndItem.mergeAnimTargetIcon && dndItem.mergeAnimTargetIcon2) {
                                ininAni.start()
                            }
                        }
                    }

                    FrostedGlassBackground {
                        anchors.fill: parent
                        visible: root.glassSourceItem !== null && opacity > 0
                        opacity: root.icons !== undefined || (root.isDragHover && !isWindowedMode) ? 1 : 0
                        scale: (root.isDragHover && !isWindowedMode) ? 1.2 : 1
                        radius: dragAndfolderBackground.radius
                        sourceItem: root.glassSourceItem
                        sampleRevision: root.glassSampleRevision
                        live: root.glassLive
                        effectEnabled: root.glassEffect
                        textureScale: 0.5

                        Behavior on opacity {
                            NumberAnimation { duration: 200 * LauncherController.animationSpeedScale; easing.type: Easing.OutQuad }
                        }
                        Behavior on scale {
                            NumberAnimation { duration: 200 * LauncherController.animationSpeedScale; easing.type: Easing.OutCubic }
                        }
                    }

                    Loader {
                        id: iconLoader
                        anchors.fill: parent
                        asynchronous: true
                        sourceComponent: root.icons !== undefined ? folderComponent : imageComponent
                    }
                }

                DciIcon {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom

                    name: "emblem_autostart"
                    visible: autoStart
                    sourceSize: Qt.size(16, 16)
                    palette: DTK.makeIconPalette(root.palette)
                    theme: ApplicationHelper.DarkType
                }

                Component {
                    id: folderComponent

                    Item {
                        anchors.fill: parent

                        Loader {
                            anchors.fill: parent
                            sourceComponent: dndItem.mergeAnimPending ? folderAnimatedPreviewComponent : folderStaticPreviewComponent
                        }
                    }
                }

                Component {
                    id: folderStaticPreviewComponent

                    Item {
                        id: staticIconItem
                        anchors.fill: parent
                        property real maxIconCount: root.folderPreviewGridSize
                        property real spacing: 5
                        property real itemWidth: (width - ((maxIconCount + 1) * spacing)) / maxIconCount
                        property real itemHeight: (height - ((maxIconCount + 1) * spacing)) / maxIconCount
                        readonly property var visibleIcons: root.folderPreviewIcons()

                        function getItemX(index) {
                            let col = index % maxIconCount
                            return (col + 1) * spacing + col * itemWidth
                        }

                        function getItemY(index) {
                            let row = Math.floor(index / maxIconCount)
                            return (row + 1) * spacing + row * itemHeight
                        }

                        Repeater {
                            model: staticIconItem.visibleIcons

                            DciIcon {
                                x: staticIconItem.getItemX(index)
                                y: staticIconItem.getItemY(index)
                                width: staticIconItem.itemWidth
                                height: staticIconItem.itemHeight
                                name: modelData
                                sourceSize: Qt.size(root.maxIconSizeInFolder, root.maxIconSizeInFolder)
                                scale: (staticIconItem.itemWidth / root.maxIconSizeInFolder) * root.iconScaleFactor
                                palette: DTK.makeIconPalette(root.palette)
                                theme: ApplicationHelper.DarkType
                            }
                        }
                    }
                }

                Component {
                    id: folderAnimatedPreviewComponent

                    Item {
                        id: iconItem
                        anchors.fill: parent
                        property real maxIconCount: root.folderPreviewGridSize
                        property real spacing: 5
                        property real itemWidth: (width - ((maxIconCount + 1) * spacing)) / maxIconCount
                        property real itemHeight: (height - ((maxIconCount + 1) * spacing)) / maxIconCount
                        readonly property var visibleIcons: root.folderPreviewIcons()
                        readonly property int visibleIconCount: visibleIcons.length

                        function previewIcons() {
                            return visibleIcons
                        }

                        function getItemX(index) {
                            let col = index % maxIconCount
                            let ItemX = (col + 1) * spacing + col * itemWidth

                            return ItemX
                        }

                        function getItemY(index) {
                            let row = Math.floor(index / maxIconCount)
                            let ItemY = (row + 1) * spacing + row * itemHeight
                            return ItemY
                        }
                        Repeater {
                            model: iconItem.previewIcons()

                            DciIcon {
                                id: folderIcon
                                x: iconItem.getItemX(index)
                                y: iconItem.getItemY(index)

                                width: iconItem.itemWidth
                                height: iconItem.itemHeight

                                name: modelData
                                sourceSize: Qt.size(root.maxIconSizeInFolder, root.maxIconSizeInFolder)
                                scale: (itemWidth / root.maxIconSizeInFolder) * root.iconScaleFactor

                                property real introScale: 1.0

                                palette: DTK.makeIconPalette(root.palette)
                                theme: ApplicationHelper.DarkType

                                // 位移动画属性
                                property real iconCenterX: 0
                                property real iconCenterY: 0
                                ParallelAnimation {
                                    id: iconIntroAnim
                                    onStarted: root.iconIntroAnimRunning = true

                                    NumberAnimation {
                                        target: folderIcon
                                        property: "scale"
                                        from: folderIcon.introScale
                                        to: (itemWidth / root.maxIconSizeInFolder) * root.iconScaleFactor
                                        duration: 600 * LauncherController.animationSpeedScale
                                        easing.type: Easing.OutExpo
                                    }
                                    NumberAnimation {
                                        target: folderIcon
                                        property: "x"
                                        from: folderIcon.iconCenterX; to: iconItem.getItemX(index)
                                        duration: 800 * LauncherController.animationSpeedScale
                                        easing.type: Easing.OutExpo
                                    }
                                    NumberAnimation {
                                        target: folderIcon
                                        property: "y"
                                        from: folderIcon.iconCenterY; to: iconItem.getItemY(index)
                                        duration: 800 * LauncherController.animationSpeedScale
                                        easing.type: Easing.OutExpo
                                    }

                                    onFinished: {
                                        root.iconIntroAnimRunning = false
                                        dndItem.mergeAnimPending = false
                                        dndItem.mergeAnimTargetIcon = ""
                                        dndItem.mergeAnimTargetIcon2 = ""
                                    }
                                }

                                Component.onCompleted: {
                                    if (dndItem.mergeAnimPending
                                        && modelData === dndItem.mergeAnimTargetIcon) {
                                        folderIcon.visible = false
                                        Qt.callLater(function() {
                                            let localPos = iconItem.mapFromItem(null,
                                                dndItem.mergeAnimStartX, dndItem.mergeAnimStartY)
                                            folderIcon.iconCenterX = localPos.x - folderIcon.width / 2
                                            folderIcon.iconCenterY = localPos.y - folderIcon.height / 2
                                            folderIcon.introScale = (iconItem.width / root.maxIconSizeInFolder) * root.iconScaleFactor
                                            folderIcon.visible = true
                                            iconIntroAnim.start()
                                        })
                                    } else if (dndItem.mergeAnimPending
                                        && modelData === dndItem.mergeAnimTargetIcon2) {
                                        Qt.callLater(function() {
                                            folderIcon.iconCenterX = iconItem.width / 2 - folderIcon.width / 2
                                            folderIcon.iconCenterY = iconItem.height / 2 - folderIcon.height / 2
                                            folderIcon.introScale = (iconItem.width / root.maxIconSizeInFolder) * root.iconScaleFactor
                                            iconIntroAnim.start()
                                        })
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: Math.max(0, root.folderPreviewMaxIcons - iconItem.visibleIconCount)

                            Item {
                                Layout.fillHeight: true
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop | Qt.AlignLeft

                                width: parent.width / root.folderPreviewGridSize
                                height: parent.height / root.folderPreviewGridSize
                            }
                        }
                    }
                }

                Component {
                    id: imageComponent

                    DciIcon {
                        objectName: "appIcon"
                        anchors.fill: parent
                        name: iconSource
                        sourceSize: Qt.size(root.maxIconSize, root.maxIconSize)
                        scale: (iconVisualItem.width / root.maxIconSize) * root.iconScaleFactor
                        palette: DTK.makeIconPalette(root.palette)
                        theme: ApplicationHelper.DarkType
                        fillMode: Image.PreserveAspectFit
                    }
                }
            }

            // as topMargin
            Item {
                width: 1
                height: Math.max(0, root.labelSpacerHeight - root.gridLabelGapReduction)
            }

            Label {
                property bool singleRow: font.pixelSize > (isWindowedMode ? Helper.windowed.doubleRowMaxFontSize : Helper.fullscreen.doubleRowMaxFontSize)
                property bool isNewlyInstalled: model.lastLaunchedTime === 0 && model.installedTime !== 0
                readonly property int horizontalInset: isWindowedMode ? 8 : 12
                id: iconItemLabel
                visible: !root.isDragHover
                opacity: root.labelOpacity
                text: isNewlyInstalled ? ("<font color='#669DFF' size='1' style='text-shadow: 0 0 1px rgba(255,255,255,0.1)'>●</font>&nbsp;&nbsp;" + root.text) : root.text
                textFormat: isNewlyInstalled ? Text.StyledText : Text.PlainText
                width: Math.max(0, parent.width - horizontalInset * 2)
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                wrapMode: singleRow ? Text.NoWrap : Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: singleRow ? 1 : 2
                font: LauncherController.adjustFontWeight(root.displayFont, Font.Light)
            }

        }

        Item {
            id: inputLayer
            anchors.fill: parent
            z: 1000
            property real lastMouseX: 0
            property real lastMouseY: 0
            property bool leftButtonPressed: false
            readonly property bool dragActive: dragHandler.active

            function updateProxyDragPosition() {
                if (!dndItem || !dndItem.parent) {
                    return
                }

                const proxyPos = mapToItem(dndItem.parent, lastMouseX, lastMouseY)
                dndItem.x = proxyPos.x - dndItem.Drag.hotSpot.x
                dndItem.y = proxyPos.y - dndItem.Drag.hotSpot.y
            }

            function prepareDrag(mouseX, mouseY) {
                lastMouseX = mouseX
                lastMouseY = mouseY
                leftButtonPressed = true
                if (!root.dndEnabled) {
                    return
                }

                root.proxyDragPending = false
                root.Drag.hotSpot = root.clampedDragHotSpot(mouseX, mouseY)
                const cacheKey = root.currentDragImageCacheKey()
                if (root.dragImageReady
                        && root.dragImageCacheKey === cacheKey
                        && root.dragImageCacheUrl !== "") {
                    root.Drag.imageSource = root.dragImageCacheUrl
                    return
                }

                root.dragImageReady = false
                root.Drag.imageSource = ""
                iconVisualItem.grabToImage(function(result) {
                    root.Drag.imageSource = result.url
                    root.dragImageCacheKey = cacheKey
                    root.dragImageCacheUrl = result.url
                    root.dragImageReady = true
                    if (root.proxyDragPending || dragHandler.active) {
                        inputLayer.startProxyDragWhenReady()
                    }
                })
            }

            function startProxyDragWhenReady() {
                if (!dragHandler.active || dndItem.Drag.active) {
                    return
                }
                if (!root.dragImageReady || root.Drag.imageSource === "") {
                    root.proxyDragPending = true
                    return
                }

                root.proxyDragPending = false
                dndItem.currentlyDraggedId = root.Drag.mimeData["text/x-dde-launcher-dnd-desktopId"]
                dndItem.currentlyDraggedIconName = root.iconSource
                dndItem.Drag.mimeData = root.Drag.mimeData
                dndItem.Drag.keys = Object.keys(root.Drag.mimeData)
                dndItem.Drag.supportedActions = Qt.MoveAction
                dndItem.mergeSize = Math.min(iconVisualItem.width, iconVisualItem.height)
                dndItem.width = Math.max(1, iconVisualItem.width)
                dndItem.height = Math.max(1, iconVisualItem.height)
                if (typeof dndItem.dragImageSource !== "undefined") {
                    dndItem.dragImageSource = root.Drag.imageSource
                }
                const useQuickDragOverlay = typeof dndItem.useQuickDragOverlay !== "undefined"
                    && dndItem.useQuickDragOverlay
                const useExternalDockDrag = typeof dndItem.externalDockDragEnabled !== "undefined"
                    && dndItem.externalDockDragEnabled
                if (typeof dndItem.visualDragHotSpot !== "undefined") {
                    dndItem.visualDragHotSpot = root.Drag.hotSpot
                }
                dndItem.Drag.hotSpot = useQuickDragOverlay ? Qt.point(0, 0) : root.Drag.hotSpot
                dndItem.Drag.imageSource = useQuickDragOverlay ? "" : root.Drag.imageSource
                dndItem.Drag.dragType = useExternalDockDrag ? root.Drag.Automatic : root.Drag.Internal
                updateProxyDragPosition()
                Qt.callLater(function() {
                    if (dragHandler.active && dndItem.currentlyDraggedId === root.Drag.mimeData["text/x-dde-launcher-dnd-desktopId"]) {
                        inputLayer.updateProxyDragPosition()
                        dndItem.Drag.active = true
                    }
                })
            }

            function activateItem() {
                if (model.itemType === ItemArrangementProxyModel.FolderItemType) {
                    root.folderClicked()
                } else {
                    root.itemClicked()
                }
            }

            TapHandler {
                id: leftTapHandler
                acceptedButtons: Qt.LeftButton
                gesturePolicy: TapHandler.WithinBounds
                onPressedChanged: {
                    if (pressed) {
                        inputLayer.prepareDrag(point.pressPosition.x, point.pressPosition.y)
                    } else {
                        inputLayer.leftButtonPressed = false
                    }
                }
                onTapped: inputLayer.activateItem()
            }

            TapHandler {
                acceptedButtons: Qt.RightButton
                gesturePolicy: TapHandler.WithinBounds
                onTapped: root.menuTriggered()
            }

            DragHandler {
                id: dragHandler
                enabled: root.dndEnabled
                acceptedButtons: Qt.LeftButton
                target: root.dndEnabled && inputLayer.leftButtonPressed ? root : null

                onCentroidChanged: {
                    inputLayer.lastMouseX = centroid.position.x
                    inputLayer.lastMouseY = centroid.position.y
                    if (active) {
                        inputLayer.updateProxyDragPosition()
                    }
                }

                onActiveChanged: {
                    if (active) {
                        inputLayer.lastMouseX = centroid.position.x
                        inputLayer.lastMouseY = centroid.position.y
                        if (!inputLayer.leftButtonPressed) {
                            inputLayer.prepareDrag(centroid.position.x, centroid.position.y)
                        }
                        if (typeof suppressAutoHide === "function") {
                            suppressAutoHide()
                        } else {
                            LauncherController.cancelHide()
                        }
                        inputLayer.startProxyDragWhenReady()
                    } else {
                        inputLayer.leftButtonPressed = false
                        root.proxyDragPending = false
                        if (dndItem.currentlyDraggedId === root.Drag.mimeData["text/x-dde-launcher-dnd-desktopId"]) {
                            if (dndItem.Drag.active) {
                                dndItem.Drag.active = false
                                return
                            }
                            dndItem.currentlyDraggedId = ""
                            dndItem.currentlyDraggedIconName = ""
                        }
                    }
                }
            }

            TapHandler {
                acceptedDevices: PointerDevice.TouchScreen | PointerDevice.TouchPad
                gesturePolicy: TapHandler.WithinBounds
                onLongPressed: root.menuTriggered()
            }
        }
        }
        ToolTip.text: root.text
        ToolTip.delay: 500
        ToolTip.visible: hovered && iconItemLabel.truncated
        background: Loader {
            active: true
            sourceComponent: ItemBackground {
                radius: isWindowedMode ? 8 : 18
                button: iconButton
            }
        }
    }
    background: DebugBounding { }

    Keys.onSpacePressed: {
        if (model.itemType === ItemArrangementProxyModel.FolderItemType) {
            root.folderClicked()
        } else {
            root.itemClicked()
        }
    }

    Keys.onReturnPressed: {
        if (model.itemType === ItemArrangementProxyModel.FolderItemType) {
            root.folderClicked()
        } else {
            root.itemClicked()
        }
    }
}
