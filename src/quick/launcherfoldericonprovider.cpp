// SPDX-FileCopyrightText: 2023 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

#include "launcherfoldericonprovider.h"

#include "iconutils.h"

#include <QPainter>
#include <QLoggingCategory>
#include <QMutexLocker>

Q_DECLARE_LOGGING_CATEGORY(logQuick)

LauncherFolderIconProvider::LauncherFolderIconProvider():
    QQuickImageProvider(QQuickImageProvider::Pixmap)
{
    m_cache.setMaxCost(8192);
}

LauncherFolderIconProvider::~LauncherFolderIconProvider()
{

}

QPixmap LauncherFolderIconProvider::requestPixmap(const QString &id, QSize *size, const QSize &requestedSize)
{
    constexpr int iconPerRow = 3;

    QSize preferredSize = requestedSize.isValid()
                              ? requestedSize
                              : ((size && size->isValid()) ? *size : QSize(64, 64));
    if (size) {
        *size = preferredSize;
    }

    const QString cacheKey = id + QLatin1Char('@')
        + QString::number(preferredSize.width()) + QLatin1Char('x')
        + QString::number(preferredSize.height());
    {
        QMutexLocker locker(&m_cacheMutex);
        if (QPixmap *cached = m_cache.object(cacheKey)) {
            return *cached;
        }
    }

    const auto [iconSize, padding] = IconUtils::getFolderPerfectIconCell(preferredSize.width(), iconPerRow);
    int iconSpacing = padding;
    qCDebug(logQuick) << "Calculated icon size:" << iconSize << "padding:" << padding;
    QPixmap result(preferredSize);
    result.fill(Qt::transparent);

    QPainter painter;
    painter.begin(&result);

    // icons
    // uri: image://provider/icon-name:icon-name:icon-name
    // ids: icon-name:icon-name:icon-name
    const QStringList ids(id.split(':', Qt::SkipEmptyParts));
    int curIdx = 0;
    for (const QString & icon : ids) {
        if (icon.isEmpty()) {
            continue;
        }
        if (curIdx >= iconPerRow * iconPerRow) {
            break;
        }
        int curRow = curIdx / iconPerRow;
        int curCol = curIdx % iconPerRow;
        QPixmap iconPixmap(QSize(iconSize, iconSize));
        iconPixmap.fill(Qt::transparent);
        IconUtils::getThemeIcon(iconPixmap, icon, iconSize);
        QRect iconRect;
        iconRect.setTop(padding + curRow * (iconSize + iconSpacing));
        iconRect.setLeft(padding + curCol * (iconSize + iconSpacing));
        iconRect.setSize(QSize(iconSize, iconSize));
        painter.drawPixmap(iconRect, iconPixmap);
        curIdx++;
    }

    painter.end();
    const int cacheCost = qMax(1, result.width() * result.height() * result.depth() / 8 / 1024);
    {
        QMutexLocker locker(&m_cacheMutex);
        m_cache.insert(cacheKey, new QPixmap(result), cacheCost);
    }
    qCDebug(logQuick) << "Folder icon pixmap created successfully, size:" << result.size();
    return result;
}
