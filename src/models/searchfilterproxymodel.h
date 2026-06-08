// SPDX-FileCopyrightText: 2023 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QtQml/qqml.h>
#include <QHash>
#include <QSortFilterProxyModel>

namespace Dtk::Core {
class DConfig;
}

class SearchFilterProxyModel : public QSortFilterProxyModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(QString searchText READ searchText WRITE setSearchText NOTIFY searchTextChanged)
    QML_NAMED_ELEMENT(SearchFilterProxyModel)
    QML_SINGLETON
public:
    static SearchFilterProxyModel &instance()
    {
        static SearchFilterProxyModel _instance;
        return _instance;
    }

    static SearchFilterProxyModel *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine)
    {
        Q_UNUSED(qmlEngine)
        Q_UNUSED(jsEngine)
        return &instance();
    }

    int count() const;
    QString searchText() const;
    Q_INVOKABLE void setSearchText(const QString &searchText);

signals:
    void countChanged();
    void searchTextChanged();

    // QSortFilterProxyModel interface
protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const override;
    bool lessThan(const QModelIndex &source_left, const QModelIndex &source_right) const override;

private:
    explicit SearchFilterProxyModel(QObject *parent = nullptr);

    int calculateWeight(const QModelIndex &modelIndex) const;
    QString transliteratedLower(const QModelIndex &modelIndex, const QString &displayName) const;
    QString jianpinNormalizedLower(const QModelIndex &modelIndex, const QString &displayName) const;
    void clearWeightCache() const;
    void clearSearchCaches() const;
    void scheduleCountChanged();
    void scheduleSearchStatePublish();

    Dtk::Core::DConfig *m_dconfig;
    bool m_searchPackageEnabled;
    QString m_searchText;
    QString m_pendingSearchText;
    mutable QString m_cachedPattern;
    mutable QHash<int, int> m_weightCache;
    mutable QHash<int, QString> m_transliteratedCache;
    mutable QHash<int, QString> m_jianpinCache;
    bool m_searchFilterUpdateInProgress = false;
    bool m_searchStatePublishPending = false;
    bool m_countChangePending = false;
};
