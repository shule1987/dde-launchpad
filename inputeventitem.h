// SPDX-FileCopyrightText: 2023 - 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later
#ifndef INPUTEVENTITEM_H
#define INPUTEVENTITEM_H

#include <QObject>
#include <QQmlEngine>
#include <QQuickItem>

class QMouseEvent;

class InputEventItem : public QQuickItem
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QQuickItem* inputMethodSource READ inputMethodSource WRITE setInputMethodSource NOTIFY inputMethodSourceChanged)
public:
    InputEventItem();

    QQuickItem* inputMethodSource() const;
    void setInputMethodSource(QQuickItem* source);

    Q_INVOKABLE void activateWindowForInput();
    Q_INVOKABLE void releaseWindowInput();

    QVariant inputMethodQuery(Qt::InputMethodQuery query) const override;

protected:
    bool eventFilter(QObject *obj, QEvent *event) override;
    void mousePressEvent(QMouseEvent *event) override;
    bool childMouseEventFilter(QQuickItem *item, QEvent *event) override;

signals:
    void inputReceived(const QString &input);
    void inputMethodSourceChanged();
    void pointerPressed(const QPointF &position, int button, int modifiers);
    void pointerReleased(const QPointF &position, int button, int modifiers);

private:
    bool handleMouseEvent(QEvent::Type type, const QPointF &position, Qt::MouseButton button, Qt::KeyboardModifiers modifiers);
    QQuickItem* m_inputMethodSource = nullptr;
};

#endif // INPUTEVENTITEM_H
