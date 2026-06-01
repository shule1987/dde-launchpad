// SPDX-FileCopyrightText: 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

pragma Singleton

import QtQuick 2.15

QtObject {
    enum ItemType {
        AppItemType = 0,
        FolderItemType = 1
    }

    enum DndOperation {
        DndPrepend = -1,
        DndJoin = 0,
        DndAppend = 1
    }

    signal folderPageCountChanged(int folderId)
    signal folderRemoved(int folderId)

    function folderEntriesForItem(id) {
        return []
    }

    function addItemToFolder(id, folderId) {
        return true
    }

    function addItemToNewFolder(id) {
        return true
    }

    function dissolveFolder(folderId) {
        folderRemoved(folderId)
        return true
    }
}
