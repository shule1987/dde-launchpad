// SPDX-FileCopyrightText: 2023 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QCache>
#include <QMutex>
#include <QQuickImageProvider>

class LauncherFolderIconProvider : public QQuickImageProvider {
public:
    LauncherFolderIconProvider();
    ~LauncherFolderIconProvider();

    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override;

private:
    QCache<QString, QPixmap> m_cache;
    QMutex m_cacheMutex;
};
