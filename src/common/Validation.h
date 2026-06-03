#pragma once

#include <QString>

namespace OemSetup {

struct ValidationResult {
    bool ok = false;
    QString message;
};

QString deriveUsername(const QString& displayName);
ValidationResult validateDisplayName(const QString& displayName);
ValidationResult validateUsername(const QString& username);
ValidationResult validateLocale(const QString& locale);

}
