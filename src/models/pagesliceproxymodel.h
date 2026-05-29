// SPDX-FileCopyrightText: 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QSortFilterProxyModel>
#include <QtQml/qqml.h>

class PageSliceProxyModel : public QSortFilterProxyModel
{
    Q_OBJECT
    Q_PROPERTY(QAbstractItemModel *sourceModel READ sourceModel WRITE setSourceModel NOTIFY sourceModelChanged)
    Q_PROPERTY(int pageIndex READ pageIndex WRITE setPageIndex NOTIFY pageIndexChanged)
    Q_PROPERTY(int pageSize READ pageSize WRITE setPageSize NOTIFY pageSizeChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    QML_NAMED_ELEMENT(PageSliceProxyModel)

public:
    explicit PageSliceProxyModel(QObject *parent = nullptr);

    void setSourceModel(QAbstractItemModel *model) override;

    int pageIndex() const;
    void setPageIndex(int pageIndex);

    int pageSize() const;
    void setPageSize(int pageSize);

    int count() const;

signals:
    void sourceModelChanged(QObject *model);
    void pageIndexChanged();
    void pageSizeChanged();
    void countChanged();

protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const override;

private:
    void refreshFilter();

    int m_pageIndex = 0;
    int m_pageSize = 1;
};
