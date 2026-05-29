// SPDX-FileCopyrightText: 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15

Item {
    property real radius: 0
    property Item sourceItem: null
    property real sampleRevision: 0
    property bool live: false
    property bool effectEnabled: false
    property real textureScale: 1
    property real brightness: 0
    property color tintColor: "transparent"
    property color borderColor: "transparent"
}
