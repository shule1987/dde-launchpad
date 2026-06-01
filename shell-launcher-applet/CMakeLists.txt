# SPDX-FileCopyrightText: 2023 UnionTech Software Technology Co., Ltd.
#
# SPDX-License-Identifier: GPL-3.0-or-later

find_package(DDEShell REQUIRED)

set(LAUNCHERAPPLET_PACKAGE org.deepin.ds.dock.launcherapplet)

add_library(shell-launcherapplet SHARED
    launcheritem.cpp
    launcheritem.h
)

target_link_libraries(shell-launcherapplet PRIVATE
    Dde::Shell
    launchpadcommon
)

ds_install_package(PACKAGE ${LAUNCHERAPPLET_PACKAGE} TARGET shell-launcherapplet)
ds_handle_package_translation(
PACKAGE ${LAUNCHERAPPLET_PACKAGE}
QML_FILES
    ${QML_FILES_NEED_TRANSLATION}
    ${CMAKE_CURRENT_LIST_DIR}/package/launcheritem.qml
SOURCE_FILES
    ${PROJECT_SOURCE_DIR}/desktopintegration.cpp
    ${PROJECT_SOURCE_DIR}/src/ddeintegration/appwiz.cpp
    ${PROJECT_SOURCE_DIR}/src/models/itemarrangementproxymodel.cpp
)

set(LAUNCHERAPPLET_TRANSLATION_SUFFIXES
    "_ar"
    "_az"
    "_bo"
    "_ca"
    "_de"
    "_es"
    "_fi"
    "_fr"
    "_hu"
    "_it"
    "_ja"
    "_ko"
    "_lo"
    "_nb_NO"
    "_pl"
    "_pt_BR"
    "_ru"
    "_sq"
    "_uk"
    "_zh_CN"
    "_zh_HK"
    "_zh_TW"
)

set(LAUNCHERAPPLET_TRANSLATION_QM_FILES
    ${CMAKE_CURRENT_BINARY_DIR}/${LAUNCHERAPPLET_PACKAGE}.qm
)
foreach(TRANSLATION_SUFFIX ${LAUNCHERAPPLET_TRANSLATION_SUFFIXES})
    list(APPEND LAUNCHERAPPLET_TRANSLATION_QM_FILES
        ${CMAKE_CURRENT_BINARY_DIR}/${LAUNCHERAPPLET_PACKAGE}${TRANSLATION_SUFFIX}.qm
    )
endforeach()

add_dependencies(${LAUNCHERAPPLET_PACKAGE}_package release_translations)
add_custom_command(TARGET ${LAUNCHERAPPLET_PACKAGE}_package POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory ${PROJECT_BINARY_DIR}/packages/${LAUNCHERAPPLET_PACKAGE}/translations
    COMMAND ${CMAKE_COMMAND} -E copy_if_different ${LAUNCHERAPPLET_TRANSLATION_QM_FILES} ${PROJECT_BINARY_DIR}/packages/${LAUNCHERAPPLET_PACKAGE}/translations
)
