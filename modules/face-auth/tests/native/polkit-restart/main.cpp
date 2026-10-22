// Exercise real AuthFlow, Identity and QObject property/signal lifetimes. Only
// the external Polkit agent session / D-Bus reply boundary is replaced, so this
// test cannot contact the live authorization agent, PAM or a camera.
#include <QCoreApplication>
#include <QDebug>
#include <QMetaObject>
#include <QPointer>
#include <cstdlib>
#include <cstdio>
#include "flow.hpp"
#include "session.hpp"
using namespace qs::service::polkit;

namespace {
int initiated = 0, cancelled = 0, requestCancelled = 0, requestCompleted = 0;
Session* lastSession = nullptr;
PolkitIdentity* lastIdentity = nullptr;
QString lastCookie;
void check(bool condition, const char* message) {
    if (!condition) { std::fprintf(stderr, "FAIL: %s\n", message); std::exit(1); }
}
bool restart(AuthFlow& flow) {
    bool accepted = false;
    bool exposed = QMetaObject::invokeMethod(&flow, "restartAuthentication", Qt::DirectConnection,
                                             Q_RETURN_ARG(bool, accepted));
    check(exposed, "real AuthFlow must expose restartAuthentication to QML");
    return accepted;
}
AuthRequest* request() {
    auto* value = new AuthRequest{};
    value->cookie = "original-protected-action-cookie";
    value->actionId = "org.omarchy.test.restart";
    return value;
}
Identity* identity(int uid) {
    return new Identity(uid, QString::number(uid), "Administrator", false,
      GObjectRef<PolkitIdentity>(polkit_unix_user_new(uid), G_OBJECT_NO_REF));
}
}
namespace qs::log { void initLogCategoryLevel(const char*, QtMsgType) {} }
namespace qs::service::polkit {
void AuthRequest::complete() { requestCompleted++; }
void AuthRequest::cancel(const QString&) { requestCancelled++; }
Session::Session(PolkitIdentity* identity, const QString& cookie, QObject* parent): QObject(parent) {
    lastSession = this; lastIdentity = identity; lastCookie = cookie;
}
Session::~Session() = default;
void Session::initiate() { initiated++; emit request("Use face authentication? [y/N]", true); }
void Session::respond(const QString&) {}
void Session::cancel() {
    cancelled++;
    // libpolkit can complete synchronously during cancel. No old callback may
    // mutate the replacement conversation or complete the protected request.
    emit showError("obsolete session error");
    emit request("obsolete password prompt", false);
    emit completed(false);
}
}
int main(int argc, char** argv) {
    QCoreApplication app(argc, argv);
    auto* original = request();
    auto* admin = identity(1000);
    AuthFlow flow(original, {admin});
    int failures = 0, successes = 0;
    QObject::connect(&flow, &AuthFlow::authenticationFailed, [&] { failures++; });
    QObject::connect(&flow, &AuthFlow::authenticationSucceeded, [&] { successes++; });
    flow.submit("n");
    emit lastSession->request("Password:", false);
    emit lastSession->showError("earlier face failure");
    QPointer<Session> obsolete(lastSession);
    check(restart(flow), "waiting password prompt accepts explicit return");
    check(initiated == 2 && cancelled == 1, "one explicit return starts exactly one replacement");
    check(!obsolete, "obsolete Session is destroyed after cancel");
    check(flow.authRequest() == original && flow.cookie() == "original-protected-action-cookie",
          "restart keeps original protected request and cookie");
    check(flow.selectedIdentity().value() == admin && lastIdentity == admin->polkitIdentity.get(),
          "restart keeps exact selected administrator identity");
    check(lastCookie == "original-protected-action-cookie", "replacement uses original cookie");
    check(requestCancelled == 0 && requestCompleted == 0 && failures == 0 && successes == 0,
          "old session cancellation cannot fail, succeed, retry or cancel protected action");
    check(flow.isResponseRequired().value() && flow.inputPrompt().value() == "Use face authentication? [y/N]",
          "replacement returns to real PAM consent conversation");
    check(flow.supplementaryMessage().value().isEmpty() && !flow.supplementaryIsError().value(),
          "old supplementary error is cleared");
    flow.submit("y");
    check(!restart(flow) && initiated == 2, "busy authentication rejects restart");
    emit lastSession->request("Password:", false);
    flow.cancelAuthenticationRequest();
    check(!restart(flow) && requestCancelled == 1 && initiated == 2,
          "cancelled request cannot be resurrected");
    {
        auto* second = identity(1001);
        AuthFlow changing(request(), {identity(1000), second});
        const auto before = initiated;
        changing.setSelectedIdentity(second);
        check(initiated == before + 1, "changing identity creates one session without cancellation retries");
        check(changing.selectedIdentity().value() == second && lastIdentity == second->polkitIdentity.get(),
              "identity change uses the selected administrator");
        const auto after = initiated;
        changing.setSelectedIdentity(second);
        check(initiated == after, "reselecting identity is a no-op");
        emit lastSession->completed(true);
        check(!restart(changing) && initiated == after, "completed authorization cannot be restarted");
    }
    std::puts("POLKIT_RESTART_NATIVE_PASS");
}
