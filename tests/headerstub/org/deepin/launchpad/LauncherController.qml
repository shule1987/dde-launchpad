// SPDX-FileCopyrightText: 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

pragma Singleton

import QtQuick 2.15

QtObject {
    property bool visible: true
    readonly property int animationSpeedScale: 1
    property int suppressCount: 0

    function suppressNextHideForInputFocus() {
        suppressCount += 1
    }
}
