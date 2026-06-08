// SPDX-FileCopyrightText: 2023 - 2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later
#include "inputeventitem.h"
#include "launchercontroller.h"
#include <QGuiApplication>
#include <QInputMethod>
#include <QKeyEvent>
#include <QLoggingCategory>
#include <QMouseEvent>
#include <QQuickItem>
#include <QQuickWindow>
#include <QWheelEvent>
#include <QtGui/qguiapplication_platform.h>

#include <xcb/xcb.h>

namespace {
Q_LOGGING_CATEGORY(logInputEvent, "org.deepin.dde.launchpad.input")

bool isItemAncestorOf(QQuickItem *ancestor, QQuickItem *item)
{
    for (auto *current = item; current; current = current->parentItem()) {
        if (current == ancestor)
            return true;
    }
    return false;
}

bool isEditableTextItem(QQuickItem *item)
{
    if (!item || !item->isVisible() || !item->isEnabled())
        return false;

    const QVariant text = item->property("text");
    const QVariant cursorPosition = item->property("cursorPosition");
    if (!text.isValid() || !cursorPosition.isValid())
        return false;

    const QVariant readOnly = item->property("readOnly");
    return !readOnly.isValid() || !readOnly.toBool();
}

bool isEffectivelyVisible(QQuickItem *item)
{
    for (auto *current = item; current; current = current->parentItem()) {
        if (!current->isVisible() || !current->isEnabled())
            return false;
    }
    return true;
}

QQuickWindow *quickWindowForEventObject(QObject *obj)
{
    if (auto *targetWindow = qobject_cast<QQuickWindow *>(obj))
        return targetWindow;

    if (auto *targetItem = qobject_cast<QQuickItem *>(obj))
        return targetItem->window();

    return nullptr;
}
}

InputEventItem::InputEventItem()
{
    qApp->installEventFilter(this);
    setAcceptedMouseButtons(Qt::AllButtons);
    setFiltersChildMouseEvents(true);
}

QQuickItem* InputEventItem::inputMethodSource() const
{
    return m_inputMethodSource;
}

void InputEventItem::setInputMethodSource(QQuickItem* source)
{
    if (m_inputMethodSource != source) {
        m_inputMethodSource = source;
        Q_EMIT inputMethodSourceChanged();
    }
}

bool InputEventItem::wheelEventForwardingEnabled() const
{
    return m_wheelEventForwardingEnabled;
}

void InputEventItem::setWheelEventForwardingEnabled(bool enabled)
{
    if (m_wheelEventForwardingEnabled == enabled)
        return;

    m_wheelEventForwardingEnabled = enabled;
    Q_EMIT wheelEventForwardingEnabledChanged();
}

void InputEventItem::activateWindowForInput()
{
    if (!window())
        return;

    window()->create();
    const auto windowId = static_cast<xcb_window_t>(window()->winId());
    if (windowId == XCB_WINDOW_NONE)
        return;

    auto *x11App = qGuiApp->nativeInterface<QNativeInterface::QX11Application>();
    if (!x11App || !x11App->connection())
        return;

    xcb_set_input_focus(x11App->connection(), XCB_INPUT_FOCUS_PARENT, windowId, XCB_CURRENT_TIME);
    xcb_flush(x11App->connection());
}

void InputEventItem::releaseWindowInput()
{
}

QVariant InputEventItem::inputMethodQuery(Qt::InputMethodQuery query) const
{
    if (m_inputMethodSource) {
        if (query == Qt::ImCursorRectangle) {
            QVariant result = m_inputMethodSource->inputMethodQuery(query);
            QRectF rect = result.toRectF();
            QPointF mapped = m_inputMethodSource->mapToItem(this, rect.topLeft());
            rect.moveTopLeft(mapped);
            return rect;
        }
    }
    return QQuickItem::inputMethodQuery(query);
}

bool InputEventItem::eventFilter(QObject *obj, QEvent *event) {
    if (event->type() == QEvent::Wheel && m_wheelEventForwardingEnabled && window()) {
        auto *targetWindow = quickWindowForEventObject(obj);
        if (targetWindow == window() && targetWindow->isVisible() && isEffectivelyVisible(this)) {
            auto *wheelEvent = static_cast<QWheelEvent *>(event);
            Q_EMIT wheelReceived(wheelEvent->position(),
                                 wheelEvent->pixelDelta(),
                                 wheelEvent->angleDelta(),
                                 int(wheelEvent->modifiers()));
            return true;
        }
    }

    if (event->type() == QEvent::KeyPress && m_inputMethodSource && window()) {
        auto *targetWindow = qobject_cast<QQuickWindow *>(obj);
        if (!targetWindow) {
            if (auto *targetItem = qobject_cast<QQuickItem *>(obj))
                targetWindow = targetItem->window();
        }

        if (targetWindow == window() && !m_inputMethodSource->hasActiveFocus() && !hasEditableFocus()) {
            auto *keyEvent = static_cast<QKeyEvent *>(event);
            const bool commandModifier = keyEvent->modifiers().testFlag(Qt::ControlModifier)
                || keyEvent->modifiers().testFlag(Qt::AltModifier)
                || keyEvent->modifiers().testFlag(Qt::MetaModifier);
            if (!commandModifier && keyEvent->text().size() == 1 && keyEvent->text().at(0).isPrint()) {
                m_inputMethodSource->forceActiveFocus(Qt::TabFocusReason);
                const QString currentText = m_inputMethodSource->property("text").toString();
                m_inputMethodSource->setProperty("text", currentText + keyEvent->text());
                return true;
            }
        }
    }

    if (event->type() == QEvent::InputMethod && (this->children().contains(obj) || obj == this)) {
        if (m_inputMethodSource && window()) {
            auto *focusItem = window()->activeFocusItem();
            if (focusItem == m_inputMethodSource || isItemAncestorOf(m_inputMethodSource, focusItem))
                return QObject::eventFilter(obj, event);
        }

        if (hasEditableFocus())
            return QObject::eventFilter(obj, event);

        QInputMethodEvent *inputMethodEvent = static_cast<QInputMethodEvent *>(event);
        qCDebug(logInputEvent) << "Input method event received:" << inputMethodEvent->commitString();
        if (!inputMethodEvent->commitString().isEmpty()) {
            qCInfo(logInputEvent) << "Emitting input received signal:" << inputMethodEvent->commitString();
            Q_EMIT inputReceived(inputMethodEvent->commitString());
        }
    }
    return QObject::eventFilter(obj, event);
}

void InputEventItem::mousePressEvent(QMouseEvent *event)
{
    if (handleMouseEvent(event->type(), event->position(), event->button(), event->modifiers()))
        return;

    QQuickItem::mousePressEvent(event);
}

bool InputEventItem::childMouseEventFilter(QQuickItem *item, QEvent *event)
{
    if (event->type() != QEvent::MouseButtonPress
            && event->type() != QEvent::MouseButtonRelease
            && event->type() != QEvent::MouseButtonDblClick) {
        return QQuickItem::childMouseEventFilter(item, event);
    }

    auto *mouseEvent = static_cast<QMouseEvent *>(event);
    const QPointF position = item
        ? item->mapToItem(this, mouseEvent->position())
        : mouseEvent->position();

    return handleMouseEvent(event->type(), position, mouseEvent->button(), mouseEvent->modifiers());
}

bool InputEventItem::handleMouseEvent(QEvent::Type type, const QPointF &position, Qt::MouseButton button, Qt::KeyboardModifiers modifiers)
{
    if (m_inputMethodSource) {
        const QRectF inputRect(m_inputMethodSource->mapToItem(this, QPointF(0, 0)),
                               QSizeF(m_inputMethodSource->width(), m_inputMethodSource->height()));
        if (inputRect.contains(position)) {
            if (type == QEvent::MouseButtonPress || type == QEvent::MouseButtonDblClick) {
                LauncherController::instance().suppressNextHideForInputFocus();
                m_inputMethodSource->forceActiveFocus(Qt::MouseFocusReason);
                QGuiApplication::inputMethod()->show();
            }
            return false;
        }
    }

    if (type == QEvent::MouseButtonPress) {
        Q_EMIT pointerPressed(position, int(button), int(modifiers));
    } else if (type == QEvent::MouseButtonRelease) {
        Q_EMIT pointerReleased(position, int(button), int(modifiers));
    }
    return false;
}

bool InputEventItem::hasEditableFocus() const
{
    if (!window())
        return false;

    QQuickItem *focusItem = window()->activeFocusItem();
    if (!focusItem)
        return false;

    if (focusItem == this || focusItem == m_inputMethodSource || isItemAncestorOf(m_inputMethodSource, focusItem))
        return false;

    return isEditableTextItem(focusItem);
}
