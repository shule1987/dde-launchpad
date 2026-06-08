// SPDX-FileCopyrightText: 2024 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.deepin.dtk 1.0
import org.deepin.ds 1.0
import org.deepin.dtk.style 1.0 as DStyle

import org.deepin.launchpad 1.0
import org.deepin.launchpad.models 1.0
import "."

Control {
    id: control

    property Item keyTabTarget: shutdownBtn
    property Item nextKeyTabTarget
    property alias searchEdit: searchEdit
    property var searchNavigationKeyHandler: null

    padding: 10

    contentItem: RowLayout {
        ToolButton {
            id: shutdownBtn
            icon.name: "shutdown"
            icon.width: 16
            icon.height: 16
            background: ItemBackground {
               button: shutdownBtn
            }
            ToolTip.visible: hovered
            ToolTip.delay: 500
            ToolTip.text: qsTr("Power")
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            onClicked: {
                var shutdown = DS.applet("org.deepin.ds.dde-shutdown")
                if (shutdown) {
                    shutdown.requestShutdown()
                } else {
                    console.warn("shutdown applet not found")
                }
            }
        }

        // TODO dtk's bug, ColorSelector's control is wrong for SearchEdit.
        Control {
            Layout.preferredWidth: 360
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            Layout.preferredHeight: 30

            contentItem: SearchEdit {
                id: searchEdit
                padding: 1
                placeholder: qsTr("Search")
                property Palette textColor: DStyle.Style.button.text
                placeholderTextColor: ColorSelector.textColor
                palette.windowText: ColorSelector.textColor
                ColorSelector.pressed: false

                onTextChanged: {
                    console.log(text)
                    searchEdit.focus = true
                    SearchFilterProxyModel.searchText = text.trim()
                }

                function handleSearchNavigationKey(key) {
                    if (searchEdit.text.trim() === "") {
                        return false
                    }

                    if (typeof control.searchNavigationKeyHandler === "function") {
                        control.searchNavigationKeyHandler(key)
                    }
                    return true
                }

                Keys.onPressed: function(event) {
                    switch (event.key) {
                    case Qt.Key_Left:
                    case Qt.Key_Right:
                    case Qt.Key_Up:
                    case Qt.Key_Down:
                        if (searchEdit.handleSearchNavigationKey(event.key)) {
                            event.accepted = true
                        }
                        break
                    }
                }

                property Palette edittingPalette: Palette {
                    normal {
                        crystal: Qt.rgba(0, 0, 0, 0.1)
                    }
                    normalDark {
                        crystal: Qt.rgba(1, 1, 1, 0.1)
                    }
                }

                property Palette nomalPalette: Palette {
                    normal {
                        crystal: ("transparent")
                    }
                    normalDark {
                        crystal: ("transparent")
                    }
                    hovered {
                        crystal:  Qt.rgba(0, 0, 0, 0.05)
                    }
                    hoveredDark {
                        crystal:  Qt.rgba(1, 1, 1, 0.05)
                    }
                }

                backgroundColor: searchEdit.editting ? edittingPalette : nomalPalette
            }
        }

        ToolButton {
            id: fullscreenBtn
            icon.name: "launcher_fullscreen"
            icon.width: 16
            icon.height: 16
            background: ItemBackground {
                button: fullscreenBtn
            }
            ToolTip.visible: hovered
            ToolTip.delay: 500
            ToolTip.text: qsTr("Full-screen Mode")
            Accessible.name: "Fullscreen"
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            onClicked: {
                searchEdit.text = ""
                LauncherController.setCurrentFrameToFullscreenFrame()
            }
            KeyNavigation.tab: nextKeyTabTarget
        }
    }

    background: DebugBounding { }
}
