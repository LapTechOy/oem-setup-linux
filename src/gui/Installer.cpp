#include "Installer.h"

#include "Validation.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QTextStream>

namespace {

static int fail(const QString& msg)
{
    QTextStream(stderr) << "oem-setup --install: " << msg << Qt::endl;
    return 1;
}

static QString appBaseDir()
{
    // AppImagessa ja CMake-installissa binääri on prefix/bin:n alla.
    // Yksi ".." vie takaisin samaan prefiksiin.
    return QCoreApplication::applicationDirPath() + "/..";
}

static bool copyFile(const QString& src, const QString& dst, QFile::Permissions perms)
{
    if (!QFile::exists(src))
        return fail("source not found: " + src) == 0; // palauttaa false

    QDir().mkpath(QFileInfo(dst).absolutePath());
    QFile::remove(dst);

    if (!QFile::copy(src, dst)) {
        fail("cannot copy " + src + " -> " + dst);
        return false;
    }
    if (!QFile::setPermissions(dst, perms)) {
        fail("cannot set permissions on " + dst);
        return false;
    }
    return true;
}

static bool writeFile(const QString& dst, const QString& content, QFile::Permissions perms)
{
    QDir().mkpath(QFileInfo(dst).absolutePath());
    QFile f(dst);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text)) {
        fail("cannot write " + dst);
        return false;
    }
    QTextStream(&f) << content;
    f.close();
    if (!QFile::setPermissions(dst, perms)) {
        fail("cannot set permissions on " + dst);
        return false;
    }
    return true;
}

}

namespace Installer {


int install(const QString& setupUser)
{
    if (::getuid() != 0)
        return fail("täytyy ajaa rootina (sudo)");

    if (!OemSetup::validateUsername(setupUser).ok)
        return fail("virheellinen setup-käyttäjänimi: " + setupUser);

    if (!QDir("/home/" + setupUser).exists())
        return fail("kotihakemistoa ei löydy: /home/" + setupUser);

    const QString base = appBaseDir();

    // GUI-binääri, eli tämä sama ohjelma.
    const QString appImagePath = QString::fromLocal8Bit(qgetenv("APPIMAGE"));
    const QString selfPath = appImagePath.isEmpty()
        ? QCoreApplication::applicationFilePath()
        : appImagePath;
    constexpr auto execPerms =
        QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner |
        QFile::ReadGroup | QFile::ExeGroup |
        QFile::ReadOther | QFile::ExeOther;
    if (!copyFile(selfPath, "/usr/bin/oem-setup-gui", execPerms))
        return 1;

    // Skriptit.
    if (!copyFile(base + "/libexec/oem-setup/oem-apply.sh",
                  "/usr/libexec/oem-setup/oem-apply.sh", execPerms))
        return 1;
    if (!copyFile(base + "/libexec/oem-setup/oem-cleanup.sh",
                  "/usr/libexec/oem-setup/oem-cleanup.sh", execPerms))
        return 1;

    // Polkit-policy.
    constexpr auto dataPerms =
        QFile::ReadOwner | QFile::WriteOwner |
        QFile::ReadGroup | QFile::ReadOther;
    if (!copyFile(base + "/share/polkit-1/actions/fi.local.oem-setup.policy",
                  "/etc/polkit-1/actions/fi.local.oem-setup.policy", dataPerms))
        return 1;

    // Cleanup-palvelu.
    if (!copyFile(base + "/lib/systemd/system/oem-cleanup.service",
                  "/usr/lib/systemd/system/oem-cleanup.service", dataPerms))
        return 1;

    // Ajonaikainen konffi.
    if (!writeFile("/etc/oem-setup/oem-setup.conf",
                   "setup_user=" + setupUser + "\n"
                   "allowed_locales=fi_FI.UTF-8;sv_SE.UTF-8;en_GB.UTF-8;en_US.UTF-8\n",
                   dataPerms))
        return 1;

    // Wrapper: tarkistaa onko setup valmis ja onko wizard jo käynnissä,
    // sitten käynnistää wizardin systemd-inhibitin kautta.
    const QString guiExec = appImagePath.isEmpty()
        ? QStringLiteral("/usr/bin/oem-setup-gui")
        : QStringLiteral("/usr/bin/oem-setup-gui --appimage-extract-and-run");
    if (!writeFile(QStringLiteral("/usr/bin/oem-setup-run"),
                   "#!/bin/bash\n"
                   "[ -f /etc/oem-setup/oem-setup.conf ] || exit 42\n"
                   "[ -f /tmp/oem-setup-done ] && exit 42\n"
                   "[ -n \"$DISPLAY\" ] || [ -n \"$WAYLAND_DISPLAY\" ] || exit 0\n"
                   "exec 9>/tmp/oem-setup-gui.lock\n"
                   "flock -n 9 || exit 0\n"
                   "if command -v systemd-inhibit >/dev/null 2>&1; then\n"
                   "    exec systemd-inhibit"
                   " --what=sleep:handle-lid-switch:handle-power-key:idle"
                   " --why=OEM-kayttoonotto --who=oem-setup-gui "
                   + guiExec + "\n"
                   "else\n"
                   "    exec " + guiExec + "\n"
                   "fi\n",
                   execPerms))
        return 1;

    // Autostart setup-käyttäjälle (fallback jos systemd --user ei käynnisty).
    const QString autostartDir = "/home/" + setupUser + "/.config/autostart";
    if (!writeFile(autostartDir + "/oem-setup.desktop",
                   "[Desktop Entry]\n"
                   "Type=Application\n"
                   "Name=OEM Setup\n"
                   "Exec=/usr/bin/oem-setup-run\n"
                   "X-GNOME-Autostart-enabled=true\n"
                   "NoDisplay=true\n",
                   QFile::ReadOwner | QFile::WriteOwner |
                   QFile::ReadGroup | QFile::ReadOther))
        return 1;

    // Systemd user service: käynnistää wrapperin ja respawnaa kaatumisen jälkeen.
    const QString serviceDir = "/home/" + setupUser + "/.config/systemd/user";
    if (!writeFile(serviceDir + "/oem-setup.service",
                   "[Unit]\n"
                   "Description=OEM Setup wizard\n"
                   "\n"
                   "[Service]\n"
                   "Type=simple\n"
                   "ExecStart=/usr/bin/oem-setup-run\n"
                   "Restart=always\n"
                   "RestartPreventExitStatus=42\n"
                   "RestartSec=5\n"
                   "\n"
                   "[Install]\n"
                   "WantedBy=default.target\n",
                   QFile::ReadOwner | QFile::WriteOwner |
                   QFile::ReadGroup | QFile::ReadOther))
        return 1;

    // Enable-symlinkki (vastaa systemctl --user enable).
    const QString wantsDir = serviceDir + "/default.target.wants";
    QDir().mkpath(wantsDir);
    const QString symlinkPath = wantsDir + "/oem-setup.service";
    QFile::remove(symlinkPath);
    if (!QFile::link(QStringLiteral("../oem-setup.service"), symlinkPath))
        return fail("systemd user service -symlinkin luonti epäonnistui");

    if (QProcess::execute(QStringLiteral("chown"), {QStringLiteral("-R"),
            setupUser + u':' + setupUser,
            "/home/" + setupUser + "/.config"}) != 0)
        return fail("chown epäonnistui .config-hakemistolle");

    if (QProcess::execute(QStringLiteral("systemctl"), {QStringLiteral("daemon-reload")}) != 0)
        return fail("systemctl daemon-reload epäonnistui");

    QTextStream(stdout)
        << "oem-setup: asennus valmis, käynnistä järjestelmä uudelleen." << Qt::endl;
    return 0;
}

}
