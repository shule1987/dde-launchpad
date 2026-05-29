// SPDX-FileCopyrightText: 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15
import QtTest 1.3
import org.deepin.launchpad 1.0

TestCase {
    id: testCase
    name: "FullscreenHeaderIndicatorClick"
    width: 400
    height: 120
    visible: true
    when: windowShown

    QtObject {
        id: fakePageView
        property int count: 3
        property int currentIndex: 0
        property bool changedByNonKeyboard: false

        function setCurrentIndex(index) {
            currentIndex = index
        }
    }

    Item {
        id: glassSource
        width: testCase.width
        height: testCase.height
    }

    FullscreenHeader {
        id: header
        width: testCase.width
        bandHeight: 80
        searchActive: false
        pageView: fakePageView
        glassSourceItem: glassSource
        glassSampleRevision: 0
        glassLive: false
        glassEffect: false
    }

    function init() {
        fakePageView.currentIndex = 0
        fakePageView.changedByNonKeyboard = false
        LauncherController.visible = true
        LauncherController.suppressCount = 0
    }

    function thirdIndicatorPoint() {
        return Qt.point(header.width / 2 + 24, header.height / 2)
    }

    function indicatorEdgeHoverPoint() {
        return Qt.point(
            header.width / 2 + header.indicatorBaseWidth * header.indicatorHoverScale / 2 + 1,
            header.height / 2
        )
    }

    function test_hoverScalesTopIndicator() {
        waitForRendering(header)

        const indicator = findChild(header, "fullscreenPageIndicator")
        const background = findChild(header, "fullscreenPageIndicatorHoverBackground")
        verify(indicator !== null)
        verify(background !== null)
        compare(indicator.scale, 1)
        compare(background.scale, 1)
        compare(background.opacity, 0)

        const hoverPoint = thirdIndicatorPoint()
        mouseMove(testCase, hoverPoint.x, hoverPoint.y)
        tryCompare(indicator, "scale", 1.5)
        tryCompare(background, "scale", 1.5)
        tryCompare(background, "opacity", 1)

        mouseMove(testCase, 0, 0)
        tryCompare(indicator, "scale", 1)
        tryCompare(background, "scale", 1)
        tryCompare(background, "opacity", 0)
    }

    function test_nearIndicatorEdgeHoverScalesTopIndicator() {
        waitForRendering(header)

        const indicator = findChild(header, "fullscreenPageIndicator")
        const background = findChild(header, "fullscreenPageIndicatorHoverBackground")
        verify(indicator !== null)
        verify(background !== null)

        const hoverPoint = indicatorEdgeHoverPoint()
        verify(header.pointInPageIndicator(hoverPoint.x, hoverPoint.y))
        mouseMove(testCase, hoverPoint.x, hoverPoint.y)
        tryCompare(indicator, "scale", 1.5)
        tryCompare(background, "scale", 1.5)
        tryCompare(background, "opacity", 1)
    }

    function test_switchPageIndicatorAtSwitchesPageFromParentPressPath() {
        compare(fakePageView.currentIndex, 0)
        waitForRendering(header)

        const clickPoint = thirdIndicatorPoint()
        verify(header.pointInPageIndicator(clickPoint.x, clickPoint.y))
        verify(header.switchPageIndicatorAt(clickPoint.x, clickPoint.y))

        compare(fakePageView.currentIndex, 2)
        verify(fakePageView.changedByNonKeyboard)
    }

    function test_clickThirdTopIndicatorSwitchesPage() {
        compare(fakePageView.currentIndex, 0)
        waitForRendering(header)

        const clickPoint = thirdIndicatorPoint()
        const clickX = clickPoint.x
        const clickY = clickPoint.y
        verify(header.pointInPageIndicator(clickX, clickY))

        mouseClick(testCase, clickX, clickY, Qt.LeftButton)
        tryCompare(fakePageView, "currentIndex", 2)
        verify(fakePageView.changedByNonKeyboard)
        compare(LauncherController.visible, true)
        compare(LauncherController.suppressCount, 1)
    }
}
