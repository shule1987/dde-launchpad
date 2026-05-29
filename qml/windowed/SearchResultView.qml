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

    function resetCurrentPage() {
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
                    model: pageSliceModel
                    activeFocusOnTab: searchResultPagesView.gridViewFocus

                    delegate: IconItemDelegate {
                        width: searchResultViewContainer.cellWidth
                        height: searchResultViewContainer.cellHeight
                        iconSource: iconName
                        onItemClicked: {
                            launchApp(desktopId)
                        }
                        onMenuTriggered: {
                            showContextMenu(this, model)
                            baseLayer.focus = true
                        }
                    }

                    Keys.onLeftPressed: function(event) {
                        event.accepted = true

                        if (pageSliceModel.count <= 0) {
                            return
                        }

                        const current = searchResultViewContainer.currentIndex
                        if (current > 0) {
                            searchResultViewContainer.currentIndex = current - 1
                            return
                        }

                        if (searchResultPagesView.count <= 1) {
                            searchResultViewContainer.currentIndex = pageSliceModel.count - 1
                            return
                        }

                        const targetPage = pageDelegate.pageIndex === 0 ? searchResultPagesView.count - 1 : pageDelegate.pageIndex - 1
                        searchResultPagesView.pendingGridIndex = control.pageSize - 1
                        searchResultPagesView.setCurrentIndex(targetPage)
                    }

                    Keys.onRightPressed: function(event) {
                        event.accepted = true

                        if (pageSliceModel.count <= 0) {
                            return
                        }

                        const current = searchResultViewContainer.currentIndex
                        if (current < pageSliceModel.count - 1) {
                            searchResultViewContainer.currentIndex = current + 1
                            return
                        }

                        if (searchResultPagesView.count <= 1) {
                            searchResultViewContainer.currentIndex = 0
                            return
                        }

                        const targetPage = pageDelegate.pageIndex === searchResultPagesView.count - 1 ? 0 : pageDelegate.pageIndex + 1
                        searchResultPagesView.pendingGridIndex = 0
                        searchResultPagesView.setCurrentIndex(targetPage)
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
            onCurrentIndexChanged: searchResultPagesView.setCurrentIndex(currentIndex)
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
