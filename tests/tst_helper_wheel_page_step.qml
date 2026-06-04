// SPDX-FileCopyrightText: 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15
import QtTest 1.3
import org.deepin.launchpad 1.0

TestCase {
    id: testCase
    name: "HelperWheelPageStep"

    function wheel(pixelX, pixelY, angleX, angleY) {
        return {
            pixelDelta: Qt.point(pixelX, pixelY),
            angleDelta: Qt.point(angleX, angleY)
        }
    }

    function methodPoint(x, y) {
        return {
            x: function() { return x },
            y: function() { return y }
        }
    }

    function methodWheel(pixelX, pixelY, angleX, angleY) {
        return {
            pixelDelta: methodPoint(pixelX, pixelY),
            angleDelta: methodPoint(angleX, angleY)
        }
    }

    function test_touchpadHorizontalPixelDelta() {
        compare(Helper.wheelPageStep(wheel(18, 0, 0, 0)), 1)
        compare(Helper.wheelPageStep(wheel(-18, 0, 0, 0)), -1)
    }

    function test_touchpadVerticalPixelDelta() {
        compare(Helper.wheelPageStep(wheel(0, 18, 0, 0)), -1)
        compare(Helper.wheelPageStep(wheel(0, -18, 0, 0)), 1)
    }

    function test_angleDeltaFallback() {
        compare(Helper.wheelPageStep(wheel(0, 0, 120, 0)), 1)
        compare(Helper.wheelPageStep(wheel(0, 0, -120, 0)), -1)
        compare(Helper.wheelPageStep(wheel(0, 0, 0, 120)), -1)
        compare(Helper.wheelPageStep(wheel(0, 0, 0, -120)), 1)
    }

    function test_pixelDeltaWinsWhenPresent() {
        compare(Helper.wheelPageStep(wheel(18, 0, -120, 0)), 1)
        compare(Helper.wheelPageStep(wheel(0, -18, 0, 120)), 1)
    }

    function test_dominantAxis() {
        compare(Helper.wheelPageStep(wheel(24, 12, 0, 0)), 1)
        compare(Helper.wheelPageStep(wheel(12, 24, 0, 0)), -1)
        compare(Helper.wheelPageStep(wheel(0, 0, 0, 0)), 0)
    }

    function test_functionStylePointComponents() {
        compare(Helper.wheelPageStep(methodWheel(18, 0, 0, 0)), 1)
        compare(Helper.wheelPageStep(methodWheel(0, -18, 0, 120)), 1)
        compare(Helper.wheelPageStep(methodWheel(0, 0, 0, 120)), -1)
    }

    function test_missingPointComponentsFallBackToZero() {
        compare(Helper.wheelPageStep({
            pixelDelta: {},
            angleDelta: Qt.point(0, -120)
        }), 1)
    }
}
