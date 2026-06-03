#include "Installer.h"
#include "OemSetupController.h"

#include <QDebug>
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QPalette>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QQuickStyle>
#include <QUrl>

int main(int argc, char* argv[])
{
    // --install ajetaan ennen QGuiApplicationia, sudolla ei välttämättä ole näyttöä.
    for (int i = 1; i < argc; ++i) {
        if (qstrcmp(argv[i], "--install") == 0) {
            QCoreApplication app(argc, argv);
            QString setupUser = QStringLiteral("setup");
            for (int j = i + 1; j < argc; ++j) {
                const QString arg = QString::fromLocal8Bit(argv[j]);
                if (arg.startsWith(QStringLiteral("--setup-user=")))
                    setupUser = arg.mid(13);
            }
            return Installer::install(setupUser);
        }
    }

    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("OEM Setup"));
    QGuiApplication::setOrganizationName(QStringLiteral("fi.local"));

    QQuickStyle::setStyle(QStringLiteral("Fusion"));

    // Pakotetaan vaalea paletti. Setup-käyttäjän teema ei kerro oikeasta käyttäjästä.
    // TODO: vaihda palettipohjaisiin QML-väreihin kun tumma teema joskus tehdään.
    QPalette palette;
    palette.setColor(QPalette::Window,          QColor{0xf7, 0xf4, 0xef});
    palette.setColor(QPalette::WindowText,      QColor{0x26, 0x32, 0x38});
    palette.setColor(QPalette::Base,            QColor{0xff, 0xff, 0xff});
    palette.setColor(QPalette::AlternateBase,   QColor{0xf1, 0xf4, 0xf2});
    palette.setColor(QPalette::Text,            QColor{0x26, 0x32, 0x38});
    palette.setColor(QPalette::PlaceholderText, QColor{0x94, 0xa3, 0xa8});
    palette.setColor(QPalette::Button,          QColor{0xe8, 0xed, 0xf0});
    palette.setColor(QPalette::ButtonText,      QColor{0x26, 0x32, 0x38});
    palette.setColor(QPalette::Highlight,       QColor{0x3d, 0x7a, 0x5f});
    palette.setColor(QPalette::HighlightedText, QColor{0xff, 0xff, 0xff});
    palette.setColor(QPalette::Mid,             QColor{0xda, 0xd6, 0xce});
    palette.setColor(QPalette::Dark,            QColor{0xc8, 0xd0, 0xcd});
    app.setPalette(palette);

    OemSetupController controller;
    controller.setMockMode(QCoreApplication::arguments().contains(QStringLiteral("--mock")));

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("oemSetup"), &controller);
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { qCritical() << "Failed to load OEM setup QML."; },
        Qt::DirectConnection);
    QObject::connect(&engine, &QQmlApplicationEngine::warnings, &app, [](const QList<QQmlError>& warnings) {
        for (const QQmlError& warning : warnings) {
            qWarning().noquote() << warning.toString();
        }
    });
    // Ajetaan qsTr()-bindingit uusiksi kun UI-kieli vaihtuu.
    QObject::connect(&controller, &OemSetupController::uiLanguageChanged,
                     &engine,     &QQmlApplicationEngine::retranslate);

    // Qt 6.4 AppImagessa QML ei aina ole QRC:ssä, joten lisätään usr/qml varalle.
    engine.addImportPath(QDir::cleanPath(
        QCoreApplication::applicationDirPath() + "/../qml"));

    // QRC ensin jos löytyy, muuten tiedostojärjestelmän QML-moduuli.
    const QString qrcRelPath = QStringLiteral("/qt/qml/OemSetup/qml/Main.qml");
    const QUrl mainUrl = QFile::exists(QLatin1Char(':') + qrcRelPath)
        ? QUrl(QStringLiteral("qrc") + qrcRelPath)
        : QUrl::fromLocalFile(QDir::cleanPath(
              QCoreApplication::applicationDirPath()
              + "/../qml/OemSetup/qml/Main.qml"));
    engine.load(mainUrl);

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "OEM setup QML produced no root objects.";
        return 1;
    }

    return app.exec();
}
