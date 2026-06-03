#include "OemSetupController.h"

#include "Validation.h"

#include <QCoreApplication>
#include <QFile>
#include <QIODevice>
#include <QMap>
#include <QProcess>

OemSetupController::OemSetupController(QObject* parent)
    : QObject(parent)
{
}

QString OemSetupController::displayName() const { return m_displayName; }

void OemSetupController::setDisplayName(const QString& value)
{
    const QString trimmed = value.trimmed();
    if (m_displayName == trimmed)
        return;

    m_displayName = trimmed;
    emit displayNameChanged();

    if (!m_usernameManuallyEdited) {
        const QString derived = OemSetup::deriveUsername(m_displayName);
        if (derived != m_username) {
            m_username = derived;
            emit usernameChanged();
        }
    }
}

QString OemSetupController::username() const { return m_username; }

void OemSetupController::setUsername(const QString& raw)
{
    // Pidetään tunnus simppelinä: pienet kirjaimet, [a-z0-9_-], max 32 merkkiä.
    QString filtered;
    filtered.reserve(qMin(raw.size(), 32));
    for (const QChar c : raw.toLower()) {
        if (filtered.size() == 32) break;
        if ((c >= u'a' && c <= u'z') || (c >= u'0' && c <= u'9') || c == u'_' || c == u'-')
            filtered += c;
    }

    const bool wasManual = m_usernameManuallyEdited;
    m_usernameManuallyEdited = (filtered != OemSetup::deriveUsername(m_displayName));

    if (m_username == filtered && wasManual == m_usernameManuallyEdited)
        return;

    m_username = filtered;
    emit usernameChanged();
    if (wasManual != m_usernameManuallyEdited)
        emit usernameManuallyEditedChanged();
}

bool OemSetupController::usernameManuallyEdited() const { return m_usernameManuallyEdited; }

void OemSetupController::resetUsernameToAutomatic()
{
    if (!m_usernameManuallyEdited)
        return;

    const QString derived = OemSetup::deriveUsername(m_displayName);
    const bool nameChanged = (m_username != derived);

    m_username = derived;
    m_usernameManuallyEdited = false;

    if (nameChanged) emit usernameChanged();
    emit usernameManuallyEditedChanged();
}

QString OemSetupController::locale() const { return m_locale; }

void OemSetupController::setLocale(const QString& value)
{
    if (m_locale == value) {
        return;
    }
    m_locale = value;
    emit localeChanged();
}

QString OemSetupController::localeLabel() const
{
    static const QMap<QString, QString> labels = {
        {QStringLiteral("fi_FI.UTF-8"), QStringLiteral("Suomi")},
        {QStringLiteral("sv_SE.UTF-8"), QStringLiteral("Svenska")},
        {QStringLiteral("en_GB.UTF-8"), QStringLiteral("English (UK)")},
        {QStringLiteral("en_US.UTF-8"), QStringLiteral("English (US)")},
    };
    return labels.value(m_locale, m_locale);
}

QString OemSetupController::password() const { return m_password; }

void OemSetupController::setPassword(const QString& value)
{
    if (m_password == value) {
        return;
    }
    m_password = value;
    emit passwordChanged();
}

QString OemSetupController::passwordConfirmation() const { return m_passwordConfirmation; }

void OemSetupController::setPasswordConfirmation(const QString& value)
{
    if (m_passwordConfirmation == value) {
        return;
    }
    m_passwordConfirmation = value;
    emit passwordConfirmationChanged();
}

QString OemSetupController::errorTitle() const { return m_errorTitle; }
QString OemSetupController::errorMessage() const { return m_errorMessage; }
bool OemSetupController::busy() const { return m_busy; }
bool OemSetupController::mockMode() const { return m_mockMode; }

void OemSetupController::setMockMode(bool value)
{
    if (m_mockMode == value) {
        return;
    }
    m_mockMode = value;
    emit mockModeChanged();
}

bool OemSetupController::validateNamePage()
{
    const auto nameResult = OemSetup::validateDisplayName(m_displayName);
    if (!nameResult.ok) {
        setError(tr("Tarkista nimi"), nameResult.message);
        return false;
    }

    const auto usernameResult = OemSetup::validateUsername(m_username);
    if (!usernameResult.ok) {
        setError(tr("Tunnusta ei voi muodostaa"), usernameResult.message);
        return false;
    }

    clearError();
    return true;
}

bool OemSetupController::validateLanguagePage()
{
    const auto localeResult = OemSetup::validateLocale(m_locale);
    if (!localeResult.ok) {
        setError(tr("Tarkista kieli"), localeResult.message);
        return false;
    }
    clearError();
    return true;
}

bool OemSetupController::validatePasswordPage()
{
    if (m_password.isEmpty()) {
        setError(tr("Kirjoita salasana"), tr("Salasana voi olla lyhyt, mutta se ei voi olla tyhjä."));
        return false;
    }

    if (m_password != m_passwordConfirmation) {
        setError(tr("Salasanat eivät täsmää"), tr("Kirjoita sama salasana molempiin kenttiin."));
        return false;
    }

    clearError();
    return true;
}

bool OemSetupController::validateAll()
{
    return validateNamePage() && validateLanguagePage() && validatePasswordPage();
}

bool OemSetupController::apply()
{
    if (m_busy) {
        return false;
    }

    if (!validateAll()) {
        return false;
    }

    setBusy(true);

    if (m_mockMode) {
        QTimer::singleShot(1400, this, [this]() {
            setBusy(false);
            clearError();
            emit applySucceeded();
        });
        return true;
    }

    m_helperProcess = new QProcess(this);

    connect(m_helperProcess, &QProcess::finished, this,
            [this](int exitCode, QProcess::ExitStatus exitStatus) {
        const QString stderrOutput = QString::fromUtf8(
            m_helperProcess->readAllStandardError()).trimmed();

        m_helperProcess->deleteLater();
        m_helperProcess = nullptr;

        setBusy(false);

        if (exitStatus == QProcess::NormalExit && exitCode == 0) {
            m_password.clear();   // tyhjennetään vasta onnistumisella, retry tarvitsee tämän
            emit passwordChanged();
            clearError();
            emit applySucceeded();
        } else {
            setError(tr("Käyttöönotto epäonnistui"),
                     stderrOutput.isEmpty()
                         ? tr("Tilin luominen ei onnistunut. "
                              "Tarkista, että sinulla on riittävät oikeudet.")
                         : stderrOutput);
            emit applyRuntimeFailed();
        }
    });

    m_helperProcess->start(QStringLiteral("pkexec"), {
        QStringLiteral("/usr/libexec/oem-setup/oem-apply.sh"),
        QStringLiteral("--username"),     m_username,
        QStringLiteral("--display-name"), m_displayName,
        QStringLiteral("--locale"),       m_locale,
    });

    if (!m_helperProcess->waitForStarted(5000)) {
        m_helperProcess->deleteLater();
        m_helperProcess = nullptr;
        setBusy(false);
        setError(tr("Käyttöönotto epäonnistui"),
                 tr("Helper-prosessin käynnistys epäonnistui."));
        QTimer::singleShot(0, this, [this]() { emit applyRuntimeFailed(); });
        return true;
    }

    // Salasana stdinistä, ei argv:hen.
    m_helperProcess->write((m_password + u'\n').toUtf8());
    m_helperProcess->closeWriteChannel();
    return true;
}

QString OemSetupController::uiLanguage() const { return m_uiLanguage; }

void OemSetupController::setUiLanguage(const QString& lang)
{
    if (m_uiLanguage == lang)
        return;

    QCoreApplication::removeTranslator(&m_translator);

    if (lang != QLatin1String("fi")) {
        const QString path = QStringLiteral(":/i18n/oem-setup_") + lang + QStringLiteral(".qm");
        if (!m_translator.load(path)) {
            return; // käännöstä ei ole, pidetään nykyinen kieli
        }
        QCoreApplication::installTranslator(&m_translator);
    }

    m_uiLanguage = lang;
    emit uiLanguageChanged();
}

void OemSetupController::reboot()
{
    if (m_mockMode) {
        QCoreApplication::quit();
        return;
    }
    { QFile f(QStringLiteral("/tmp/oem-setup-done")); (void)f.open(QIODevice::WriteOnly); }
    QProcess::startDetached(QStringLiteral("systemctl"), {QStringLiteral("reboot")});
    QCoreApplication::quit();
}

void OemSetupController::clearError()
{
    if (m_errorTitle.isEmpty() && m_errorMessage.isEmpty()) {
        return;
    }
    m_errorTitle.clear();
    m_errorMessage.clear();
    emit errorChanged();
}

void OemSetupController::setError(const QString& title, const QString& message)
{
    m_errorTitle = title;
    m_errorMessage = message;
    emit errorChanged();
}

void OemSetupController::setBusy(bool value)
{
    if (m_busy == value) {
        return;
    }
    m_busy = value;
    emit busyChanged();
}
