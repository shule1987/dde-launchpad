# SPDX-FileCopyrightText: 2024 UnionTech Software Technology Co., Ltd.
#
# SPDX-License-Identifier: CC0-1.0

find_package(Qt6 REQUIRED COMPONENTS Core Test)

qt_standard_project_setup()

macro(launchpad_add_tests)
    foreach(_testname ${ARGN})
        qt_add_executable(launchpad-${_testname} ${_testname}.cpp)
        target_link_libraries(launchpad-${_testname} PRIVATE Qt6::Core Qt6::Test launchpadcommon)
        add_test(
            NAME launchpad-${_testname}
            COMMAND ${CMAKE_COMMAND} -E env
                    LD_LIBRARY_PATH=$<TARGET_FILE_DIR:launchpadcommon>
                    $<TARGET_FILE:launchpad-${_testname}>
        )
    endforeach()
endmacro()

launchpad_add_tests(
    itemspagetest
    gioappinfotest
    searchfilterproxymodeltest
)

target_sources(launchpad-searchfilterproxymodeltest PRIVATE
    ${CMAKE_SOURCE_DIR}/src/models/pagesliceproxymodel.cpp
    ${CMAKE_SOURCE_DIR}/src/models/pagesliceproxymodel.h
)

find_program(QT6_QMLTESTRUNNER_EXECUTABLE
    NAMES qmltestrunner
    PATHS /usr/lib/qt6/bin
    NO_DEFAULT_PATH
)
if(NOT QT6_QMLTESTRUNNER_EXECUTABLE)
    find_program(QT6_QMLTESTRUNNER_EXECUTABLE NAMES qmltestrunner)
endif()
if(QT6_QMLTESTRUNNER_EXECUTABLE)
    add_test(
        NAME launchpad-pageindicator-click
        COMMAND ${CMAKE_COMMAND} -E env QT_QPA_PLATFORM=offscreen
                ${QT6_QMLTESTRUNNER_EXECUTABLE}
                -input ${CMAKE_CURRENT_SOURCE_DIR}/tst_pageindicator_click.qml
                -o -,txt
    )
    add_test(
        NAME launchpad-fullscreen-header-indicator-click
        COMMAND ${CMAKE_COMMAND} -E env QT_QPA_PLATFORM=offscreen
                QML2_IMPORT_PATH=${CMAKE_CURRENT_SOURCE_DIR}/headerstub
                ${QT6_QMLTESTRUNNER_EXECUTABLE}
                -input ${CMAKE_CURRENT_SOURCE_DIR}/tst_fullscreen_header_indicator_click.qml
                -o -,txt
    )
    add_test(
        NAME launchpad-gridviewcontainer-item-click
        COMMAND ${CMAKE_COMMAND} -E env QT_QPA_PLATFORM=offscreen
                QML2_IMPORT_PATH=${CMAKE_SOURCE_DIR}/qml:${CMAKE_CURRENT_SOURCE_DIR}/headerstub
                ${QT6_QMLTESTRUNNER_EXECUTABLE}
                -input ${CMAKE_CURRENT_SOURCE_DIR}/tst_gridviewcontainer_item_click.qml
                -o -,txt
    )
endif()
