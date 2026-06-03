#include "Validation.h"

#include <QTest>

class ValidationTest : public QObject {
    Q_OBJECT

private slots:
    // Käyttäjätunnuksen johtaminen
    void deriveUsername_finnishFirstName();
    void deriveUsername_fullNameUsesFirstWordOnly();
    void deriveUsername_finnishCharsTransliterated();
    void deriveUsername_stripsNonAscii();
    void deriveUsername_emptyInput();
    void deriveUsername_maxLength();

    // Näyttönimen validointi
    void validateDisplayName_valid();
    void validateDisplayName_emptyFails();
    void validateDisplayName_colonFails();
    void validateDisplayName_commaFails();
    void validateDisplayName_tooLongFails();
    void validateDisplayName_controlCharFails();
    void validateDisplayName_bidiOverrideFails();

    // Käyttäjätunnuksen validointi
    void validateUsername_valid();
    void validateUsername_startsWithDigitFails();
    void validateUsername_uppercaseFails();
    void validateUsername_tooLongFails();
    void validateUsername_maxLengthAllowed();
    void validateUsername_withHyphenAndUnderscore();

    // Localen validointi
    void validateLocale_knownLocalesAccepted();
    void validateLocale_unknownFails();
};

void ValidationTest::deriveUsername_finnishFirstName()
{
    QCOMPARE(OemSetup::deriveUsername(QStringLiteral("Matti")), QStringLiteral("matti"));
}

void ValidationTest::deriveUsername_fullNameUsesFirstWordOnly()
{
    QCOMPARE(OemSetup::deriveUsername(QStringLiteral("Matti Meikäläinen")), QStringLiteral("matti"));
}

void ValidationTest::deriveUsername_finnishCharsTransliterated()
{
    QCOMPARE(OemSetup::deriveUsername(QStringLiteral("Äiti")),  QStringLiteral("aiti"));
    QCOMPARE(OemSetup::deriveUsername(QStringLiteral("Öljy")),  QStringLiteral("oljy"));
    QCOMPARE(OemSetup::deriveUsername(QStringLiteral("Åland")), QStringLiteral("aland"));
}

void ValidationTest::deriveUsername_stripsNonAscii()
{
    // Pisteet ja muu sälä pois, numerot ja a-z jäävät.
    QCOMPARE(OemSetup::deriveUsername(QStringLiteral("user.name")), QStringLiteral("username"));
    // Numerot ovat käyttäjätunnuksessa ok.
    QCOMPARE(OemSetup::deriveUsername(QStringLiteral("123abc")), QStringLiteral("123abc"));
}

void ValidationTest::deriveUsername_emptyInput()
{
    QVERIFY(OemSetup::deriveUsername(QStringLiteral("")).isEmpty());
}

void ValidationTest::deriveUsername_maxLength()
{
    // Pitkä nimi katkaistaan 32 merkkiin.
    const QString longName(40, u'a');
    QCOMPARE(OemSetup::deriveUsername(longName).length(), 32);
}

void ValidationTest::validateDisplayName_valid()
{
    QVERIFY(OemSetup::validateDisplayName(QStringLiteral("Matti Meikäläinen")).ok);
    QVERIFY(OemSetup::validateDisplayName(QStringLiteral("Åke")).ok);
    QVERIFY(OemSetup::validateDisplayName(QStringLiteral("A")).ok);
}

void ValidationTest::validateDisplayName_emptyFails()
{
    QVERIFY(!OemSetup::validateDisplayName(QStringLiteral("")).ok);
    QVERIFY(!OemSetup::validateDisplayName(QStringLiteral("   ")).ok);
}

void ValidationTest::validateDisplayName_colonFails()
{
    QVERIFY(!OemSetup::validateDisplayName(QStringLiteral("user:name")).ok);
}

void ValidationTest::validateDisplayName_commaFails()
{
    QVERIFY(!OemSetup::validateDisplayName(QStringLiteral("Etu,Suku")).ok);
}

void ValidationTest::validateDisplayName_tooLongFails()
{
    QVERIFY(!OemSetup::validateDisplayName(QString(129, u'a')).ok);
    QVERIFY(OemSetup::validateDisplayName(QString(128, u'a')).ok);
}

void ValidationTest::validateDisplayName_controlCharFails()
{
    QVERIFY(!OemSetup::validateDisplayName(QStringLiteral("name\x01")).ok);
    // Lopun \n lähtee trimmedillä, keskellä se on se oikea ongelma.
    QVERIFY(!OemSetup::validateDisplayName(QStringLiteral("na\nme")).ok);
}

void ValidationTest::validateDisplayName_bidiOverrideFails()
{
    // U+202E on bidi-ohjausmerkki, eli pieni spoofausriski.
    const QString nameWithBidi = QStringLiteral("name") + QChar(0x202E);
    QVERIFY(!OemSetup::validateDisplayName(nameWithBidi).ok);
}

void ValidationTest::validateUsername_valid()
{
    QVERIFY(OemSetup::validateUsername(QStringLiteral("matti")).ok);
    QVERIFY(OemSetup::validateUsername(QStringLiteral("user1")).ok);
    QVERIFY(OemSetup::validateUsername(QStringLiteral("my-user")).ok);
    QVERIFY(OemSetup::validateUsername(QStringLiteral("my_user")).ok);
}

void ValidationTest::validateUsername_startsWithDigitFails()
{
    QVERIFY(!OemSetup::validateUsername(QStringLiteral("1user")).ok);
}

void ValidationTest::validateUsername_uppercaseFails()
{
    QVERIFY(!OemSetup::validateUsername(QStringLiteral("Matti")).ok);
}

void ValidationTest::validateUsername_tooLongFails()
{
    QVERIFY(!OemSetup::validateUsername(QString(33, u'a')).ok);
}

void ValidationTest::validateUsername_maxLengthAllowed()
{
    QVERIFY(OemSetup::validateUsername(QString(32, u'a')).ok);
}

void ValidationTest::validateUsername_withHyphenAndUnderscore()
{
    // Väliviiva ja alaviiva käyvät, mutta eivät ekaksi merkiksi.
    QVERIFY(OemSetup::validateUsername(QStringLiteral("a-b_c")).ok);
    QVERIFY(!OemSetup::validateUsername(QStringLiteral("-user")).ok);
    QVERIFY(!OemSetup::validateUsername(QStringLiteral("_user")).ok);
}

void ValidationTest::validateLocale_knownLocalesAccepted()
{
    QVERIFY(OemSetup::validateLocale(QStringLiteral("fi_FI.UTF-8")).ok);
    QVERIFY(OemSetup::validateLocale(QStringLiteral("sv_SE.UTF-8")).ok);
    QVERIFY(OemSetup::validateLocale(QStringLiteral("en_GB.UTF-8")).ok);
    QVERIFY(OemSetup::validateLocale(QStringLiteral("en_US.UTF-8")).ok);
}

void ValidationTest::validateLocale_unknownFails()
{
    QVERIFY(!OemSetup::validateLocale(QStringLiteral("xx_XX.UTF-8")).ok);
    QVERIFY(!OemSetup::validateLocale(QStringLiteral("fi_FI")).ok);
    QVERIFY(!OemSetup::validateLocale(QStringLiteral("")).ok);
}

QTEST_MAIN(ValidationTest)
#include "ValidationTest.moc"
