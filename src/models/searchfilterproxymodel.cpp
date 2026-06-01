// SPDX-FileCopyrightText: 2023 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

#include "appsmodel.h"
#include "searchfilterproxymodel.h"

#include <QDebug>
#include <DPinyin>
#include <DConfig>
#include <QLoggingCategory>
#include <QTimer>

Q_DECLARE_LOGGING_CATEGORY(logModels)

DCORE_USE_NAMESPACE

namespace {

bool needsTransliteration(const QString &text)
{
    for (const QChar &ch : text) {
        if (ch.unicode() > 0x7f) {
            return true;
        }
    }

    return false;
}

bool wordStartsWith(const QString &text, const QString &pattern)
{
    const QStringList words = text.split(' ', Qt::SkipEmptyParts);
    for (const QString &word : words) {
        if (word.toLower().startsWith(pattern)) {
            return true;
        }
    }

    return false;
}

QString firstLettersForWords(const QString &text)
{
    const QStringList words = text.split(' ', Qt::SkipEmptyParts);
    QString letters;
    letters.reserve(words.size());

    for (const QString &word : words) {
        if (word.isEmpty()) {
            continue;
        }

        const QChar firstChar = word.at(0);
        if (firstChar.isLetter()) {
            letters += firstChar.toLower();
        }
    }

    return letters;
}

QString capitalizedWords(const QString &text)
{
    static const QRegularExpression capitalizedWordRegex("\\b[A-Z][A-Za-z0-9]*");
    QStringList words;

    auto matches = capitalizedWordRegex.globalMatch(text);
    while (matches.hasNext()) {
        words << matches.next().captured(0).toLower();
    }

    return words.join(' ');
}

} // namespace

SearchFilterProxyModel::SearchFilterProxyModel(QObject *parent)
    : QSortFilterProxyModel(parent)
    , m_dconfig(DConfig::create("org.deepin.dde.shell", "org.deepin.ds.launchpad"))
    , m_searchPackageEnabled(false)
{
    setFilterCaseSensitivity(Qt::CaseInsensitive);

    setSourceModel(&AppsModel::instance());
    sort(0, Qt::DescendingOrder);

    const auto refreshSearchState = [this]() {
        clearWeightCache();
        scheduleCountChanged();
    };
    connect(this, &QAbstractItemModel::rowsInserted, this, refreshSearchState);
    connect(this, &QAbstractItemModel::rowsRemoved, this, refreshSearchState);
    connect(this, &QAbstractItemModel::modelReset, this, refreshSearchState);
    connect(this, &QAbstractItemModel::layoutChanged, this, refreshSearchState);
    connect(&AppsModel::instance(), &QAbstractItemModel::dataChanged, this, [this]() {
        clearSearchCaches();
        scheduleCountChanged();
    });
    connect(&AppsModel::instance(), &QAbstractItemModel::rowsInserted, this, [this]() {
        clearSearchCaches();
    });
    connect(&AppsModel::instance(), &QAbstractItemModel::rowsRemoved, this, [this]() {
        clearSearchCaches();
    });
    connect(&AppsModel::instance(), &AppsModel::temporaryHiddenAppsChanged, this, [this]() {
        clearSearchCaches();
        invalidateFilter();
        scheduleCountChanged();
    });

    Q_ASSERT_X(m_dconfig->isValid(), "DConfig", "DConfig file is missing or invalid");

    m_searchPackageEnabled = m_dconfig->value("searchByDesktopId", false).toBool();
    QObject::connect(m_dconfig, &DConfig::valueChanged, this, [this](const QString &key) {
        if (key == "searchByDesktopId") {
            m_searchPackageEnabled = m_dconfig->value("searchByDesktopId", false).toBool();
            qCInfo(logModels) << "searchByDesktopId config updated:" << m_searchPackageEnabled;
            // 触发重新过滤以应用新的搜索配置
            clearWeightCache();
            invalidateFilter();
            scheduleCountChanged();
        }
    });
}

int SearchFilterProxyModel::count() const
{
    return rowCount();
}

bool SearchFilterProxyModel::filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const
{
    QModelIndex modelIndex = this->sourceModel()->index(sourceRow, 0, sourceParent);
    if (!modelIndex.isValid()) {
        qCWarning(logModels) << "Invalid model index for row" << sourceRow;
        return false;
    }
    const QRegularExpression searchPattern = this->filterRegularExpression();
    if (modelIndex.data(AppsModel::TemporarilyHiddenRole).toBool()) {
        return false;
    }

    // 计算匹配索引
    int matchIndex = calculateWeight(modelIndex);

    return matchIndex >= 0;
}

bool SearchFilterProxyModel::lessThan(const QModelIndex &source_left, const QModelIndex &source_right) const
{
    int leftIndex = calculateWeight(source_left);
    int rightIndex = calculateWeight(source_right);

    if (leftIndex != rightIndex) {
        // 索引值越小优先级越高，在降序排序中应该排在前面
        return leftIndex > rightIndex; // 索引小的返回false（排在前面）
    }

    // 索引相同时，按启动次数排序：高频使用 > 低频使用
    int leftLaunchedTimes = source_left.data(AppItem::LaunchedTimesRole).toInt();
    int rightLaunchedTimes = source_right.data(AppItem::LaunchedTimesRole).toInt();

    if (leftLaunchedTimes != rightLaunchedTimes) {
        bool result = leftLaunchedTimes < rightLaunchedTimes;
        return result;
    }

    // 索引和启动次数都相同时，按照原有的排序规则
    return QSortFilterProxyModel::lessThan(source_left, source_right);
}

int SearchFilterProxyModel::calculateWeight(const QModelIndex &modelIndex) const
{
    const QRegularExpression searchPattern = this->filterRegularExpression();
    if (searchPattern.pattern().isEmpty()) {
        return 0;
    }

    const QString pattern = searchPattern.pattern();
    if (pattern != m_cachedPattern) {
        m_cachedPattern = pattern;
        m_weightCache.clear();
    }

    const int cacheKey = modelIndex.row();
    auto cachedWeight = m_weightCache.constFind(cacheKey);
    if (cachedWeight != m_weightCache.constEnd()) {
        return *cachedWeight;
    }

    const QString displayName = modelIndex.data(Qt::DisplayRole).toString();
    const QString name = modelIndex.data(AppsModel::NameRole).toString();
    const QString vendor = modelIndex.data(AppItem::VendorRole).toString();
    const QString genericName = modelIndex.data(AppItem::GenericNameRole).toString();
    const QString targetName = vendor == "deepin" && !genericName.isEmpty() ? genericName : name;

    const QString searchPatternLower = QString(pattern).toLower().remove(' ');
    const QString displayNameLower = QString(displayName).toLower().remove(' ');
    const QString targetNameLower = QString(targetName).toLower().remove(' ');
    const QString nameFirstLettersLower = firstLettersForWords(targetName);

    static const QRegularExpression searchEnglishCheck("^[a-zA-Z0-9\\s\\-\\.]+$");
    static const QRegularExpression startsWithEnglishCheck("^[a-zA-Z][a-zA-Z0-9]*");
    const bool isEnglishSearch = searchEnglishCheck.match(pattern).hasMatch();
    const bool displayNameStarts = displayNameLower.startsWith(searchPatternLower);
    const bool displayNameStartsWithEnglish = startsWithEnglishCheck.match(displayName).hasMatch();

    auto cacheAndReturn = [this, cacheKey](int weight) {
        m_weightCache.insert(cacheKey, weight);
        return weight;
    };

    if (displayNameLower == searchPatternLower) {
        return cacheAndReturn(0);
    }

    if (targetNameLower == searchPatternLower) {
        return cacheAndReturn(1);
    }

    const QString transliterated = transliteratedLower(modelIndex, displayName);
    if (transliterated.startsWith(searchPatternLower)) {
        return cacheAndReturn(2);
    }

    const QString jianpin = jianpinNormalizedLower(modelIndex, displayName);
    if (jianpin == searchPatternLower) {
        return cacheAndReturn(3);
    }

    if (jianpin.startsWith(searchPatternLower)) {
        return cacheAndReturn(4);
    }

    if (displayNameStarts && !displayNameStartsWithEnglish) {
        return cacheAndReturn(5);
    }

    if (displayNameStarts && displayNameStartsWithEnglish) {
        return cacheAndReturn(6);
    }

    const bool displayWordStarts = displayNameLower.contains(searchPatternLower)
            && wordStartsWith(displayName, searchPatternLower);
    if (displayWordStarts) {
        return cacheAndReturn(7);
    }

    if (nameFirstLettersLower.startsWith(searchPatternLower)) {
        return cacheAndReturn(8);
    }

    if (targetNameLower.startsWith(searchPatternLower)) {
        return cacheAndReturn(9);
    }

    if (targetNameLower.contains(searchPatternLower)
            && wordStartsWith(targetName, searchPatternLower)) {
        return cacheAndReturn(10);
    }

    if (displayNameLower.contains(searchPatternLower) && !displayWordStarts) {
        return cacheAndReturn(11);
    }

    if (transliterated.contains(searchPatternLower)
            && wordStartsWith(transliterated, searchPatternLower)) {
        return cacheAndReturn(12);
    }

    if (targetNameLower.contains(searchPatternLower)) {
        return cacheAndReturn(13);
    }

    if (transliterated.contains(searchPatternLower)) {
        return cacheAndReturn(14);
    }

    if (nameFirstLettersLower.contains(searchPatternLower)) {
        return cacheAndReturn(15);
    }

    if (jianpin.contains(searchPatternLower)) {
        return cacheAndReturn(16);
    }

    if (isEnglishSearch) {
        const QString capitalized = capitalizedWords(targetName);
        if (capitalized.startsWith(searchPatternLower)) {
            return cacheAndReturn(17);
        }

        if (capitalized.contains(searchPatternLower)) {
            return cacheAndReturn(18);
        }
    }

    if (m_searchPackageEnabled) {
        const QString desktopIdLower = modelIndex.data(AppItem::DesktopIdRole).toString().toLower().remove(' ');
        if (desktopIdLower.contains(searchPatternLower)) {
            return cacheAndReturn(19);
        }
    }

    return cacheAndReturn(-1);
}

QString SearchFilterProxyModel::transliteratedLower(const QModelIndex &modelIndex, const QString &displayName) const
{
    if (!needsTransliteration(displayName)) {
        return QString();
    }

    const int cacheKey = modelIndex.row();
    auto cachedValue = m_transliteratedCache.constFind(cacheKey);
    if (cachedValue != m_transliteratedCache.constEnd()) {
        return *cachedValue;
    }

    const QString value = modelIndex.data(AppsModel::AllTransliteratedRole).toString().toLower();
    m_transliteratedCache.insert(cacheKey, value);
    return value;
}

QString SearchFilterProxyModel::jianpinNormalizedLower(const QModelIndex &modelIndex, const QString &displayName) const
{
    if (!needsTransliteration(displayName)) {
        return QString();
    }

    const int cacheKey = modelIndex.row();
    auto cachedValue = m_jianpinCache.constFind(cacheKey);
    if (cachedValue != m_jianpinCache.constEnd()) {
        return *cachedValue;
    }

    const QString value = Dtk::Core::firstLetters(displayName, TS_NoneTone).join(',').toLower().remove(',').remove(' ');
    m_jianpinCache.insert(cacheKey, value);
    return value;
}

void SearchFilterProxyModel::clearWeightCache() const
{
    m_cachedPattern.clear();
    m_weightCache.clear();
}

void SearchFilterProxyModel::clearSearchCaches() const
{
    clearWeightCache();
    m_transliteratedCache.clear();
    m_jianpinCache.clear();
}

void SearchFilterProxyModel::scheduleCountChanged()
{
    if (m_countChangePending) {
        return;
    }

    m_countChangePending = true;
    QTimer::singleShot(0, this, [this]() {
        m_countChangePending = false;
        emit countChanged();
    });
}
