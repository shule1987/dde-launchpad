// SPDX-FileCopyrightText: 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

#include "pagesliceproxymodel.h"

PageSliceProxyModel::PageSliceProxyModel(QObject *parent)
    : QSortFilterProxyModel(parent)
{
    setDynamicSortFilter(true);

    connect(this, &QAbstractItemModel::rowsInserted, this, &PageSliceProxyModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &PageSliceProxyModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &PageSliceProxyModel::countChanged);
}

void PageSliceProxyModel::setSourceModel(QAbstractItemModel *model)
{
    if (model == sourceModel()) {
        return;
    }

    QSortFilterProxyModel::setSourceModel(model);
    emit sourceModelChanged(model);
    emit countChanged();
}

int PageSliceProxyModel::pageIndex() const
{
    return m_pageIndex;
}

void PageSliceProxyModel::setPageIndex(int pageIndex)
{
    const int normalizedPageIndex = qMax(0, pageIndex);
    if (normalizedPageIndex == m_pageIndex) {
        return;
    }

    m_pageIndex = normalizedPageIndex;
    emit pageIndexChanged();
    refreshFilter();
}

int PageSliceProxyModel::pageSize() const
{
    return m_pageSize;
}

void PageSliceProxyModel::setPageSize(int pageSize)
{
    const int normalizedPageSize = qMax(1, pageSize);
    if (normalizedPageSize == m_pageSize) {
        return;
    }

    m_pageSize = normalizedPageSize;
    emit pageSizeChanged();
    refreshFilter();
}

int PageSliceProxyModel::count() const
{
    return rowCount();
}

bool PageSliceProxyModel::filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const
{
    if (sourceParent.isValid()) {
        return false;
    }

    const int firstRow = m_pageIndex * m_pageSize;
    return sourceRow >= firstRow && sourceRow < firstRow + m_pageSize;
}

void PageSliceProxyModel::refreshFilter()
{
    invalidateFilter();
    emit countChanged();
}
