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

    property alias currentIndex: searchResultGridViewContainer.currentIndex
    readonly property alias currentItem: searchResultGridViewContainer.currentItem
    readonly property int resultCount: delegateSearchResultModel.count

    DelegateModel {
        id: delegateSearchResultModel
        model: SearchFilterProxyModel

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
        placeholderIcon: "search_no_result"
        placeholderText: qsTranslate("SearchResultView", "No search results")
        placeholderIconSize: 256
        model: delegateSearchResultModel
        padding: 0
        interactive: true
        vScrollBar: ScrollBar {
            visible: parent.model.count > 4 * 7
            active: parent.model.count > 4 * 7
        }
    }
}
