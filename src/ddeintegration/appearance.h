// SPDX-FileCopyrightText: 2023 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QObject>
#include <QtConcurrent>
class QUrl;
class __Appearance1;
class Appearance : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString wallpaperUrl READ wallpaperUrl NOTIFY wallpaperUrlChanged)
    Q_PROPERTY(QString wallpaperBlurhash READ wallpaperBlurhash NOTIFY wallpaperBlurhashChanged)
    Q_PROPERTY(qreal opacity READ opacity NOTIFY opacityChanged FINAL)

public:
    explicit Appearance(QObject *parent = nullptr);
    ~Appearance();

    QString wallpaperBlurhash() const;
    QString wallpaperUrl() const;

    qreal opacity() const;
    void setOpacity(qreal newOpacity);

    double scaleFactor() const;

signals:
    void wallpaperBlurhashChanged();
    void wallpaperUrlChanged();

    void opacityChanged();

private:
    void updateCurrentWallpaperBlurhash();
    void updateAllWallpaper();

    __Appearance1 * m_dbusAppearanceIface;

    QString m_wallpaperBlurhash;
    QString m_wallpaperUrl;
    QList<QFutureWatcher<QString> *> m_blurhashWatchers;
    QMap<QUrl, QString> m_wallpaperBlurMap; // { file:blurhash }
    qreal m_opacity = -1;

};
