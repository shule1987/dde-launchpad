// SPDX-FileCopyrightText: 2023 - 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QtQml/qqml.h>

#include <QVariant>
#include "itemspage.h"
#include "appsmodel.h"

#include <QConcatenateTablesProxyModel>

class ItemArrangementProxyModel : public QConcatenateTablesProxyModel
{
    Q_OBJECT
    QML_NAMED_ELEMENT(ItemArrangementProxyModel)
    QML_SINGLETON
public:
    enum ItemType{
        AppItemType = 0,
        FolderItemType = 1
    };
    Q_ENUM(ItemType)

    enum Roles {
        PageRole = AppsModel::ProxyModelExtendedRole,
        IndexInPageRole,
        FolderIdNumberRole,
        IconsNameRole,
        ItemTypeRole
    };
    Q_ENUM(Roles)

    enum DndOperation {
        DndPrepend = -1,
        DndJoin = 0,
        DndAppend = 1
    };
    Q_ENUM(DndOperation)

    static ItemArrangementProxyModel &instance()
    {
        static ItemArrangementProxyModel _instance;
        return _instance;
    }

    static ItemArrangementProxyModel *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine)
    {
        Q_UNUSED(qmlEngine)
        Q_UNUSED(jsEngine)
        return &instance();
    }

    ~ItemArrangementProxyModel();

    Q_INVOKABLE int pageCount(int folderId = 0) const;
    Q_INVOKABLE void updateFolderName(int folderId, const QString & name);
    Q_INVOKABLE void bringToFront(const QString & id);
    Q_INVOKABLE void commitDndOperation(const QString & dragId, const QString & dropId, const DndOperation op, int pageHint = -1);
    Q_INVOKABLE void previewDndOperation(const QString & dragId, const QString & dropId, const DndOperation op, int pageHint = -1);
    Q_INVOKABLE void persistArrangement();
    Q_INVOKABLE void cancelPreviewArrangement();
    Q_INVOKABLE int creatEmptyPage(int folderId = 0) const;
    Q_INVOKABLE void removeEmptyPage() const;
    Q_INVOKABLE QVariantList folderEntriesForItem(const QString &id) const;
    Q_INVOKABLE bool addItemToFolder(const QString &id, const QString &folderId);
    Q_INVOKABLE bool addItemToNewFolder(const QString &id);
    Q_INVOKABLE bool dissolveFolder(int folderId);

    ItemsPage *itemsPage() { return m_topLevel; }

    // QAbstractItemModel interface
public:
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

signals:
    void topLevelPageCountChanged();
    void folderPageCountChanged(int folderId);
    void folderRemoved(int folderId);
    void itemBroughtToFront();

private:
    struct PageSnapshot {
        QString folderId;
        QString name;
        QList<QStringList> pages;
    };

    explicit ItemArrangementProxyModel(QObject *parent = nullptr);

    void loadItemArrangementFromUserData();
    void saveItemArrangementToUserData();
    PageSnapshot snapshotPage(const QString &folderId, ItemsPage *page) const;
    void capturePreviewArrangement();
    void clearPreviewArrangement();
    void restorePage(ItemsPage *page, const PageSnapshot &snapshot);
    bool performDndOperation(const QString &dragId, const QString &dropId, const DndOperation op, int pageHint, bool persist);
    std::tuple<int, int, int> findItem(const QString & id, bool searchTopLevelOnly = false) const;
    void onSourceModelChanged();
    void onFolderModelChanged();

    QString findAvailableFolderId();
    QString defaultFolderNameForItem(const QString &id) const;
    ItemsPage * createFolder(const QString & id);
    void removeFolder(const QString & idNumber, bool removeTopLevelEmptyPage = true);
    ItemsPage * folderById(int id);
    QStringList allArrangedItems() const;

    // <folder-id, items-arrangement-data> folder-id: internal/folder/<id number>
    ItemsPage * m_topLevel;
    QHash<QString, ItemsPage *> m_folders;
    QStandardItemModel m_folderModel;
    bool m_arrangementDirty = false;
    bool m_hasPreviewArrangementSnapshot = false;
    PageSnapshot m_previewTopLevelSnapshot;
    QList<PageSnapshot> m_previewFolderSnapshots;
};
